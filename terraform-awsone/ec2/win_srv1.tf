# #############################################################################
# Windows Instance
#   Vision One Server & Workload Protection
#   Atomic Launcher
# #############################################################################
resource "aws_instance" "srv1" {

    count                  = var.create_windows ? 1 : 0

    ami                    = "${data.aws_ami.windows.id}"
    instance_type          = "t3.medium"
    subnet_id              = var.public_subnet
    vpc_security_group_ids = [var.public_sg]
    iam_instance_profile   = var.ec2_profile
    key_name               = aws_key_pair.key_pair.key_name
    tags = {
        Name = "playground-srv1"
    }

    user_data = data.template_file.windows_userdata.rendered
    
    connection {
        host = coalesce(self.public_ip, self.private_ip)
        type = "winrm"
        port = 5986
        user = var.windows_username
        password = var.windows_password
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
