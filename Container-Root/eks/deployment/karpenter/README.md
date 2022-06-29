# EKS Autoscaling with Karpenter

## What is Karpenter?
[Karpenter](https://karpenter.sh) is an open source controller for Kubernetes which enables auto-scaling. 

## How is Karpenter different than the traditional Cluster Autoscaler?
The main difference is that Karpenter does not rely on node groups like Cluster Autoscaler to expand or contract the cluster. It is claimed that Karpenter is both more performant and cost effective than Cluster Autoscaler. 
More details can be found in [this article](https://towardsdev.com/karpenter-vs-cluster-autoscaler-dd877b91629b).

## How to set up Karpenter on EKS

Scripts to automate deployment of Karpenter in this project have been created following instructions from this [walkthrough](Walktrough: https://karpenter.sh/v0.10.0/getting-started/getting-started-with-eksctl/)

1. Build and run aws-do-eks project, exec into aws-do-eks container.
2. Edit eks-karpenter.yaml as needed
3. Edit `eks.conf`
	a. set CONFIG=yaml
	b. set EKS_YAML=./eks-karpenter.yaml
4. Create cluster by executing `./eks-create.sh`
5. Refer to scripts in the /eks/deployment/karpenter directory
	a. Execute `./deploy.sh` to configure the necessary roles and deploy the controller
	b. Optionally execute `./monitoring-deploy.sh` to enable prometheus/grafana monitoring of Karpenter metrics
	c. Execute `./provisioner-deploy.sh` to configure Karpenter for the cluster.
6. Test Karpenter
	1. Execute `./test-scale-out.sh` 
	2. Use `./logs.sh` script to monitor karpenter operations
	3. Use `./scale.sh <num_pods>` to change the test scale
	4. Execute `./test-scale-in.sh` to stop testing.

## References

* Karpenter Documentation: [https://karpenter.sh/v0.10.1/](https://karpenter.sh/v0.10.1/)

* Provisioner CRD: [https://karpenter.sh/v0.10.0/provisioner/](https://karpenter.sh/v0.10.0/provisioner/)

* Scheduling: [https://karpenter.sh/v0.10.1/tasks/scheduling/](https://karpenter.sh/v0.10.1/tasks/scheduling/)

* Kaprenter Best Practices: [https://aws.github.io/aws-eks-best-practices/karpenter/](https://aws.github.io/aws-eks-best-practices/karpenter/)

