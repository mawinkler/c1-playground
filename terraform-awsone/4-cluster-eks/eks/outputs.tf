# #############################################################################
# Outputs
# #############################################################################
output "update_local_context_command" {
  description = "Command to update local kube context"
  value       = "aws eks update-kubeconfig --name=${var.environment}_eks --alias=${var.environment}_eks --region=${var.aws_region}"
}
