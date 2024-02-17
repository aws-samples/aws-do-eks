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
    Blueprint  = local.name
    ClusterVersion = local.cluster_version
    BlueprintHome = "github.com/aws-samples/aws-do-eks/wd/conf/terraform/eks-p5"
  }

  nodegroup_sys = var.nodegroup_settings_sys
  nodegroup_gpu = var.nodegroup_settings_gpu

}

# Resources

resource "aws_placement_group" "efa_pg" {
  name     = "efa_pg"
  strategy = "cluster"
}

resource "kubectl_manifest" "efa_device_plugin" {
  yaml_body = <<YAML
${data.http.efa_device_plugin_yaml.response_body}
YAML
}

resource "helm_release" "k8s_device_plugin" {
  name       = "k8s-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  version    = "0.14.0"
  namespace  = "kube-system"
}

# Upstream Terraform Modules

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.12"

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

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ingress traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_self_all = {
      description = "Node to node all egress traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      self        = true
    }
  }

  eks_managed_node_group_defaults = {
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }

  eks_managed_node_groups = {

    sys = {
      instance_types = [local.nodegroup_sys.instance_type]
      min_size       = local.nodegroup_sys.min_size
      max_size       = local.nodegroup_sys.max_size
      desired_size   = local.nodegroup_sys.desired_size
      network_interfaces = [
        {
          description                 = "ENA interface"
          delete_on_termination       = true
          device_index                = 0
          associate_public_ip_address = false
          interface_type              = "interface"
          network_card_index          = 0
        }
      ]
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

    gpu = {
      instance_types = [local.nodegroup_gpu.instance_type]
      ami_id        = data.aws_ami.eks_gpu_node.id
      enable_bootstrap_user_data = true
      
      min_size     = local.nodegroup_gpu.min_size
      max_size     = local.nodegroup_gpu.max_size
      desired_size = local.nodegroup_gpu.desired_size
      
      placement = {
        group_name = aws_placement_group.efa_pg.name
      }

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

      subnet_ids = [module.vpc.private_subnets[0]]

      network_interfaces = [
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 0
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 0
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 1
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 2
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 3
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 4
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 5
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 6
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 7
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 8
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 9
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 10
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 11
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 12
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 13
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 14
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 15
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 16
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 17
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 18
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 19
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 20
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 21
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 22
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 23
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 24
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 25
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 26
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 27
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 28
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 29
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 30
        },
        {
          description                 = "EFA interface"
          delete_on_termination       = true
          device_index                = 1
          associate_public_ip_address = false
          interface_type              = "efa"
          network_card_index          = 31
        },

      ]

      # Comment out this block to use on-demand instances without ODCR
      capacity_reservation_specification = {
        capacity_reservation_id = var.odcr_id
      }

      #post_bootstrap_user_data = <<-EOT
      #  # Install EFA
      #  curl -O https://efa-installer.amazonaws.com/aws-efa-installer-latest.tar.gz
      #  tar -xf aws-efa-installer-latest.tar.gz && cd aws-efa-installer
      #  ./efa_installer.sh -y
      #  fi_info -p efa -t FI_EP_RDM
      #  # Disable ptrace
      #  sysctl -w kernel.yama.ptrace_scope=0
      #EOT

    }
  }

  tags = local.tags
}

# Supporting modules

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

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
