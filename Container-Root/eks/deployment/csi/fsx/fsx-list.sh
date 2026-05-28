#!/bin/bash

echo ""
echo "Listing FSxL volumes ..."

#QUERY='FileSystems[].{"1_FileSystemId: FileSystemId, "2_VpcId": VpcId, "3_FileSystemType": FileSystemType, "4_StorageCapacity": StorageCapacity, "5_Lifecycle": Lifecycle}'

QUERY='FileSystems[].{"1_FileSystemId": FileSystemId, "2_VpcId": VpcId, "3_FileSystemType": FileSystemType, "4_DeploymentType": LustreConfiguration.DeploymentType, "5_Lifecycle": Lifecycle, "6_StorageCapacity": StorageCapacity, "7_ThroughputMBps": LustreConfiguration.PerUnitStorageThroughput || WindowsConfiguration.ThroughputCapacity || OntapConfiguration.ThroughputCapacity || OpenZFSConfiguration.ThroughputCapacity, "8_EfaEnabled": LustreConfiguration.EfaEnabled}'

CMD="aws fsx describe-file-systems --query '${QUERY}' --output table"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi
eval "${CMD}"

