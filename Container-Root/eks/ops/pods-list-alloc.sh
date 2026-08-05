#!/bin/bash

# List pods with details: name, status, age, node, instance type, cpu, memory, gpu, efa, volumes
# Usage:
#   ./pods-list-details.sh          # current namespace
#   ./pods-list-details.sh -A       # all namespaces
#   ./pods-list-details.sh -n kube-system  # specific namespace

# Pass all arguments to kubectl get pods (e.g. -A, -n <namespace>)
KUBECTL_ARGS="$@"

# Header
if echo "$KUBECTL_ARGS" | grep -q -- "-A"; then
  printf "%-20s " "NAMESPACE"
fi
printf "%-40s %-12s %-8s %-55s %-18s %-6s %-10s %-5s %-5s %s\n" \
  "POD" "STATUS" "AGE" "NODE" "INSTANCE-TYPE" "CPU" "MEMORY" "GPU" "EFA" "VOLUMES"
if echo "$KUBECTL_ARGS" | grep -q -- "-A"; then
  printf "%-20s " "---------"
fi
printf "%-40s %-12s %-8s %-55s %-18s %-6s %-10s %-5s %-5s %s\n" \
  "---" "------" "---" "----" "-------------" "---" "------" "---" "---" "-------"

# Cache node instance types to a temp file
node_cache=$(mktemp)
kubectl get nodes -o custom-columns="NODE:.metadata.name,INSTANCE-TYPE:.metadata.labels.node\.kubernetes\.io/instance-type" --no-headers > "$node_cache"

# Get pod details using jsonpath
if echo "$KUBECTL_ARGS" | grep -q -- "-A"; then
  COLUMNS="NAMESPACE:.metadata.namespace,\
POD:.metadata.name,\
STATUS:.status.phase,\
START:.metadata.creationTimestamp,\
NODE:.spec.nodeName,\
CPU:.spec.containers[*].resources.requests.cpu,\
MEM:.spec.containers[*].resources.requests.memory,\
GPU:.spec.containers[*].resources.requests.nvidia\.com/gpu,\
EFA:.spec.containers[*].resources.requests.vpc\.amazonaws\.com/efa,\
VOLS:.spec.volumes[*].name"
else
  COLUMNS="\
POD:.metadata.name,\
STATUS:.status.phase,\
START:.metadata.creationTimestamp,\
NODE:.spec.nodeName,\
CPU:.spec.containers[*].resources.requests.cpu,\
MEM:.spec.containers[*].resources.requests.memory,\
GPU:.spec.containers[*].resources.requests.nvidia\.com/gpu,\
EFA:.spec.containers[*].resources.requests.vpc\.amazonaws\.com/efa,\
VOLS:.spec.volumes[*].name"
fi

kubectl get pods $KUBECTL_ARGS --no-headers -o custom-columns="$COLUMNS" | while read line; do
  if echo "$KUBECTL_ARGS" | grep -q -- "-A"; then
    read ns pod status start node cpu mem gpu efa vols <<< "$line"
  else
    ns=""
    read pod status start node cpu mem gpu efa vols <<< "$line"
  fi

  # Calculate age
  if [ -n "$start" ] && [ "$start" != "<none>" ]; then
    start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$start" "+%s" 2>/dev/null || date -d "$start" "+%s" 2>/dev/null)
    now_epoch=$(date "+%s")
    if [ -n "$start_epoch" ]; then
      diff_sec=$((now_epoch - start_epoch))
      days=$((diff_sec / 86400))
      hours=$(( (diff_sec % 86400) / 3600 ))
      if [ $days -gt 0 ]; then
        age="${days}d${hours}h"
      else
        minutes=$(( (diff_sec % 3600) / 60 ))
        age="${hours}h${minutes}m"
      fi
    else
      age="N/A"
    fi
  else
    age="N/A"
  fi

  # Look up instance type from cache
  itype=$(grep "^${node} " "$node_cache" | awk '{print $2}')
  [ -z "$itype" ] && itype="<none>"

  # Default empty fields
  [ -z "$cpu" ] && cpu="<none>"
  [ -z "$mem" ] && mem="<none>"
  [ -z "$gpu" ] && gpu="<none>"
  [ -z "$efa" ] && efa="<none>"
  [ -z "$vols" ] && vols="<none>"

  if [ -n "$ns" ]; then
    printf "%-20s " "$ns"
  fi
  printf "%-40s %-12s %-8s %-55s %-18s %-6s %-10s %-5s %-5s %s\n" \
    "$pod" "$status" "$age" "$node" "$itype" "$cpu" "$mem" "$gpu" "$efa" "$vols"
done

rm -f "$node_cache"

