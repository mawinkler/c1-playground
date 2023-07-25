# #############################################################################
# Windows Instance
#   Vision One Server & Workload Protection
#   Atomic Launcher
# #############################################################################
resource "random_password" "windows_password" {
    length           = 16
    special          = true
    override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_instance" "srv1" {

    count                  = var.create_windows ? 1 : 0

    ami                    = "${data.aws_ami.windows.id}"
    instance_type          = "t3.medium"
    subnet_id              = var.public_subnet_ids[1]
    vpc_security_group_ids = [var.public_security_group_id]
    iam_instance_profile   = var.ec2_profile
    key_name               = aws_key_pair.key_pair.key_name

    tags = {
        Name        = "${var.environment}-srv1"
        Environment = "${var.environment}"
    }

    user_data = data.template_file.windows_userdata.rendered
    
    connection {
        host = coalesce(self.public_ip, self.private_ip)
        type = "winrm"
        port = 5986
        user = var.windows_username
        password = random_password.windows_password.result
        https = true
        insecure = true
        timeout = "13m"
    }

    # connection {
    #     host = length(aws_instance.srv1) > 0 ? aws_instance.srv1[0].public_ip : ""
    #     type = "ssh"
    #     user = "${var.windows_username}"
    #     private_key = "${file("${aws_key_pair.key_pair.key_name}.pem")}"
    # }

    # Download packages from S3
    provisioner "remote-exec" {
        inline = [
            "PowerShell -Command Read-S3Object -BucketName ${var.s3_bucket} -KeyPrefix download -Folder Downloads"
        ]
    }

    provisioner "remote-exec" {
        inline = [
            "powershell.exe -ExecutionPolicy Unrestricted -File Downloads/TMServerAgent_Windows_deploy.ps1"
        ]
    }
}
