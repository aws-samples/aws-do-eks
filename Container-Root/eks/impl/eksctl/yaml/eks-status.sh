#!/bin/bash

echo ""
echo "Status of cluster using manifest ${ENV_HOME}${CONF} ..."

echo ""
CMD="eksctl get cluster -f ${ENV_HOME}${CONF}"
if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "${CMD}"
	echo ""
fi
if [ "${DRY_RUN}" == "" ]; then
    ${CMD}
fi

echo ""
CMD="eksctl get nodegroups -f ${ENV_HOME}${CONF}"
if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "${CMD}"
	echo ""
fi
if [ "${DRY_RUN}" == "" ]; then
    ${CMD}
fi

echo ""
CMD="eksctl get fargateprofiles -f ${ENV_HOME}${CONF}"
if [ "${VERBOSE}" == "true" ]; then
	echo ""
	echo "${CMD}"
	echo ""
fi
if [ "${DRY_RUN}" == "" ]; then
    ${CMD}
fi
