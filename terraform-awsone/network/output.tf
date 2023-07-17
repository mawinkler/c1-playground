# #############################################################################
# Outputs
# #############################################################################
output "vpc_id" {
  value = aws_vpc.pg_vpc.id
}

output "public_sg" {
  value = aws_security_group.pg_sg["public"].id
}

output "public_subnet" {
  value = aws_subnet.pg_public_subnet.id
}
