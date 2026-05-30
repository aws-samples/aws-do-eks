#!/usr/bin/env bash
# probe-host.sh — single-node verdict for p5en host prep state.
# Run on the operator host (kubectl access required). Prints one line per
# p5en node and exits 0 if every node is GOOD, exits 1 otherwise.
#
# Author: Anton Alexander
#
# Usage:
#   bash probe-host.sh            # default: namespace=kube-system
#   NS=default bash probe-host.sh
#
# Verdicts:
#   GOOD            efa.ko + gdrdrv + efa_nv_peermem all loaded
#   MISSING-PEERMEM efa + gdrdrv loaded, efa_nv_peermem absent
#                   => apply 03-efa-peermem-dkms-rebuild-daemonset.yaml
#   MISSING-GDRDRV  efa loaded, gdrdrv absent
#                   => apply 02-gdrcopy-installer-daemonset.yaml
#   MISSING-EFA     no efa.ko (extremely unusual on p5en)
#                   => apply 01-efa-installer-daemonset.yaml
set -euo pipefail

NS="${NS:-kube-system}"
PROBE_DS_NAME=peermem-probe-p5en

# Drop the probe DS
cat <<YAML | kubectl -n "$NS" apply -f - >/dev/null
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ${PROBE_DS_NAME}
  namespace: ${NS}
spec:
  selector: { matchLabels: { app: ${PROBE_DS_NAME} } }
  template:
    metadata: { labels: { app: ${PROBE_DS_NAME} } }
    spec:
      hostPID: true
      hostNetwork: true
      nodeSelector:
        node.kubernetes.io/instance-type: "p5en.48xlarge"
      tolerations: [{ operator: Exists }]
      containers:
        - name: probe
          image: ubuntu:24.04
          command: ["nsenter", "--target", "1", "--mount", "--", "bash", "-c"]
          args:
            - |
              while true; do
                EFA=\$(lsmod   | awk '\$1=="efa"{print "Y"}')
                GDR=\$(lsmod   | awk '\$1=="gdrdrv"{print "Y"}')
                NV=\$(lsmod    | awk '\$1=="efa_nv_peermem"{print "Y"}')
                if   [ "\$EFA" != Y ];                         then V="MISSING-EFA"
                elif [ "\$GDR" != Y ];                         then V="MISSING-GDRDRV"
                elif [ "\$NV"  != Y ];                         then V="MISSING-PEERMEM"
                else                                                V="GOOD"
                fi
                printf "%s  efa=%s gdrdrv=%s efa_nv_peermem=%s  =>  %s\n" \
                  "\$(hostname)" "\${EFA:-N}" "\${GDR:-N}" "\${NV:-N}" "\$V"
                sleep 86400
              done
          securityContext: { privileged: true, runAsUser: 0 }
YAML

echo "[probe] DaemonSet applied; waiting 12s for pods to print verdicts"
sleep 12

OUTPUT=$(kubectl -n "$NS" logs -l app=$PROBE_DS_NAME --tail=1 --prefix)
echo "$OUTPUT"
echo

# Tear down
kubectl -n "$NS" delete ds/$PROBE_DS_NAME --wait=false >/dev/null

# Gate: pass only if every node prints GOOD
TOTAL=$(echo "$OUTPUT" | grep -cE '=>')
GOOD=$(echo  "$OUTPUT" | grep -cE 'GOOD$')
if [ "$TOTAL" -eq 0 ]; then
    echo "FAIL — no p5en nodes found in $NS namespace"
    exit 1
elif [ "$GOOD" -eq "$TOTAL" ]; then
    echo "PASS — $TOTAL/$TOTAL p5en nodes ready for step 1 bandwidth test"
    exit 0
else
    echo "FAIL — $GOOD/$TOTAL p5en nodes GOOD; remediate per matching DS in 00-host-prep/daemonsets/"
    exit 1
fi
