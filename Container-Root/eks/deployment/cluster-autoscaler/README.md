# Cluster Autoscaler
The Kubernetes Cluster Autoscaler is used traditionally to dynamically scale node groups.

## Deployment
Execute scripot `./deploy-cluster-autoscaler.sh`

## Troubleshooting

* Error log in autoscaler pod:
 Failed to watch *v1beta1.CSIStorageCapacity: failed to list *v1beta1.CSIStorageCapacity: csistoragecapacities.storage.k8s.io is forbidden: User "system:serviceaccount:kube-system:cluster-autoscaler" cannot list resource "csistoragecapacities" in API group "storage.k8s.io" at the cluster scope

Resolution:

```
kubectl edit clusterrole cluster-autoscaler
```
append

```
- apiGroups:
  - storage.k8s.io
  resources:
  - csinodes
  - csidrivers
  - csistoragecapacities
  verbs:
  - watch
  - list
  - get
```


## References

* GitHub: [https://github.com/kubernetes/autoscaler](https://github.com/kubernetes/autoscaler)
* Cluster Autoscaling on AWS: [https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md)
* AWS Autoscaling Documentation: [https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html](https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html)
