# #############################################################################
# Outputs
# #############################################################################
output "public_instance_id_web1" {
  value = length(aws_instance.web1) > 0 ? aws_instance.web1[0].id : ""
}

output "public_instance_ip_web1" {
  value = length(aws_instance.web1) > 0 ? aws_instance.web1[0].public_ip : ""
}

output "public_instance_id_db1" {
  value = length(aws_instance.db1) > 0 ? aws_instance.db1[0].id : ""
}

output "public_instance_ip_db1" {
  value = length(aws_instance.db1) > 0 ? aws_instance.db1[0].public_ip : ""
}

output "public_instance_id_srv1" {
  value = length(aws_instance.srv1) > 0 ? aws_instance.srv1[0].id : ""
}

output "public_instance_ip_srv1" {
  value = length(aws_instance.srv1) > 0 ? aws_instance.srv1[0].public_ip : ""
}

output "private_key_path" {
  value = "${aws_key_pair.key_pair.key_name}.pem"
}

output "windows_password" {
  value = random_password.windows_password.result
}

output "ssh_instance_db1" {
  description = "Command to ssh to instance db1"
  value       = length(aws_instance.db1) > 0 ? "ssh -i ${aws_key_pair.key_pair.key_name}.pem -o StrictHostKeyChecking=no ubuntu@${aws_instance.db1[0].public_ip}" : ""
}

output "ssh_instance_web1" {
  description = "Command to ssh to instance web1"
  value       = length(aws_instance.web1) > 0 ? "ssh -i ${aws_key_pair.key_pair.key_name}.pem -o StrictHostKeyChecking=no ubuntu@${aws_instance.web1[0].public_ip}" : ""
}

output "ssh_instance_srv1" {
  description = "Command to ssh to instance srv1"
  value       = length(aws_instance.srv1) > 0 ? "ssh -i ${aws_key_pair.key_pair.key_name}.pem -o StrictHostKeyChecking=no ${var.windows_username}@${aws_instance.srv1[0].public_ip}" : ""
}
