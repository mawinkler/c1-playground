resource "aws_instance" "srv1" {

    ami                    = "${data.aws_ami.windows.id}"
    instance_type          = "t3.medium"
    subnet_id              = var.public_subnet
    vpc_security_group_ids = [var.public_sg]
    key_name               = aws_key_pair.key_pair.key_name
    tags = {
        Name = "playground-srv1"
    }

    user_data = data.template_file.windows-userdata.rendered
    
    connection {
        host = coalesce(self.public_ip) #, self.private_ip)
        type = "winrm"
        port = 5986
        user = var.windows_username
        password = var.windows_password
        https = true
        insecure = true
        timeout = "13m"
    }

    # xdr basecamp agent deployment
    provisioner "file" {
        source = "${path.module}/files/TMServerAgent_Windows_auto_64_Server_-_Workload_Protection_Manager.zip"
        destination = "C:/Windows/Temp/TMServerAgent_Windows_auto_64_Server_-_Workload_Protection_Manager.zip"
    }

    provisioner "file" {
        source = "${path.module}/files/TMServerAgent_Windows_deploy.ps1"
        destination = "C:/Windows/Temp/TMServerAgent_Windows_deploy.ps1"
    }

    provisioner "remote-exec" {
        inline = [
            "powershell.exe -ExecutionPolicy Unrestricted -File C:/Windows/Temp/TMServerAgent_Windows_deploy.ps1"
        ]
    }
}

resource "null_resource" "atomic_srv1" {
    count = fileexists("files/atomic_launcher_windows_1.0.0.1013.zip") ? 1 : 0

    triggers = {
        instance_running = aws_instance.srv1.instance_state == "running" ? 1 : 0
    }

    connection {
        host = aws_instance.srv1.public_ip
        type = "winrm"
        port = 5986
        user = var.windows_username
        password = var.windows_password
        https = true
        insecure = true
        timeout = "13m"
    }

    provisioner "file" {
        source      = "files/atomic_launcher_windows_1.0.0.1013.zip"
        destination = "C:/Windows/Temp/atomic_launcher_windows_1.0.0.1013.zip"
    }

    # provisioner "remote-exec" {
    #     inline = [
    #         "PowerShell -Command Expand-Archive -LiteralPath 'C:/Windows/Temp/atomic_launcher_windows_1.0.0.1013.zip' -DestinationPath C:/Windows/Temp -Force"
    #     ]
    # }
}
