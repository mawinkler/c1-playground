output "public_instance_id" {
    value = "${aws_instance.web1.id}"
}

output "public_instance_ip" {
    value = "${aws_instance.web1.public_ip}"
}
