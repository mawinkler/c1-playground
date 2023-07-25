output "vpc_id" {
  value = module.network.vpc_id
}

output "public_security_group_id" {
  value = module.network.public_security_group_id
}

output "private_security_group_id" {
  value = module.network.private_security_group_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}
