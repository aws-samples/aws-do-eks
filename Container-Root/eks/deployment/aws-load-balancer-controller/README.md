# AWS LoadBalancer Controller

Reference: 

# Troubleshooting

## If you create an ingress object but no loadbalancer is provisioned and your controller is running

Check aws-load-balancer-controller  pod logs. If you see this error:

```
"error":"couldn't auto-discover subnets: UnauthorizedOperation: You are not authorized to perform this operation.\n\tstatus code: 403, 
```

Solution:

Follow instructions from https://aws.amazon.com/premiumsupport/knowledge-center/eks-load-balancer-controller-subnets/

Add `ec2:DescribeAvailabilityZones` permission to the IAM role associated with the loadbalancer controller service account


