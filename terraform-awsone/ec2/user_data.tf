# #############################################################################
# Windows Userdata to create a new local administrator with
# the configured password
# Configures WinRM, SSHD and AWS.Tools
# #############################################################################
data "template_file" "windows_userdata" {
    template = <<EOF
<powershell>
Start-Transcript -Path 'C:/userdata.log'

$logfilepath="C:\agent.log"
$fqdn="$env:computername"
$port_winrm=5986 
$port_ssh=22
$username = '${var.windows_username}'
$password = ConvertTo-SecureString '${var.windows_password}' -AsPlainText -Force 

Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser -Force -ErrorAction Ignore
$ErrorActionPreference = "stop"


function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string] $message,
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO","WARN","ERROR")]
        [string] $level = "INFO"
    )
    # Create timestamp
    $timestamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    # Append content to log file
    Add-Content -Path $logfilepath -Value "$timestamp [$level] - $message"
}


function Create-LocalAdmin {
    process {
        try {
            # Create new local user
            New-LocalUser "$username" -Password $password -FullName "$username" -Description "local admin" -ErrorAction stop
            Write-Log -message "$username local user created"

            # Add user to administrator group
            Add-LocalGroupMember -Group "Administrators" -Member "$username" -ErrorAction stop
            Write-Log -message "$username added to the Administrators group"

        } catch{ Write-log -message $_.Exception.message -level "ERROR"}
    }    
}


function Delete-WinRMListener {
    process {
        $config = winrm enumerate winrm/config/listener
        foreach($conf in $config) {
            Write-Log -message "verifying listener configuration"
            if($conf.Contains("HTTPS")) {
                try {
                    Write-Log -message "HTTPS is already configured. Deleting the exisiting configuration"
                    Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse
                } catch { Write-log -message "Remove HTTPS listener - " + $_.Exception.message -level "ERROR"}
                break
            }
        }
    }
}


function Configure-WinRMHttpsListener {
    
    Delete-WinRMListener
    
    try {
        Write-Log -message "creating self-signed certificate"
        $Cert = (New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -dnsname $fqdn -NotAfter (Get-Date).AddMonths(36)).Thumbprint
        
        if(-not $Cert) {
            throw "Failed to create the test certificate."
            Write-Log -message "failed to create certificate" -level "ERROR"
        }
        $WinrmCreate= "winrm create --% winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname=`"$fqdn`";CertificateThumbprint=`"$Cert`"}"
        invoke-expression $WinrmCreate
        winrm set winrm/config/service/auth '@{Basic="true"}'
    } catch { Write-log -message "Create certificate - "+ $_.Exception.message -level "ERROR"}
    
}


function Add-FirewallRule-WinRM {
    
    try {
        # Delete an exisitng rule
        Write-Log -message "Deleting the existing firewall rule for port $port_winrm"
        netsh advfirewall firewall delete rule name="Windows Remote Management (HTTPS-In)" dir=in protocol=TCP localport=$port_winrm | Out-Null

        # Add a new firewall rule
        Write-Log -message "Adding the firewall rule for port $port_winrm"
        netsh advfirewall firewall add rule name="Windows Remote Management (HTTPS-In)" dir=in action=allow protocol=TCP localport=$port_winrm | Out-Null
    } catch { Write-log -message "Add/Remove firewall rule - "+ $_.Exception.message -level "ERROR"}
    
}

function Add-FirewallRule-SSH {
    
    try {
        # Delete an exisitng rule
        Write-Log -message "Deleting the existing firewall rule for port $port_ssh"
        netsh advfirewall firewall delete rule name="SSH Daemon (SSH-In)" dir=in protocol=TCP localport=$port_ssh | Out-Null

        # Add a new firewall rule
        Write-Log -message "Adding the firewall rule for port $port_ssh"
        netsh advfirewall firewall add rule name="SSH Daemon (SSH-In)" dir=in action=allow protocol=TCP localport=$port_ssh | Out-Null
    } catch { Write-log -message "Add/Remove firewall rule - "+ $_.Exception.message -level "ERROR"}
    
}

function Configure-WinRMService {

    try {
        Write-Log -message "Configuring winrm service"
        netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=yes
        cmd.exe /c winrm quickconfig -q
        cmd.exe /c winrm set "winrm/config" '@{MaxTimeoutms="1800000"}'
        cmd.exe /c winrm set "winrm/config/winrs" '@{MaxMemoryPerShellMB="1024"}'
        cmd.exe /c winrm set "winrm/config/service" '@{AllowUnencrypted="false"}'
        cmd.exe /c winrm set "winrm/config/client" '@{AllowUnencrypted="false"}'
        cmd.exe /c winrm set "winrm/config/service/auth" '@{Basic="true"}'
        cmd.exe /c winrm set "winrm/config/client/auth" '@{Basic="true"}'
        cmd.exe /c winrm set "winrm/config/service/auth" '@{CredSSP="true"}'
    } catch  { Write-log -message "configure winrm service - "+ $_.Exception.message -level "ERROR"}
}

