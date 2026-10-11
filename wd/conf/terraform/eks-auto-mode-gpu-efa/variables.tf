variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-2"
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
  default     = "do-eks-tf-auto-mode-gpu-efa"
}

variable "cluster_version" {
  description = "EKS Cluster Version"
  type        = string
  default     = "1.35"
}

variable "auto_mode_node_pools" {
  description = "Built-in EKS Auto Mode node pools to create. general-purpose gives CoreDNS and other system pods a place to run and makes EKS create the access entry for the Auto Mode node role, which the GPU NodeClass reuses. Set to [] for a fully custom cluster (then create the node class access entry yourself)."
  type        = list(string)
  default     = ["general-purpose", "system"]
}

variable "gpu_instance_type" {
  description = "GPU instance type for the static NodePool. Must be a key of efa_network_cards. Verified Auto Mode supported types with EFA: p5en.48xlarge (H200), p5e.48xlarge (H200), p6-b200.48xlarge (B200), p5.48xlarge (H100)"
  type        = string
  default     = "p5en.48xlarge"
}

variable "efa_network_cards" {
  description = "Number of network cards (= EFA interfaces) per instance type, from `aws ec2 describe-instance-types --query 'InstanceTypes[].[InstanceType,NetworkInfo.MaximumNetworkCards,NetworkInfo.EfaInfo.MaximumEfaInterfaces]'` (us-east-2, 2026-10-11). Add an entry to use another EFA-capable type."
  type        = map(number)
  default = {
    "p5en.48xlarge"    = 16
    "p5e.48xlarge"     = 32
    "p6-b200.48xlarge" = 8
    "p5.48xlarge"      = 32
  }
}

variable "capacity_reservation_id" {
  description = "Capacity Reservation ID - can be either an On-Demand Capacity Reservation (ODCR) or an ML Capacity Block reservation for gpu_instance_type. On Auto Mode it is selected by the NodeClass (capacityReservationSelectorTerms), not by a node group."
  type        = string
  default     = "cr-xxxxxxxxxxxxxxxxx"
}

variable "gpu_availability_zone" {
  description = "Availability zone for the GPU nodes (must match the capacity reservation AZ). The NodeClass is pinned to the private subnet in this AZ."
  type        = string
  default     = "us-east-2a"
}

variable "gpu_node_count" {
  description = "Number of GPU nodes the static NodePool keeps running (NodePool spec.replicas). Match your reservation."
  type        = number
  default     = 2
}

variable "gpu_node_limit" {
  description = "NodePool limits.nodes. Must exceed gpu_node_count so a node can be replaced during Auto Mode AMI drift without dropping below the desired count. Default: gpu_node_count + 1."
  type        = number
  default     = null
}

variable "pod_ipv4_prefix_count" {
  description = "secondaryIPv4PrefixCount on the primary ENI of each GPU node; each /28 prefix gives 16 pod IPs. With static networkInterfaces Auto Mode adds no IPs after launch, so this fixes the pod capacity per node."
  type        = number
  default     = 1
}

variable "efa_device_plugin_version" {
  description = "Chart version of aws-efa-k8s-device-plugin from https://aws.github.io/eks-charts (EKS Auto Mode does not bundle the EFA device plugin)"
  type        = string
  default     = "v0.5.33"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.13.0.0/16"
}

variable "cluster_enabled_log_types" {
  description = "EKS Cluster Control Plane Logging"
  type        = list(any)
  default     = ["api", "authenticator", "audit", "scheduler", "controllerManager"]
}
