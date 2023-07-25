# #############################################################################
# Outputs
# #############################################################################
output "update_local_context_command" {
  description = "Command to update local kube context"
  value       = "aws eks update-kubeconfig --name=${module.eks.cluster_name} --alias=${module.eks.cluster_name} --region=${var.aws_region}"
}
