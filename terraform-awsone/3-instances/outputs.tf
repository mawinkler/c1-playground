output "public_instance_id_web1" {
    value = module.ec2.public_instance_id_web1
}

output "public_instance_ip_web1" {
    value = module.ec2.public_instance_ip_web1
}

output "public_instance_id_db1" {
    value = module.ec2.public_instance_id_db1
}

output "public_instance_ip_db1" {
    value = module.ec2.public_instance_ip_db1
}

output "public_instance_id_srv1" {
    value = module.ec2.public_instance_id_srv1
}

output "public_instance_ip_srv1" {
    value = module.ec2.public_instance_ip_srv1
}

output "public_instance_password_srv1" {
    value = module.ec2.windows_password
    sensitive = true
}

output "private_key_path" {
    value = module.ec2.private_key_path
}

output "s3_bucket" {
    value = module.s3.s3_bucket
}

output "ssh_instance_db1" {
    value = module.ec2.ssh_instance_db1
}

output "ssh_instance_web1" {
    value = module.ec2.ssh_instance_web1
}

output "ssh_instance_srv1" {
    value = module.ec2.ssh_instance_srv1
}
