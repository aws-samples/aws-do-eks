variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-2"
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
  default     = "do-eks-tf-p6-b200"
}

variable "cluster_version" {
  description = "EKS Cluster Version"
  type        = string
  default     = "1.35"
}

variable "gpu_ami_name_pattern" {
  description = "Name pattern for the GPU AMI lookup"
  type        = string
  default     = "amazon-eks-node-al2023-x86_64-nvidia-1.35-*"
}

variable "gpu_node_group_type" {
  description = "Type of node group for GPU instances. Valid values: managed, self-managed, use managed if capacity reservation is active, self-managed if CR is not yet active"
  type        = string
  default     = "managed"
}

variable "gpu_capacity_type" {
  description = "Capacity type for the GPU nodegroup. Valid values: ON_DEMAND, SPOT, CAPACITY_BLOCK"
  type        = string
  default     = "CAPACITY_BLOCK"
}

variable "gpu_availability_zone" {
  description = "Availability zone for the GPU nodegroup (must match the capacity reservation AZ)"
  type        = string
  default     = "us-east-2b"
}

variable "capacity_reservation_id" {
  description = "Capacity Reservation ID - can be either an On-Demand Capacity Reservation (ODCR) or an ML Capacity Block reservation"
  type        = string
  default     = "cr-xxxxxxxxxxxxxxxxx"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.12.0.0/16"
}

variable "nodegroup_settings_sys" {
  description = "Settings for the system nodegroup (CPU instances for system pods)"
  type = object({
    instance_type = string
    min_size      = string
    max_size      = string
    desired_size  = string
    vol_size_gb   = string
  })
  default = {
    instance_type = "m5.8xlarge"
    min_size      = "1"
    max_size      = "4"
    desired_size  = "1"
    vol_size_gb   = "300"
  }
}

variable "nodegroup_settings_gpu" {
  description = "Settings for the GPU nodegroup (p6-b200.48xlarge with EFA)"
  type = object({
    instance_type = string
    min_size      = string
    max_size      = string
    desired_size  = string
    vol_size_gb   = string
  })
  default = {
    instance_type = "p6-b200.48xlarge"
    min_size      = "0"
    max_size      = "128"
    desired_size  = "2"
    vol_size_gb   = "500"
  }
}

variable "cluster_enabled_log_types" {
  description = "EKS Cluster Control Plane Logging"
  type        = list(any)
  default     = ["api", "authenticator", "audit", "scheduler", "controllerManager"]
}

