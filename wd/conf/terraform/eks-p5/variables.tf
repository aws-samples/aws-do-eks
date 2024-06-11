variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
  default     = "do-eks-tf-p5"
}

variable "cluster_version" {
  description = "EKS Cluster Version"
  type        = string
  default     = "1.28"
}

variable "odcr_id" {
  description = "On-demand Capacity Reservation ID"
  type        = string
  default     = "cr-xxxxxxxxxxxxxxxxx"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.11.0.0/16"
}

variable "nodegroup_settings_sys" {
  description = "Settings for the system nodegroup"
  type        = object({
    instance_type = string
    min_size     = string
    max_size     = string
    desired_size = string
    vol_size_gb  = string 
  })
  default = {
    instance_type = "m5.large"
    min_size     = "0"
    max_size     = "6"
    desired_size = "0"
    vol_size_gb   = "50"
  }
}

variable "nodegroup_settings_gpu" {
  description = "Settings for the gpu nodegroup"
  type        = object({
    instance_type = string
    min_size     = string
    max_size     = string
    desired_size = string
    vol_size_gb  = string
  })
  default = {
    instance_type = "p5.48xlarge"
    min_size     = "0"
    max_size     = "128"
    desired_size = "2"
    vol_size_gb  = "500"
  }
}

variable "cluster_enabled_log_types" {
  description = "EKS Cluster Control Plane Logging"
  type        = list(any)
  default     = ["api", "authenticator", "audit", "scheduler", "controllerManager"]
}
