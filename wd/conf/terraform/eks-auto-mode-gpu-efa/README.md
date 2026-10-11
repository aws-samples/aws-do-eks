# EKS Auto Mode Cluster with H200 (p5en.48xlarge) or B200 (p6-b200.48xlarge) GPU Nodes and EFA

## Overview

This Terraform configuration creates an [Amazon EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/automode.html) cluster from scratch in a new VPC, with a static pool of NVIDIA GPU instances (H200 on p5en.48xlarge by default, B200 on p6-b200.48xlarge or H200 on p5e.48xlarge by variable) launched into an On-Demand Capacity Reservation or ML Capacity Block, with Elastic Fabric Adapter (EFA) networking.

On Auto Mode there are no managed node groups. AWS runs the compute (a built-in Karpenter), pod networking, cluster DNS, block storage and the GPU drivers and device plugin as cluster capabilities on Bottlerocket-based nodes. The GPU nodes are described by a `NodeClass` and a static `NodePool` that this configuration renders and applies to the cluster, and the capacity reservation id goes into the `NodeClass`.

## GPU Instance Types

Values below are from `aws ec2 describe-instance-types` (us-east-2, 2026-10-11); the EFA interface count per instance type is kept in the `efa_network_cards` variable and drives the `NodeClass`.

| Instance type | GPUs | Network cards | EFA interfaces | Network |
|---------------|------|---------------|----------------|---------|
| p5en.48xlarge | 8 x NVIDIA H200 | 16 | 16 | 3200 Gbps |
| p5e.48xlarge | 8 x NVIDIA H200 | 32 | 32 | 3200 Gbps |
| p6-b200.48xlarge | 8 x NVIDIA B200 | 8 | 8 | 3200 Gbps |

