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
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}


# Data

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_availability_zones" "available" {}


data "aws_ami" "eks_gpu_node" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.gpu_ami_name_pattern]
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
  gpu_subnet_id = module.vpc.private_subnets[index(local.azs, var.gpu_availability_zone)]
}

# Resources




# EKS Cluster

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true
  enable_efa_support = true
  cluster_enabled_log_types      = var.cluster_enabled_log_types

  cluster_addons = {
    coredns = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    vpc-cni = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets


  eks_managed_node_group_defaults = {
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }

  eks_managed_node_groups = merge({

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

  }, var.gpu_node_group_type == "managed" ? {

    # GPU nodegroup - managed (use when capacity block is active)
    # Requires: capacity_type = CAPACITY_BLOCK, instance_market_options, and
    # capacity_reservation_specification on the launch template per AWS docs:
    # https://docs.aws.amazon.com/eks/latest/userguide/capacity-blocks-mng.html
    gpu = {
      instance_types = [local.nodegroup_gpu.instance_type]
      capacity_type  = var.gpu_capacity_type
      ami_type       = "AL2023_x86_64_NVIDIA"

      min_size     = local.nodegroup_gpu.min_size
      max_size     = local.nodegroup_gpu.max_size
      desired_size = local.nodegroup_gpu.desired_size

      enable_efa_support = true
      ebs_optimized      = true
      enable_monitoring  = true

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

      subnet_ids = [local.gpu_subnet_id]

      instance_market_options = {
        market_type = "capacity-block"
      }

      capacity_reservation_specification = {
        capacity_reservation_preference = "capacity-reservations-only"
        capacity_reservation_target = {
          capacity_reservation_id = var.capacity_reservation_id
        }
      }
    }
  } : {})
  # GPU node group - self-managed (use when capacity block is not yet active)
  # Set var.gpu_node_group_type = "self-managed" to use this
  self_managed_node_groups = var.gpu_node_group_type == "self-managed" ? {
    gpu = {
      instance_type = local.nodegroup_gpu.instance_type
      ami_type      = "AL2023_x86_64_NVIDIA"

      min_size     = local.nodegroup_gpu.min_size
      max_size     = local.nodegroup_gpu.max_size
      desired_size = local.nodegroup_gpu.desired_size

      enable_efa_support = true
      ebs_optimized      = true
      enable_monitoring  = true

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

      subnet_ids = [local.gpu_subnet_id]

      instance_market_options = {
        market_type = "capacity-block"
      }

      capacity_reservation_specification = {
        capacity_reservation_preference = "capacity-reservations-only"
        capacity_reservation_target = {
          capacity_reservation_id = var.capacity_reservation_id
        }
      }

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  } : {}

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
