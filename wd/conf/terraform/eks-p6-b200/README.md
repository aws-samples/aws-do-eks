# EKS Cluster with P6-B200.48xlarge Node Group and 32 EFA Interfaces

## Overview

This Terraform configuration creates an Amazon EKS cluster from scratch in a new VPC, configured with NVIDIA B200 GPU instances (p6-b200.48xlarge) and Elastic Fabric Adapter (EFA) networking.

## P6-B200 Instance Type

Amazon EC2 P6-B200 instances feature:
- 8 NVIDIA Blackwell B200 GPUs with 1440 GB of high-bandwidth GPU memory
- 192 vCPUs (5th Gen Intel Xeon Scalable - Emerald Rapids)
- 2 TiB system memory
- 30 TB local NVMe storage
- Up to 3.2 Tbps EFAv4 networking (32 EFA adapters)

## Architecture

The cluster is deployed with two managed node groups:

1. **sys** - CPU instances (m5.2xlarge by default) for running system pods such as CoreDNS, kube-proxy, and other cluster services. Default: 1 instance.

2. **gpu** - P6-B200.48xlarge instances with full EFA networking enabled across all 32 network cards. Default: 2 instances.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0.1
- kubectl
- An On-Demand Capacity Reservation (ODCR) for p6-b200.48xlarge instances, or comment out the `capacity_reservation_specification` block in `main.tf`

## Usage

### 1. Configure

Edit [variables.tf](variables.tf) to adjust defaults as needed. Key settings:
- `cluster_version`: EKS version (default: 1.35)
- `nodegroup_settings_gpu`: GPU nodegroup size and instance type
- `nodegroup_settings_sys`: System nodegroup size and instance type
- `odcr_id`: Your capacity reservation ID

If you are **not** using an ODCR, comment out the `capacity_reservation_specification` block in [main.tf](main.tf).

### 2. Initialize

```bash
cd wd/conf/terraform/eks-p6-b200
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

Cluster creation takes approximately 15 minutes.

### 5. Connect

```bash
aws eks update-kubeconfig --region <your-region> --name do-eks-tf-p6-b200
kubectl get nodes -L node.kubernetes.io/instance-type
```

### 6. Cleanup

```bash
terraform destroy
```

## Inputs

| Variable | Description | Default |
|----------|-------------|---------|
| aws_region | AWS Region | us-east-2 |
| cluster_name | EKS cluster name | do-eks-tf-p6-b200 |
| cluster_version | EKS version | 1.35 |
| odcr_id | On-Demand Capacity Reservation ID | cr-xxxxxxxxxxxxxxxxx |
| vpc_cidr | VPC CIDR block | 10.12.0.0/16 |
| nodegroup_settings_sys | System nodegroup config | m5.2xlarge, 1 instance |
| nodegroup_settings_gpu | GPU nodegroup config | p6-b200.48xlarge, 2 instances, 500GB disk |

## Outputs

| Output | Description |
|--------|-------------|
| eks_cluster_id | The EKS cluster ID |
| configure_kubectl | Command to configure kubectl |

## References

- [Amazon EC2 P6-B200 Instances](https://aws.amazon.com/ec2/instance-types/p6/)
- [Elastic Fabric Adapter (EFA)](https://aws.amazon.com/hpc/efa/)
- [EFA on EKS](https://github.com/aws-samples/aws-efa-eks/)
- [NVIDIA Device Plugin for Kubernetes](https://github.com/NVIDIA/k8s-device-plugin)
