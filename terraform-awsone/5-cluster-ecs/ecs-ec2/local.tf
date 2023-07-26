locals {
  container_name = "ecs-sample"
  container_port = 80

  tags = {
    Name        = "${var.environment}-ecs-ec2"
    Environment = "${var.environment}"
  }
}