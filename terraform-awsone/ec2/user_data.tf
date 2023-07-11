# #############################################################################
# Windows Userdata to create a new local administrator with
# the configured password
# #############################################################################
data "template_file" "windows-userdata" {
    template = <<EOF
      <powershell>
      $logfilepath="C:\agent.log"
      $fqdn="$env:computername"
      $port=5986 


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

            }catch{ Write-log -message $_.Exception.message -level "ERROR"}
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


      function Add-FirewallRule {
          
            try {
              # Delete an exisitng rule
              Write-Log -message "Deleting the existing firewall rule for port $port"
              netsh advfirewall firewall delete rule name="Windows Remote Management (HTTPS-In)" dir=in protocol=TCP localport=$port | Out-Null

              # Add a new firewall rule
              Write-Log -message "Adding the firewall rule for port $port"
              netsh advfirewall firewall add rule name="Windows Remote Management (HTTPS-In)" dir=in action=allow protocol=TCP localport=$port | Out-Null
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

      # Create local admin user
      Create-LocalAdmin 

      # Configure WinRM service
      Configure-WinRMService

      # Configure WinRM listener
      Configure-WinRMHttpsListener

      # Add Firewall rules
      Add-FirewallRule

      # List the listeners
      Write-Verbose -Verbose "Listing the WinRM listeners:"

      Write-Verbose -Verbose "Querying WinRM listeners by running command: winrm enumerate winrm/config/listener"
      winrm enumerate winrm/config/listener
      </powershell>
    EOF
}