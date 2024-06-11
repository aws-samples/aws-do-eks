echo "Creating IAM service role for CloudWatch..add-on"
eksctl create iamserviceaccount \
  --name cloudwatch-agent \
  --namespace amazon-cloudwatch --cluster eks-inference-workshop \
  --role-name cloudwatch-addon-role \
  --attach-policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy \
  --role-only \
  --approve
echo "... IAM role created"
#echo "Creating Add-on..."
#aws eks create-addon --addon-name amazon-cloudwatch-observability --cluster-name eks-inference-workshop  --service-account-role-arn arn:aws:iam::133776528597:role/cloudwatch-addon-role
