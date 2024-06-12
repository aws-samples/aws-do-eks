echo "Creating IAM service role for CloudWatch add-on...."
export AWS_DEFAULT_REGION=us-west-2
eksctl create iamserviceaccount \
  --name cloudwatch-agent \
  --namespace amazon-cloudwatch --cluster eks-inference-workshop \
  --role-name cloudwatch-addon-role \
  --attach-policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy \
  --role-only \
  --approve
echo "... IAM role created"
sleep 30
ROLE=$(aws iam list-roles --query "Roles[?RoleName=='cloudwatch-addon-role'].Arn" --output text)
echo "Creating CloudWatch Add-on using role ARN: $ROLE..."
aws eks create-addon --addon-name amazon-cloudwatch-observability --cluster-name eks-inference-workshop  --service-account-role-arn $ROLE
echo "CloudWatch add-on installed!"
