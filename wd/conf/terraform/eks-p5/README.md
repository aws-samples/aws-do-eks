# Example EKS cluster with P5.48xlarge Node Group and 32 Elastic Fabric Adapter Interfaces per P5 instance

## Elastic Fabric Adapter Overview

[Elastic Fabric Adapter (EFA)](https://aws.amazon.com/hpc/efa/) is a network interface supported by [some Amazon EC2 instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types) that provides high-performance network communications at scale on AWS. Commonly, high-performance computing, simulation, and large AI model training jobs require EFA, in order to minimize the time to job completion. This example provides a blueprint for deploying an [Amazon EKS](https://aws.amazon.com/eks/) cluster with EFA-enabled nodes, which can be used to run such jobs.

## P5 Instance Type Overview

Amazon EC2 [P5](https://aws.amazon.com/ec2/instance-types/p5/) instances contain 8 NVIDIA H100 GPUs with 80GB of GPU Memory. They are also powered by 32 EFA network adapters, providing network speeds of up to 3200 Gbps. These instance types are typically used for distributed training of large foundation models, fine-tuning, or other GenAI and HPC workloads.

# Terraform Doc

The main Terraform doc [main.tf](main.tf) contains local variables, local data, vpc and eks definitions, device plugins, and addons.

## Requirements

Requirements are specified in the [providers.tf](providers.tf) file. This file is used to install all needed providers when `terraform init` is executed.

## Modules

The following modules are included in the template:

1. vpc - defines the VPC which will be used to host the EKS cluster

2. eks - defines the EKS cluster
   The EKS cluster contains a managed nodedgroup called `sys` for running system pods,
   and a managed nodegroup called `gpu` which has the necessary configuration to run the configure GPU instance type, default p5.48xlarge.

## Resources

The [resources section of main.tf](main.tf#69) creates a placement group, deploys the [EFA](https://github.com/aws-samples/aws-efa-eks) and [NVIDIA](https://github.com/NVIDIA/k8s-device-plugin) device plugins.

## Inputs

There are no required user-inputs.
The template comes with default inputs which create an EKS cluster.
Input settings can be adjusted in the [variables.tf](variables.tf) file.

## Outputs

When the `terraform apply` completes successfully, the EKS cluster id, and the command to connect to the cluster are provided as outputs as described in [outputs.tf](outputs.tf).

# Example Walkthrough

## 1. Clone Repository

```bash
git clone https://github.com/aws-samples/aws-do-eks
cd aws-do-eks/wd/conf/terraform/eks-gpu
```

## 2. Configure Terraform Plan

Edit [variables.tf](variables.tf) as needed. If you are using an On-deman capacity reservation, specify the capacity reservation id in [variables.tf](variables.tf) and uncomment the `capacity_reservation_specification` block in [main.tf](main.tf).

## 3. Initialize Terraform Plan

```bash
terraform init
```
<details>
<summary>sample output:</summary>

```text
Initializing the backend...
Initializing modules...
Downloading registry.terraform.io/terraform-aws-modules/eks/aws 19.21.0 for eks...
- eks in .terraform/modules/eks
- eks.eks_managed_node_group in .terraform/modules/eks/modules/eks-managed-node-group
- eks.eks_managed_node_group.user_data in .terraform/modules/eks/modules/_user_data
- eks.fargate_profile in .terraform/modules/eks/modules/fargate-profile
Downloading registry.terraform.io/terraform-aws-modules/kms/aws 2.1.0 for eks.kms...
- eks.kms in .terraform/modules/eks.kms
- eks.self_managed_node_group in .terraform/modules/eks/modules/self-managed-node-group
- eks.self_managed_node_group.user_data in .terraform/modules/eks/modules/_user_data
Downloading registry.terraform.io/terraform-aws-modules/vpc/aws 4.0.2 for vpc...
- vpc in .terraform/modules/vpc

Initializing provider plugins...
- Finding hashicorp/aws versions matching ">= 4.33.0, >= 4.35.0, >= 4.47.0, >= 4.57.0"...
- Finding hashicorp/kubernetes versions matching ">= 2.10.0, >= 2.16.1"...
- Finding hashicorp/helm versions matching ">= 2.8.0"...
- Finding gavinbunney/kubectl versions matching ">= 1.14.0"...
- Finding hashicorp/http versions matching ">= 2.2.0"...
- Finding hashicorp/time versions matching ">= 0.9.0"...
- Finding hashicorp/tls versions matching ">= 3.0.0"...
- Finding hashicorp/cloudinit versions matching ">= 2.0.0"...
- Installing hashicorp/helm v2.12.1...
- Installed hashicorp/helm v2.12.1 (signed by HashiCorp)
- Installing gavinbunney/kubectl v1.14.0...
- Installed gavinbunney/kubectl v1.14.0 (self-signed, key ID AD64217B5ADD572F)
- Installing hashicorp/http v3.4.1...
- Installed hashicorp/http v3.4.1 (signed by HashiCorp)
- Installing hashicorp/time v0.10.0...
- Installed hashicorp/time v0.10.0 (signed by HashiCorp)
- Installing hashicorp/tls v4.0.5...
- Installed hashicorp/tls v4.0.5 (signed by HashiCorp)
- Installing hashicorp/cloudinit v2.3.3...
- Installed hashicorp/cloudinit v2.3.3 (signed by HashiCorp)
- Installing hashicorp/aws v5.37.0...
- Installed hashicorp/aws v5.37.0 (signed by HashiCorp)
- Installing hashicorp/kubernetes v2.26.0...
- Installed hashicorp/kubernetes v2.26.0 (signed by HashiCorp)

Partner and community providers are signed by their developers.
If you'd like to know more about provider signing, you can read about it here:
https://www.terraform.io/docs/cli/plugins/signing.html

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

</details>

## 4. Create Terraform Plan

```bash
terraform plan -out tfplan
```

<details>
<summary>Output:</summary>

```text
...
# module.vpc.aws_vpc.this[0] will be created
  + resource "aws_vpc" "this" {
      + arn                                  = (known after apply)
      + cidr_block                           = "10.11.0.0/16"
      + default_network_acl_id               = (known after apply)
      + default_route_table_id               = (known after apply)
      + default_security_group_id            = (known after apply)
...

Plan: 69 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + configure_kubectl = "aws eks update-kubeconfig --region us-east-1 --name eks-efa"
  + eks_cluster_id    = (known after apply)

───────────────────────────────────────────────────────────────────────────────

Saved the plan to: tfplan

To perform exactly these actions, run the following command to apply:
    terraform apply "tfplan"
```
</details>

## 5. Apply Terraform Plan

```bash
terraform apply tfplan
```

<details>

<summary>Output:</summary>

```text
aws_placement_group.efa_pg: Creating...
module.eks.aws_cloudwatch_log_group.this[0]: Creating...
module.vpc.aws_vpc.this[0]: Creating...
module.eks.module.eks_managed_node_group["sys"].aws_iam_role.this[0]: Creating...
module.vpc.aws_eip.nat[0]: Creating...
module.eks.aws_iam_role.this[0]: Creating...
...
module.eks.aws_eks_cluster.this[0]: Still creating... [1m40s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [1m50s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [2m0s elapsed]
...
Apply complete! Resources: 69 added, 0 changed, 0 destroyed.

Outputs:

configure_kubectl = "aws eks update-kubeconfig --region us-west-2 --name do-eks-tf-p5"

```
</details>

> **_Note:_** If the plan apply operation fails, you can repeat `terraform plan -out tfplan` and `terraform apply tfplan`

It takes about 15 minutes to create the cluster.

## 6. Connect to EKS

Copy the value of the `configure_kubectl` output and execute it in your shell to connect to your EKS cluster.

```bash
aws eks update-kubeconfig --region us-west-2 --name do-eks-tf-p5
```

Output:
```text
Updated context arn:aws:eks:us-west-2:xxxxxxxxxxxx:cluster/do-eks-tf-p5 in /root/.kube/config
```

Allow 5 minutes after the plan is applied for the EFA nodes to finish initializing and join the EKS cluster, then execute:

```bash
kubectl get nodes -L node.kubernetes.io/instance-type
```

Your nodes and node types will be listed:

```text
NAME                                        STATUS   ROLES    AGE     VERSION               INSTANCE-TYPE
ip-10-11-14-93.us-west-2.compute.internal   Ready    <none>   2m34s   v1.28.5-eks-5e0fdde   p5.48xlarge
ip-10-11-7-53.us-west-2.compute.internal    Ready    <none>   2m31s   v1.28.5-eks-5e0fdde   p5.48xlarge
```

You should see nodes listed (in this example `p5.48xlarge`) nodes in the list.
This verifies that you are connected to your EKS cluster and it is configured with EFA nodes.


## 9. Cleanup

```bash
terraform destroy
```

<details>
<summary>Output:</summary>

```text
...
 # module.eks.module.self_managed_node_group["efa"].aws_iam_role.this[0] will be destroyed
...

Plan: 0 to add, 0 to change, 69 to destroy.
...
Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes
  ...
  module.eks.aws_iam_role.this[0]: Destruction complete after 1s
module.eks.aws_security_group_rule.node["ingress_self_coredns_udp"]: Destruction complete after 2s
module.eks.aws_security_group_rule.node["ingress_cluster_9443_webhook"]: Destruction complete after 3s
module.eks.aws_security_group_rule.node["ingress_cluster_443"]: Destruction complete after 3s
module.eks.aws_security_group_rule.node["egress_all"]: Destruction complete after 2s
module.eks.aws_security_group_rule.node["egress_self_all"]: Destruction complete after 3s
module.eks.aws_security_group_rule.node["ingress_nodes_ephemeral"]: Destruction complete after 3s
module.eks.aws_security_group_rule.node["ingress_cluster_8443_webhook"]: Destruction complete after 3s
module.eks.aws_security_group_rule.node["ingress_self_coredns_tcp"]: Destruction complete after 4s
module.eks.aws_security_group.cluster[0]: Destroying... [id=sg-05516650e2f2ed6c1]
module.eks.aws_security_group.node[0]: Destroying... [id=sg-0e421877145f36d48]
module.eks.aws_security_group.cluster[0]: Destruction complete after 1s
module.eks.aws_security_group.node[0]: Destruction complete after 1s
module.vpc.aws_vpc.this[0]: Destroying... [id=vpc-04677b1ab4eac3ca7]
module.vpc.aws_vpc.this[0]: Destruction complete after 0s
╷
│ Warning: EC2 Default Network ACL (acl-0932148c7d86482e0) not deleted, removing from state
╵

Destroy complete! Resources: 69 destroyed.
```

</details>

The cleanup process takes about 15 minutes.

# Conclusion

With this example, we have demonstrated how Terraform can be used to create an EKS cluster with a
p5 nodegroup. Each of the instances in the nodegroup is configured with EFA adapters. 
Use this example as a starting point to bootstrap your own infrastructure-as-code terraform projects that require use
of high-performance networking and accelerated computing on AWS.

# References

* [Elastic Fabric Adapter](https://aws.amazon.com/hpc/efa/)
* [EFA-enabled Instance Types](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types)
* [Getting started with EFA on EKS](https://github.com/aws-samples/aws-efa-eks/)
* [do-framework](https://bit.ly/do-framework)
* [Amazon EC2 P5 Instane Type](https://aws.amazon.com/ec2/instance-types/p5/)
