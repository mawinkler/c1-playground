# #############################################################################
# Outputs
# #############################################################################
output "cluster_name" {
  description = ""
  value       = module.ecs-ec2.cluster_name
}

output "cluster_arn" {
  description = ""
  value       = module.ecs-ec2.cluster_arn
}