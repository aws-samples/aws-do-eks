#!/bin/bash

source .env

if [ "${MANIFEST_TYPE}" == "" ]; then
	export MANIFEST_TYPE=deployment
fi

export CMD=""

case "${MANIFEST_TYPE}" in
	deployment|lws-2pp|lws-pp2|lws-ep-pd|dgd)
		cat ${MANIFEST_TYPE}.yaml-template | envsubst > ${MANIFEST_TYPE}.yaml
		export CMD="kubectl apply -f ./${MANIFEST_TYPE}.yaml"
		;;
	lws|lws-pp)
		# Superseded PP shapes, removed from disagg/. Named arm rather than falling through
		# to *) so a stale MANIFEST_TYPE in someone's .env says what replaced it.
		echo "MANIFEST_TYPE=${MANIFEST_TYPE} was removed from disagg/. Use MANIFEST_TYPE=lws-2pp (PP2 prefill + 2x PP1 decode) or MANIFEST_TYPE=lws-pp2 (symmetric PP2 on both roles)."
		;;
	lws-ep)
		# Removed from disagg/: that permutation renders ONE `vllm serve` with no
		# prefill/decode split and no --kv-transfer-config, i.e. it is AGGREGATED. It now
		# lives only in ../agg. Named arm rather than falling through to *) so a stale
		# MANIFEST_TYPE=lws-ep in someone's .env says what to do instead.
		echo "MANIFEST_TYPE=lws-ep is not valid in disagg/ - that topology is aggregated; use ../agg (MANIFEST_TYPE=lws-ep)."
		echo "For expert parallelism WITH a prefill/decode split use MANIFEST_TYPE=lws-ep-pd."
		;;
	*)
		echo "Unknown MANIFEST_TYPE ${MANIFEST_TYPE}"
		;;
esac

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD"

# Verify: list everything this deployment created (empty until pods schedule)
kubectl -n ${NAMESPACE} get deploy,lws,dgd,svc,pods -l app.kubernetes.io/part-of=${DEPLOYMENT_NAME} 2>/dev/null
