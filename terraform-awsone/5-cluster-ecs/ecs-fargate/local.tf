locals {
  # container_name = "ecs-sample"
  # container_port = 80
  container_name = "java-goof"
  container_port = 8080

  tags = {
    Name        = "${var.environment}-ecs-fargate"
    Environment = "${var.environment}"
  }
}
