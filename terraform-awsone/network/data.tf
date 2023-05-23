# Get Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}