# #############################################################################
# Outputs
# #############################################################################
output "public_instance_id_web1" {
    # value = "${aws_instance.web1.id}"
    value = length(aws_instance.web1) > 0 ? aws_instance.web1[0].id : ""
}

output "public_instance_ip_web1" {
    # value = "${aws_instance.web1.public_ip}"
    value = length(aws_instance.web1) > 0 ? aws_instance.web1[0].public_ip : ""
}

output "public_instance_id_db1" {
    # value = "${aws_instance.db1.id}"
    value = length(aws_instance.db1) > 0 ? aws_instance.db1[0].id : ""
}

output "public_instance_ip_db1" {
    # value = "${aws_instance.db1.public_ip}"
    value = length(aws_instance.db1) > 0 ? aws_instance.db1[0].public_ip : ""
}

output "public_instance_id_srv1" {
    # value = "${aws_instance.srv1.id}"
    value = length(aws_instance.srv1) > 0 ? aws_instance.srv1[0].id : ""
}

output "public_instance_ip_srv1" {
    # value = "${aws_instance.srv1.public_ip}"
    value = length(aws_instance.srv1) > 0 ? aws_instance.srv1[0].public_ip : ""
}

output "private_key_path" {
    value = "${aws_key_pair.key_pair.key_name}.pem"
}
