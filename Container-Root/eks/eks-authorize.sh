#!/bin/bash

source ./conf/env.conf

case ${IMPL} in

	"impl/eksctl/env")
		source ${ENV_HOME}${CONF}
		;;
	"impl/eksctl/yaml")
		export CLUSTER_NAME=$(cat ${CONF} | yq .metadata.name)
		;;
	"impl/terraform")
		export CLUSTER_NAME=$(cat ${CONF} | grep cluster_name -A 3 | grep default | cut -d '"' -f 2)
		;;
	*)
		echo "Unexpected implementation ${IMPL}, please check env.conf"
		;;
esac

USER_ARN=$(aws sts get-caller-identity --output json | jq -r '.Arn')
USER_NAME=$(echo $USER_ARN | cut -d '/' -f 2)

CMD="eksctl create iamidentitymapping --cluster $CLUSTER_NAME --arn $USER_ARN --group system:masters --username $USER_NAME"

if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "${CMD}"
	echo ""
fi

if [ "${DRY_RUN}" == "" ]; then
	${CMD}
fi

