terraform {
  # terraform-aws-modules/eks v20.37.x requires Terraform >= 1.3.2
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # terraform-aws-modules/eks v20.37.x pins hashicorp/aws ">= 5.95, < 6.0.0"
      version = ">= 5.95, < 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    helm = {
      source = "hashicorp/helm"
      # the `kubernetes = { ... }` provider block in main.tf is helm 3.x syntax
      version = ">= 3.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
  }
}
