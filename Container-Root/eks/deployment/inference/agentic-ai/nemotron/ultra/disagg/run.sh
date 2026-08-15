#!/bin/bash

source .env

if [ "${MANIFEST_TYPE}" == "" ]; then
	export MANIFEST_TYPE=deployment
fi

export CMD=""

case "${MANIFEST_TYPE}" in
	deployment|lws-2pp|lws-pp2|lws-ep|dgd)
		cat ${MANIFEST_TYPE}.yaml-template | envsubst > ${MANIFEST_TYPE}.yaml
		export CMD="kubectl apply -f ./${MANIFEST_TYPE}.yaml"
		;;
	lws|lws-pp)
		# Superseded PP shapes, removed from disagg/. Named arm rather than falling through
		# to *) so a stale MANIFEST_TYPE in someone's .env says what replaced it.
		echo "MANIFEST_TYPE=${MANIFEST_TYPE} was removed from disagg/. Use MANIFEST_TYPE=lws-2pp (PP2 prefill + 2x PP1 decode) or MANIFEST_TYPE=lws-pp2 (symmetric PP2 on both roles)."
		;;
	lws-ep-pd)
		# Renamed 2026-08-15 to lws-ep: same MANIFEST_TYPE name as ../agg/lws-ep, and the
		# FOLDER says which mode you get (this folder = P/D split). Named arm rather than
		# falling through to *) so a stale MANIFEST_TYPE in someone's .env says the new name.
		echo "MANIFEST_TYPE=lws-ep-pd was renamed to lws-ep in disagg/. Use MANIFEST_TYPE=lws-ep (still the disaggregated EP shape - this folder is the P/D one; the aggregated EP16 permutation is ../agg with the same name)."
		;;
	*)
		echo "Unknown MANIFEST_TYPE ${MANIFEST_TYPE}"
		;;
esac

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "$CMD"

# Verify: list everything this deployment created (empty until pods schedule)
kubectl -n ${NAMESPACE} get deploy,lws,dgd,svc,pods -l app.kubernetes.io/part-of=${DEPLOYMENT_NAME} 2>/dev/null
