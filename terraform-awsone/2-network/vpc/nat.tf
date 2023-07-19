
# #############################################################################
# Create
#   NAT gateway
# #############################################################################
# Elastic IP for NAT
resource "aws_eip" "nat_eip" {
  depends_on = [aws_internet_gateway.ig]
  domain     = "vpc"
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)
  depends_on    = [aws_internet_gateway.ig]

  tags = {
    Name        = "nat"
    Environment = "${var.environment}"
  }
}
