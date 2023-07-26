# #############################################################################
# Outputs
# #############################################################################
output "cluster_name" {
  description = ""
  value       = module.ecs.cluster_name
}

output "cluster_arn" {
  description = ""
  value       = module.ecs.cluster_arn
}
