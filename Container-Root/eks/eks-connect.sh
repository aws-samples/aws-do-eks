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

CMD="aws eks update-kubeconfig --name $CLUSTER_NAME"

if [ "${VERBOSE}" == "true" ]; then
        echo ""
        echo "${CMD}"
        echo ""
fi

if [ "${DRY_RUN}" == "" ]; then
        ${CMD}
fi
