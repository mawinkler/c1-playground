resource "aws_instance" "web1" {

    ami                    = "${data.aws_ami.ubuntu.id}"
    instance_type          = "t3.medium"
    subnet_id              = var.public_subnet
    vpc_security_group_ids = [var.public_sg]
    key_name               = "${aws_key_pair.cnctraining_key_pair.id}"

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

    # # atomic
    # provisioner "file" {
    #     source      = "files/atomic_launcher_linux_1.0.0.1009.zip"
    #     destination = "/home/ubuntu/atomic_launcher_linux_1.0.0.1009.zip"
    # }

    # provisioner "remote-exec" {
    #     count = fileexists("files/atomic_launcher_linux_1.0.0.1009.zip") ? 1 : 0
    #     inline = [
    #         "sudo apt-get -y install unzip",
    #         "unzip -P virus /home/ubuntu/atomic_launcher_linux_1.0.0.1009.zip"
    #     ]
    # }

    # xdr
    provisioner "remote-exec" {
        inline = [
            "if [ ! -z \"${var.xbc_agent_url}\" ]; then ",
            "  cd /tmp",
            "  wget ${var.xbc_agent_url} -O /tmp/tmxbc_linux64.tgz",
            "  tar -xvf /tmp/tmxbc_linux64.tgz",
            "  sudo /tmp/tmxbc install",
            "fi",
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
        command = "scp -i ${var.private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${var.ec2_user}@${aws_instance.web1.public_ip}:/tmp/public-ip public-ip"
    }

    connection {
        user = "${var.ec2_user}"
        host = self.public_ip
        private_key = "${file("${var.private_key_path}")}"
    }
}

resource "null_resource" "atomic_zip" {
    count = fileexists("files/atomic_launcher_linux_1.0.0.1009.zip") ? 1 : 0

    provisioner "file" {
        source      = "files/atomic_launcher_linux_1.0.0.1009.zip"
        destination = "/home/ubuntu/atomic_launcher_linux_1.0.0.1009.zip"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo apt-get -y install unzip",
            "unzip -P virus /home/ubuntu/atomic_launcher_linux_1.0.0.1009.zip"
        ]
    }

    connection {
        user = "${var.ec2_user}"
        host = aws_instance.web1.public_ip
        private_key = "${file("${var.private_key_path}")}"
    }
}