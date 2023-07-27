# #############################################################################
# Outputs
# #############################################################################
output "cluster_name" {
  description = "ECS Cluster Name"
  value       = module.ecs-ec2.cluster_name
}

output "cluster_arn" {
  description = "ECS Cluster ARN"
  value       = module.ecs-ec2.cluster_arn
}

output "loadbalancer_dns" {
  value = module.ecs-ec2.loadbalancer_dns
}