All three are on the [EKS Auto Mode supported instance list](https://docs.aws.amazon.com/eks/latest/userguide/automode-learn-instances.html).

## Architecture

1. **VPC** - three availability zones, private subnets for the nodes, one NAT gateway.

2. **EKS cluster with Auto Mode** (`terraform-aws-modules/eks/aws ~> 20.37`, `cluster_compute_config.enabled = true`) with the built-in `general-purpose` and `system` node pools. These run CoreDNS and other system pods on CPU instances and make EKS create the access entry for the Auto Mode node IAM role.

3. **GPU NodeClass** (`eks.amazonaws.com/v1`, applied with `kubectl_manifest`) - reuses the Auto Mode node IAM role, pins the nodes to the private subnet in `gpu_availability_zone`, uses the EKS cluster security group, selects `capacity_reservation_id`, and declares the EFA interfaces statically: the primary ENI plus one `efa-only` interface per network card.

4. **GPU NodePool** (`karpenter.sh/v1`, static) - `replicas = gpu_node_count` reserved nodes of `gpu_instance_type` in `gpu_availability_zone`, `karpenter.sh/capacity-type: reserved`, tainted `nvidia.com/gpu:NoSchedule`. Default: 2 nodes.

5. **EFA device plugin** - the `aws-efa-k8s-device-plugin` Helm chart from `eks-charts`, which advertises `vpc.amazonaws.com/efa` on the nodes. Auto Mode bundles the NVIDIA GPU drivers and device plugin, but not the EFA device plugin.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.3.2
- kubectl
- An On-Demand Capacity Reservation (ODCR) or ML Capacity Block for the chosen `gpu_instance_type`, in `gpu_availability_zone`

## Usage

### 1. Configure

Edit [variables.tf](variables.tf) to adjust defaults as needed. Key settings:
- `capacity_reservation_id`: your ODCR or Capacity Block id (`cr-xxxxxxxxxxxxxxxxx`)
- `gpu_availability_zone`: the AZ of the reservation
- `gpu_instance_type`: `p5en.48xlarge` (default), `p5e.48xlarge` or `p6-b200.48xlarge`
- `gpu_node_count`: nodes the static pool keeps running (match the reservation); `gpu_node_limit` defaults to one more
- `cluster_version`: EKS version (default: 1.35)

To use another EFA-capable instance type, add its network card count to `efa_network_cards`.

### 2. Initialize

```bash
cd wd/conf/terraform/eks-auto-mode-gpu-efa
terraform init
```

### 3. Plan

```bash
terraform plan -out tfplan
```

### 4. Apply

```bash
terraform apply tfplan
```

Cluster creation takes approximately 15 minutes. The static NodePool starts launching the reserved GPU nodes as soon as it is applied.

### 5. Connect

```bash
aws eks update-kubeconfig --region <your-region> --name do-eks-tf-auto-mode-gpu-efa
kubectl get nodeclass gpu-efa
kubectl get nodepool gpu-efa
kubectl get nodeclaims -o wide
kubectl get nodes -L node.kubernetes.io/instance-type
```

If the GPU nodes do not appear, `kubectl describe nodeclaim -l karpenter.sh/nodepool=gpu-efa` shows the launch error (reservation id or AZ mismatch, insufficient capacity, IAM).

Once the nodes are `Ready`, each one should advertise 8 `nvidia.com/gpu` and one `vpc.amazonaws.com/efa` per EFA interface (16 on p5en.48xlarge, 8 on p6-b200.48xlarge):

```bash
kubectl get nodes -l karpenter.sh/nodepool=gpu-efa -o custom-columns='NAME:.metadata.name,TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,GPU:.status.allocatable.nvidia\.com/gpu,EFA:.status.allocatable.vpc\.amazonaws\.com/efa'
```

A pod that requests `nvidia.com/gpu` and `vpc.amazonaws.com/efa` and tolerates the `nvidia.com/gpu` taint now schedules on these nodes. The NCCL tests in [Container-Root/eks/deployment/nccl-test](../../../../Container-Root/eks/deployment/nccl-test) are a ready-made workload: their worker pods already carry the toleration; set `INSTANCE_TYPE`, `GPU_PER_WORKER=8` and `EFA_PER_WORKER` (16 for p5en, 8 for p6-b200) in its `.env`.

### 6. Cleanup

```bash
terraform destroy
```

The reservation itself is not touched by Terraform and keeps billing until you cancel it.

## What is different on Auto Mode

- **Bottlerocket nodes, managed by AWS.** Nodes run an AWS-managed Bottlerocket-based AMI, not AL2023; there is no SSH or SSM access, and nodes are replaced by AWS on drift (a new Auto Mode AMI roughly once per week) and after 336 hours by default. The static pool keeps `gpu_node_count` nodes through a replacement, and the disruption budget limits it to one node at a time. ([Learn about Auto Mode managed instances](https://docs.aws.amazon.com/eks/latest/userguide/automode-learn-instances.html), [Create a node pool](https://docs.aws.amazon.com/eks/latest/userguide/create-node-pool.html))
- **No node groups: the `cr-` id lives in the NodeClass.** `capacityReservationSelectorTerms` on the NodeClass selects the reservation and `karpenter.sh/capacity-type: reserved` on the NodePool binds the nodes to it. Capacity Blocks for ML always require `capacityReservationSelectorTerms`. ([Capacity Reservations with Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/auto-odcr.html))
- **Static capacity pool.** `replicas` holds the nodes regardless of pod demand. Once set, `replicas` cannot be removed again; only `limits.nodes` is honored; `weight` cannot be set; the nodes are never consolidated. ([Static capacity node pools](https://docs.aws.amazon.com/eks/latest/userguide/auto-static-capacity.html))
- **EFA is declared statically and pod IP capacity is fixed at launch.** With `advancedNetworking.networkInterfaces` set, Auto Mode attaches no additional IPs, prefixes or ENIs after launch; `pod_ipv4_prefix_count` (one /28 = 16 pod IPs per node by default) is the pod density per GPU node. IPv6 is not supported with static interfaces. ([Create a node class](https://docs.aws.amazon.com/eks/latest/userguide/create-node-class.html))
- **EFA and static hugepages cannot coexist on one NodeClass.** Setting `interfaceType: efa-only` together with `advancedCompute.hugepages.pages` fails NodeClass validation, and pods requesting `vpc.amazonaws.com/efa` are not provisioned from a NodeClass with static hugepages. Workloads that request `hugepages-2Mi` need that request removed or a separate non-EFA NodeClass. (same page)
- **Device plugins.** Auto Mode includes the NVIDIA GPU drivers and device plugin ([Auto Mode overview](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)), so no NVIDIA device plugin or GPU operator is installed here. The EFA device plugin is not bundled (per the AWS sample [sample-eks-docs auto-mode](https://github.com/aws-samples/sample-eks-docs/tree/main/ai-ml/set-up-cluster/terraform/auto-mode); the AWS documentation pages above do not mention it) and is installed by this configuration.
- **Cluster add-ons.** CoreDNS, kube-proxy and the VPC CNI are Auto Mode capabilities, so they are not declared as `cluster_addons`; the module disables `bootstrap_self_managed_addons` when compute is enabled.
- **Module version.** `terraform-aws-modules/eks/aws ~> 20.37` is the last v20 line; it has `cluster_compute_config` (Auto Mode, since v20.31) and keeps the `cluster_name` / `cluster_version` input names used by the other examples in this folder. v21 renamed those inputs (`name`, `kubernetes_version`, `compute_config`) and requires the aws provider 6.x.

## Validation status

Validated offline only: `terraform init -backend=false`, `terraform validate` and `terraform fmt -check` pass (module `20.37.2`, providers aws `5.100.0`, helm `3.3.0`, kubectl `1.19.0` resolved). This configuration has **not** been applied to a live cluster; the first `terraform apply` on a fresh account is the proof.

## Inputs

| Variable | Description | Default |
|----------|-------------|---------|
| aws_region | AWS Region | us-east-2 |
| cluster_name | EKS cluster name | do-eks-tf-auto-mode-gpu-efa |
| cluster_version | EKS version | 1.35 |
| auto_mode_node_pools | Built-in Auto Mode node pools | ["general-purpose", "system"] |
| gpu_instance_type | GPU instance type (key of efa_network_cards) | p5en.48xlarge |
| efa_network_cards | Network cards (= EFA interfaces) per instance type | p5en 16, p5e 32, p6-b200 8, p5 32 |
| capacity_reservation_id | ODCR or Capacity Block id | cr-xxxxxxxxxxxxxxxxx |
| gpu_availability_zone | AZ of the reservation and the GPU nodes | us-east-2a |
| gpu_node_count | Static NodePool replicas | 2 |
| gpu_node_limit | NodePool limits.nodes | gpu_node_count + 1 |
| pod_ipv4_prefix_count | /28 prefixes on the primary ENI (16 pod IPs each) | 1 |
| efa_device_plugin_version | aws-efa-k8s-device-plugin chart version | v0.5.33 |
| vpc_cidr | VPC CIDR block | 10.13.0.0/16 |
| cluster_enabled_log_types | Control plane log types | api, authenticator, audit, scheduler, controllerManager |

## Outputs

| Output | Description |
|--------|-------------|
| eks_cluster_id | The EKS cluster ID |
| configure_kubectl | Command to configure kubectl |
| node_iam_role_name | Auto Mode node IAM role reused by the GPU NodeClass |
| gpu_nodepool | Name of the static GPU NodePool |
| efa_interfaces_per_node | efa-only interfaces declared per GPU node |

## References

- [EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
- [Create a Node Class for Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/create-node-class.html)
- [Create a Node Pool for EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/create-node-pool.html)
- [Static Capacity Node Pools in EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/auto-static-capacity.html)
- [Capacity Reservations with EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/auto-odcr.html)
- [terraform-aws-modules/eks: EKS Auto Mode](https://github.com/terraform-aws-modules/terraform-aws-eks/tree/v20.37.2/examples/eks-auto-mode)
- [aws-samples/sample-eks-docs: Auto Mode with a static p6-b200 EFA NodePool](https://github.com/aws-samples/sample-eks-docs/tree/main/ai-ml/set-up-cluster/terraform/auto-mode/nodepools/b-200s-static)
- [Amazon EC2 P5 Instances](https://aws.amazon.com/ec2/instance-types/p5/), [Amazon EC2 P6 Instances](https://aws.amazon.com/ec2/instance-types/p6/)
- [Elastic Fabric Adapter (EFA)](https://aws.amazon.com/hpc/efa/)
- [AWS EFA Kubernetes device plugin chart](https://github.com/aws/eks-charts/tree/master/stable/aws-efa-k8s-device-plugin)
