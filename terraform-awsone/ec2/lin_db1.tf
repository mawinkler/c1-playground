resource "aws_instance" "db1" {

    ami                    = "${data.aws_ami.ubuntu.id}"
    instance_type          = "t3.medium"
    subnet_id              = var.public_subnet
    vpc_security_group_ids = [var.public_sg]
    key_name               = aws_key_pair.key_pair.key_name
    tags = {
        Name = "playground-db1"
    }

    connection {
        user        = "${var.linux_username}"
        host        = self.public_ip
        private_key = "${file("${aws_key_pair.key_pair.key_name}.pem")}"
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

    # xdr basecamp agent deployment (V1ES)
    provisioner "file" {
        source = "${path.module}/files/TMServerAgent_Linux_auto_64_Server_-_Workload_Protection_Manager.tar"
        destination = "/tmp/TMServerAgent_Linux_auto_64_Server_-_Workload_Protection_Manager.tar"
    }

    provisioner "file" {
        source = "${path.module}/files/TMServerAgent_Linux_deploy.sh"
        destination = "/tmp/TMServerAgent_Linux_deploy.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x /tmp/TMServerAgent_Linux_deploy.sh",
            "sudo /tmp/TMServerAgent_Linux_deploy.sh"
        ]
    }

    # # dsa installation
    # provisioner "file" {
    #     source      = "scripts/dsa.sh"
    #     destination = "/tmp/dsa.sh"
    # }

    # provisioner "remote-exec" {
    #     inline = [
    #         "chmod +x /tmp/dsa.sh",
    #         "sudo /tmp/dsa.sh"
    #     ]
    # }
}
