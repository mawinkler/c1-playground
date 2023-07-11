resource "aws_instance" "web1" {

    ami                    = "${data.aws_ami.ubuntu.id}"
    instance_type          = "t3.medium"
    subnet_id              = var.public_subnet
    vpc_security_group_ids = [var.public_sg]
    key_name               = aws_key_pair.key_pair.key_name
    tags = {
        Name = "playground-web1"
    }

    connection {
        user        = "${var.linux_username}"
        host        = self.public_ip
        private_key = "${file("${aws_key_pair.key_pair.key_name}.pem")}"
    }

    # nginx installation
    provisioner "file" {
        source      = "scripts/nginx.sh"
        destination = "/tmp/nginx.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x /tmp/nginx.sh",
            "sudo /tmp/nginx.sh"
        ]
    }

    # wordpress installation
    provisioner "file" {
        source      = "scripts/wordpress.sh"
        destination = "/tmp/wordpress.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x /tmp/wordpress.sh",
            "sudo /tmp/wordpress.sh"
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

    # # xdr basecamp agent deployment
    # provisioner "remote-exec" {
    #     inline = [
    #         "if [ ! -z \"${var.xbc_agent_url}\" ]; then ",
    #         "  cd /tmp",
    #         "  wget ${var.xbc_agent_url} -O /tmp/tmxbc_linux64.tgz",
    #         "  tar -xvf /tmp/tmxbc_linux64.tgz",
    #         "  sudo /tmp/tmxbc install",
    #         "fi",
    #     ]
    # }
}

resource "null_resource" "atomic_web1" {
    count = fileexists("files/atomic_launcher_linux_1.0.0.1009.zip") ? 1 : 0

    triggers = {
        instance_running = aws_instance.web1.instance_state == "running" ? 1 : 0
        #"${timestamp()}"
    }

    provisioner "file" {
        source      = "files/atomic_launcher_linux_1.0.0.1009.zip"
        destination = "/home/ubuntu/atomic_launcher_linux_1.0.0.1009.zip"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo apt-get -y install unzip",
            # "unzip -P virus /home/ubuntu/atomic_launcher_linux_1.0.0.1009.zip"
        ]
    }

    connection {
        user = "${var.linux_username}"
        host = aws_instance.web1.public_ip
        private_key = "${file("${aws_key_pair.key_pair.key_name}.pem")}"
    }
}
