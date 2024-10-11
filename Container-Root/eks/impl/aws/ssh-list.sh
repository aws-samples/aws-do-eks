#!/bin/bash

CMD="aws ec2 describe-key-pairs --query \"KeyPairs[*].{KeyPairId:KeyPairId,KeyName:KeyName,KeyType:KeyType}\" --output table"

echo "$CMD"
eval "$CMD"

