# Providers

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# Data

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_availability_zones" "available" {}

data "http" "efa_device_plugin_yaml" {
  url = "https://raw.githubusercontent.com/aws-samples/aws-efa-eks/main/manifest/efa-k8s-device-plugin.yml"
}

data "aws_ami" "eks_gpu_node" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-gpu-node-${local.cluster_version}-*"]
  }
}

# Local config

locals {
  name            = var.cluster_name
  cluster_version = var.cluster_version

  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    Blueprint      = local.name
    ClusterVersion = local.cluster_version
    BlueprintHome  = "github.com/aws-samples/aws-do-eks/wd/conf/terraform/eks-p6-b200"
  }

  nodegroup_sys = var.nodegroup_settings_sys
  nodegroup_gpu = var.nodegroup_settings_gpu
}

# Resources

resource "kubectl_manifest" "efa_device_plugin" {
  yaml_body = <<YAML
${data.http.efa_device_plugin_yaml.response_body}
YAML
}

resource "helm_release" "nvidia_device_plugin" {
  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  version    = "0.17.0"
  namespace  = "kube-system"
}

# EKS Cluster

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true
  cluster_enabled_log_types      = var.cluster_enabled_log_types

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_aws_auth_configmap = false
  manage_aws_auth_configmap = true

  eks_managed_node_group_defaults = {
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }

  eks_managed_node_groups = {

    # System nodegroup - CPU instances for system pods (CoreDNS, kube-proxy, etc.)
    sys = {
      instance_types = [local.nodegroup_sys.instance_type]
      min_size       = local.nodegroup_sys.min_size
      max_size       = local.nodegroup_sys.max_size
      desired_size   = local.nodegroup_sys.desired_size

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = local.nodegroup_sys.vol_size_gb
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
    }

    # GPU nodegroup - p6-b200.48xlarge with EFA networking
    gpu = {
      instance_types             = [local.nodegroup_gpu.instance_type]
      ami_id                     = data.aws_ami.eks_gpu_node.id
      enable_bootstrap_user_data = true

      min_size     = local.nodegroup_gpu.min_size
      max_size     = local.nodegroup_gpu.max_size
      desired_size = local.nodegroup_gpu.desired_size

      # EFA support - the module automatically:
      # - queries the instance type for the number of network cards
      # - creates all EFA network interfaces
      # - creates a placement group
      # - adds security group rules for node-to-node EFA traffic
      enable_efa_support = true

      ebs_optimized     = true
      enable_monitoring = true

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = local.nodegroup_gpu.vol_size_gb
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # Pin GPU nodes to a single AZ for placement group compatibility
      subnet_ids = [module.vpc.private_subnets[0]]

      # Comment out this block to use on-demand instances without a capacity reservation.
      # The capacity_reservation_id can be from either an ODCR or an ML Capacity Block.
      capacity_reservation_specification = {
        capacity_reservation_target = {
          capacity_reservation_id = var.capacity_reservation_id
        }
      }

    }
  }

  tags = local.tags
}

# VPC

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}
