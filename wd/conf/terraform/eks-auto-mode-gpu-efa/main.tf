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

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}


# Data

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Local config

locals {
  name            = var.cluster_name
  cluster_version = var.cluster_version

  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint      = local.name
    ClusterVersion = local.cluster_version
    BlueprintHome  = "github.com/aws-samples/aws-do-eks/wd/conf/terraform/eks-auto-mode-gpu-efa"
  }

  # GPU nodes live in the one private subnet of the capacity reservation's AZ (EFA peers must share an AZ)
  gpu_subnet_id = module.vpc.private_subnets[index(local.azs, var.gpu_availability_zone)]

  gpu_pool_name  = "gpu-efa"
  gpu_node_limit = coalesce(var.gpu_node_limit, var.gpu_node_count + 1)

  # EFA interface count is looked up per instance type (values verified against the EC2 API, see variables.tf)
  efa_cards = lookup(var.efa_network_cards, var.gpu_instance_type, null)

  # NodeClass advancedNetworking.networkInterfaces:
  #  - card 0 / device 0: the primary ENI, interfaceType must be `interface`; with static networkInterfaces
  #    Auto Mode attaches no further IPs/ENIs after launch, so it declares the pod IP capacity up front
  #  - card 0 / device 1 and cards 1..N-1 / device 0: one efa-only interface per network card
  gpu_network_interfaces = concat(
    [{
      networkCardIndex         = 0
      deviceIndex              = 0
      interfaceType            = "interface"
      secondaryIPv4PrefixCount = var.pod_ipv4_prefix_count
    }],
    [{
      networkCardIndex = 0
      deviceIndex      = 1
      interfaceType    = "efa-only"
    }],
    [for card in range(1, coalesce(local.efa_cards, 1)) : {
      networkCardIndex = card
      deviceIndex      = 0
      interfaceType    = "efa-only"
    }],
  )
}

# Resources

# EKS Auto Mode nodes run Bottlerocket with the NVIDIA drivers and GPU device plugin built in, but the
# EFA Kubernetes device plugin (which advertises vpc.amazonaws.com/efa) is not bundled and is installed
# here, the same way Container-Root/eks/deployment/efa-device-plugin/deploy.sh does it.
resource "helm_release" "efa_device_plugin" {
  name       = "efa"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-efa-k8s-device-plugin"
  version    = var.efa_device_plugin_version
  namespace  = "kube-system"
  wait       = false # the DaemonSet only has pods once GPU nodes exist

  values = [
    yamlencode({
      # the GPU NodePool taints its nodes nvidia.com/gpu:NoSchedule
      tolerations = [{
        key      = "nvidia.com/gpu"
        operator = "Exists"
        effect   = "NoSchedule"
      }]
    })
  ]

  depends_on = [module.eks]
}

# GPU + EFA + capacity reservation NodeClass.
# kubectl_manifest (gavinbunney/kubectl) is used instead of kubernetes_manifest because NodeClass and
# NodePool are CRD-backed kinds: kubernetes_manifest needs the CRDs to exist at plan time, which fails
# before the cluster has been created, while kubectl_manifest only needs the cluster at apply time.
resource "kubectl_manifest" "gpu_nodeclass" {
  yaml_body = yamlencode({
    apiVersion = "eks.amazonaws.com/v1"
    kind       = "NodeClass"
    metadata = {
      name = local.gpu_pool_name
    }
    spec = {
      # Reuse the Auto Mode node IAM role created by the module (role name, not ARN), so the
      # EC2 access entry that EKS created for the built-in node pools already covers these nodes
      role = module.eks.node_iam_role_name
      subnetSelectorTerms = [{
        id = local.gpu_subnet_id
      }]
      # The EKS cluster security group allows all traffic from itself, which is what EFA needs
      securityGroupSelectorTerms = [{
        id = module.eks.cluster_primary_security_group_id
      }]
      # The ODCR / Capacity Block to launch into (bound by karpenter.sh/capacity-type: reserved below)
      capacityReservationSelectorTerms = [{
        id = var.capacity_reservation_id
      }]
      advancedNetworking = {
        networkInterfaces = local.gpu_network_interfaces
      }
      # No advancedCompute.hugepages here: EFA and static hugepages cannot coexist on one NodeClass
      tags = local.tags
    }
  })

  lifecycle {
    precondition {
      condition     = local.efa_cards != null
      error_message = "gpu_instance_type '${var.gpu_instance_type}' has no entry in efa_network_cards; add its network card count from `aws ec2 describe-instance-types --instance-types ${var.gpu_instance_type} --query 'InstanceTypes[].NetworkInfo.MaximumNetworkCards'`."
    }
    precondition {
      condition     = local.gpu_node_limit > var.gpu_node_count
      error_message = "gpu_node_limit must exceed gpu_node_count so Auto Mode can replace a node during AMI drift."
    }
  }

  depends_on = [module.eks]
}

# Static NodePool: holds gpu_node_count reserved GPU nodes regardless of pending pods.
resource "kubectl_manifest" "gpu_nodepool" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = local.gpu_pool_name
    }
    spec = {
      replicas = var.gpu_node_count
      # only limits.nodes is honored on a static pool; keep it above replicas for drift replacement
      limits = {
        nodes = local.gpu_node_limit
      }
      template = {
        spec = {
          nodeClassRef = {
            group = "eks.amazonaws.com"
            kind  = "NodeClass"
            name  = local.gpu_pool_name
          }
          # keeps non-GPU pods off the reserved GPU nodes; GPU pods need a matching toleration
          taints = [{
            key    = "nvidia.com/gpu"
            effect = "NoSchedule"
          }]
          requirements = [
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["reserved"]
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = [var.gpu_instance_type]
            },
            {
              key      = "topology.kubernetes.io/zone"
              operator = "In"
              values   = [var.gpu_availability_zone]
            },
          ]
        }
      }
      # static pools are never consolidated; the budget limits drift/AMI replacement to one node at a time
      disruption = {
        budgets = [{
          nodes = "1"
        }]
      }
    }
  })

  depends_on = [kubectl_manifest.gpu_nodeclass]
}

# EKS Cluster

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.37"

  cluster_name                             = local.name
  cluster_version                          = local.cluster_version
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  cluster_enabled_log_types                = var.cluster_enabled_log_types

  # EKS Auto Mode. AWS runs the compute (built-in Karpenter), pod networking, cluster DNS, block storage
  # and GPU drivers/plugins as cluster capabilities, so there are no coredns/kube-proxy/vpc-cni cluster_addons
  # and no eks_managed_node_groups here. The module creates the Auto Mode node IAM role and forces
  # bootstrap_self_managed_addons = false when compute is enabled.
  cluster_compute_config = {
    enabled    = true
    node_pools = var.auto_mode_node_pools
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

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
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 64)]

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
