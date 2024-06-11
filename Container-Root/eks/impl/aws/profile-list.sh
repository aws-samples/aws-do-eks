$!/bin/bash

CMD="aws iam list-instance-profiles --query 'InstanceProfiles[*].{InstanceProfileId:InstanceProfileId,InstanceProfileName:InstanceProfileName,Arn:Arn,Role0:Roles[0].RoleName,Arn0:Roles[0].Arn}' --output table"

echo "$CMD"

eval "$CMD"

