output "eks_cluster_id" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_id
}

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "node_iam_role_name" {
  description = "Name of the EKS Auto Mode node IAM role created by the module and reused by the GPU NodeClass"
  value       = module.eks.node_iam_role_name
}

output "gpu_nodepool" {
  description = "Name of the static GPU NodePool; nodes carry the label karpenter.sh/nodepool=<this value>"
  value       = local.gpu_pool_name
}

output "efa_interfaces_per_node" {
  description = "Number of efa-only network interfaces declared in the GPU NodeClass for var.gpu_instance_type"
  value       = local.efa_cards
}