function Configure-OpenSSHService {

    try {
        Write-Log -message "Adding OpenSSH.Server"
        Add-WindowsCapability -Online -Name OpenSSH.Server
        Add-WindowsCapability -Online -Name OpenSSH.Client

        Write-Log -message "Enabling automatic startup for OpenSSH.Server"
        Get-Service sshd | Set-Service -StartupType Automatic

        Write-Log -message "Starting OpenSSH.Server"
        Start-Service sshd

        # Write-Log -message "Setting default shell for OpenSSH.Server"
        New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value (Get-Command powershell.exe).Path -PropertyType String -Force

        # Get the public key 
        $authorizedKey = "${trimspace(tls_private_key.key_pair.public_key_openssh)}"
        # New-Item -Force -ItemType Directory -Path $env:USERPROFILE\.ssh; Add-Content -Force -Path $env:USERPROFILE\.ssh\authorized_keys -Value $authorizedKey
        # New-Item -Force -ItemType Directory -Path C:\Users\${var.windows_username}\.ssh; Add-Content -Force -Path C:\Users\${var.windows_username}\.ssh\authorized_keys -Value $authorizedKey
        New-Item -Force -ItemType File -Path C:\ProgramData\ssh\administrators_authorized_keys
        Add-Content -Force -Path C:\ProgramData\ssh\administrators_authorized_keys -Value $authorizedKey

        # Set the config to allow the pubkey auth
        $sshd_config="C:\ProgramData\ssh\sshd_config"
        (Get-Content $sshd_config) -replace '#PubkeyAuthentication', 'PubkeyAuthentication' | Out-File -encoding ASCII $sshd_config
        (Get-Content $sshd_config) -replace 'AuthorizedKeysFile	.ssh/authorized_keys', '#AuthorizedKeysFile	.ssh/authorized_keys' | Out-File -encoding ASCII $sshd_config
        # (Get-Content $sshd_config) -replace 'AuthorizedKeysFile __PROGRAMDATA__', 'AuthorizedKeysFile __PROGRAMDATA__' | Out-File -encoding ASCII $sshd_config
        # (Get-Content $sshd_config) -replace 'Match Group administrators', '#Match Group administrators' | Out-File -encoding ASCII $sshd_config

        # Set proper permissions on administrators_authorized_keys
        icacls.exe "C:\ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"

        Get-Content C:\ProgramData\ssh\sshd_config

        # Reload the config
        Write-Log -message "Reload the config"
        Restart-Service sshd

        Write-Log -message "OpenSSH.Server running"
    } catch  { Write-log -message "configure openssh service - "+ $_.Exception.message -level "ERROR"}
}

function Configure-AWS-Tools {

    $ListofModulesInstalled = (Get-InstalledModule).Name
    Write-Log -message "Ckecking if AWS.Tools.Installer is installed on this instance."
    
    if ($ListofModulesInstalled -contains "AWS.Tools.Installer") { 
        Write-Log -message "AWS.Tools.Installer module exists."
    } else { 
        Write-Log -message "AWS.Tools.Installer module does not exist and needs to be installed."
        $ListofPackagesInstalled = (Get-PackageProvider -ListAvailable).Name
        Write-Log -message "AWS.Tools.Installer requires nuget package version 2.8.5.201 or above to be installed. Checking if correct version of nuget package is installed."
        if ($ListofPackagesInstalled -contains "Nuget")
        {
            Write-Log -message "Nuget package exists. Ckecking version."
            $CheckNugetVersion=(get-PackageProvider -Name NuGet).Version
            if($CheckNugetVersion -ge "2.8.5.201")
            {
                Write-Log -message "Nuget version is $CheckNugetVersion and that is acceptable."
            }else {
                Write-Log -message "Nuget version is $CheckNugetVersion and a newer package will be installed."
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
            }
        } else {
            Write-Log -message "Nugest package does not exists and will be installed."
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        }
        Install-Module -Name AWS.Tools.Installer -Force
        Write-Log -message "AWS.Tools.Installer was installed successfully."
    }
}

# Create local admin user
Create-LocalAdmin 

# Configure WinRM service
Configure-WinRMService

# Configure WinRM listener
Configure-WinRMHttpsListener

# Add Firewall rules
Add-FirewallRule-WinRM
Add-FirewallRule-SSH

# List the listeners
Write-Verbose -Verbose "Listing the WinRM listeners:"

Write-Verbose -Verbose "Querying WinRM listeners by running command: winrm enumerate winrm/config/listener"
winrm enumerate winrm/config/listener

# Add OpenSSH.Server
Configure-OpenSSHService

# Add AWS Tools
Configure-AWS-Tools

Stop-Transcript
</powershell>
    EOF
}

data "template_file" "linux_userdata" {
    template = <<EOF
#!/bin/bash

# install essential packages
apt-get update
apt-get install -y unzip

# install aws cli
curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip
unzip /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update
rm -Rf /tmp/aws /tmp/awscliv2.zip

# download from s3
mkdir -p /home/ubuntu/download
echo aws s3 cp s3://${var.s3_bucket}/download /home/ubuntu/download --recursive

aws s3 cp s3://${var.s3_bucket}/download /home/ubuntu/download --recursive
chown ubuntu.ubuntu -R /home/ubuntu/download
    EOF
}