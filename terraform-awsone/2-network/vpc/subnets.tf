# #############################################################################
# Create Subnets
#   Public subnets
#   Private subnets
# #############################################################################
# Public subnets
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.vpc.id
  count      = length(var.public_subnets_cidr)
  cidr_block = element(var.public_subnets_cidr, count.index)
  # availability_zone       = "${element(var.availability_zones,   count.index)}"
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.environment}-${element(data.aws_availability_zones.available.names, count.index)}-public-subnet"
    Environment              = "${var.environment}"
    "kubernetes.io/role/elb" = 1
  }
}

# Private subnets
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.vpc.id
  count      = length(var.private_subnets_cidr)
  cidr_block = element(var.private_subnets_cidr, count.index)
  # availability_zone       = "${element(var.availability_zones,   count.index)}"
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name                              = "${var.environment}-${element(data.aws_availability_zones.available.names, count.index)}-private-subnet"
    Environment                       = "${var.environment}"
    "kubernetes.io/role/internal-elb" = 1
  }
}
