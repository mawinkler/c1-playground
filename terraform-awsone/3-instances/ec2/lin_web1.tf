# #############################################################################
# Linux Instance
#   Nginx
#   Wordpress
#   Vision One Server & Workload Protection
#   Atomic Launcher
# #############################################################################
resource "aws_instance" "web1" {

    count                  = var.create_linux ? 1 : 0

    ami                    = "${data.aws_ami.ubuntu.id}"
    instance_type          = "t3.medium"
    subnet_id              = var.public_subnet[0]
    vpc_security_group_ids = [var.public_sg]
    iam_instance_profile   = var.ec2_profile
    key_name               = aws_key_pair.key_pair.key_name

    tags = {
        Name        = "${var.environment}-web1"
        Environment = "${var.environment}"
    }

    user_data = data.template_file.linux_userdata.rendered

    connection {
        user        = "${var.linux_username}"
        host        = self.public_ip
        private_key = "${file("${aws_key_pair.key_pair.key_name}.pem")}"
    }

    # nginx installation
    provisioner "file" {
        source      = "../1-scripts/nginx.sh"
        destination = "/tmp/nginx.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x /tmp/nginx.sh",
            "sudo /tmp/nginx.sh"
        ]
    }

    # # wordpress installation
    # provisioner "file" {
    #     source      = "../1-scripts/wordpress.sh"
    #     destination = "/tmp/wordpress.sh"
    # }

    # provisioner "remote-exec" {
    #     inline = [
    #         "chmod +x /tmp/wordpress.sh",
    #         "sudo /tmp/wordpress.sh"
    #     ]
    # }

    # v1 basecamp installation
    provisioner "remote-exec" {
        inline = [
            "chmod +x $HOME/download/TMServerAgent_Linux_deploy.sh",
            "$HOME/download/TMServerAgent_Linux_deploy.sh"
        ]
    }
}
