resource "aws_instance" "db1" {

    ami                    = "${data.aws_ami.ubuntu.id}"
    instance_type          = "t3.medium"
    subnet_id              = var.public_subnet
    vpc_security_group_ids = [var.public_sg]
    key_name               = "${aws_key_pair.cnctraining_key_pair.id}"
    tags = {
        Name = "playground-db1"
    }

    # mysql installation
    provisioner "file" {
        source      = "scripts/mysql.sh"
        destination = "/tmp/mysql.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x /tmp/mysql.sh",
            "sudo /tmp/mysql.sh"
        ]
    }

    # dsa installation
    provisioner "file" {
        source      = "scripts/dsa.sh"
        destination = "/tmp/dsa.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x /tmp/dsa.sh",
            "sudo /tmp/dsa.sh"
        ]
    }

    # copy get public ip script
    provisioner "file" {
        source      = "scripts/get-public-ip.sh"
        destination = "/tmp/get-public-ip.sh"
    }

    # change permissions to executable and pipe its output into a new file
    provisioner "remote-exec" {
        inline = [
            "chmod +x /tmp/get-public-ip.sh",
            "/tmp/get-public-ip.sh > /tmp/public-ip",
        ]
    }

    # copy the public-ip file back to CWD, which will be tested
    provisioner "local-exec" {
        command = "scp -i ${var.private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${var.ec2_user}@${aws_instance.db1.public_ip}:/tmp/public-ip public-ip"
    }

    connection {
        user = "${var.ec2_user}"
        host = self.public_ip
        private_key = "${file("${var.private_key_path}")}"
    }
}
