output "vpc_id" {
  value = module.network.vpc_id
}

output "public_sg" {
  value = module.network.public_sg
}

output "private_sg" {
  value = module.network.private_sg
}

output "public_subnet" {
  value = module.network.public_subnet
}

output "private_subnet" {
  value = module.network.private_subnet
}
