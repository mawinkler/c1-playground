resource "aws_instance" "web1" {

    # ami                    = "${lookup(var.AMI, var.AWS_REGION)}"
    ami                    = "${data.aws_ami.ubuntu.id}"
    instance_type          = "t2.micro"
    subnet_id              = "${aws_subnet.prod-subnet-public-1.id}"
    vpc_security_group_ids = ["${aws_security_group.ssh-allowed.id}"]
    key_name               = "${aws_key_pair.frankfurt-region-key-pair.id}"

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

    // copy our example script to the server
    provisioner "file" {
        source      = "scripts/get-public-ip.sh"
        destination = "/tmp/get-public-ip.sh"
    }

    // change permissions to executable and pipe its output into a new file
    provisioner "remote-exec" {
        inline = [
            "chmod +x /tmp/get-public-ip.sh",
            "/tmp/get-public-ip.sh > /tmp/public-ip",
        ]
    }

    provisioner "local-exec" {
        # copy the public-ip file back to CWD, which will be tested
        command = "scp -i ${file("${var.PRIVATE_KEY_PATH}")} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${var.EC2_USER}@${aws_instance.web1.public_ip}:/tmp/public-ip public-ip"
    }

    connection {
        user = "${var.EC2_USER}"
        host = self.public_ip
        private_key = "${file("${var.PRIVATE_KEY_PATH}")}"
    }
}

resource "aws_key_pair" "frankfurt-region-key-pair" {
    key_name               = "frankfurt-region-key-pair"
    public_key             = "${file(var.PUBLIC_KEY_PATH)}"
}

# #############################################################################
# Look up the latest Ubuntu AMI
# #############################################################################
data "aws_ami" "ubuntu" {
    most_recent            = true
    owners                 = ["099720109477"] # Canonical

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }

    filter {
        name   = "architecture"
        values = ["x86_64"]
    }

    filter {
        name   = "image-type"
        values = ["machine"]
    }

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }
}