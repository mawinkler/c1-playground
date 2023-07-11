Start-Transcript -Path 'C:/Windows/Temp/PS-logs.txt'

Set-Location 'C:/Windows/Temp'

if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You are not running as an Administrator. Please try again with admin privileges."
    exit 1
}

Write-Host "Extracting XBC/Basecamp Package" -ForegroundColor Green

Expand-Archive -LiteralPath 'C:/Windows/Temp/TMServerAgent_Windows_auto_64_Server_-_Workload_Protection_Manager.zip' -DestinationPath C:/Windows/Temp -Force

try {
    Write-Host "Starting XBC/Basecamp Install Process" -ForegroundColor Green

    Start-Process -FilePath 'C:/Windows/Temp/EndpointBasecamp.exe' -WorkingDirectory 'C:/Windows/Temp' -NoNewWindow

    Write-Host "Install Process Completed" -ForegroundColor Green
}
catch {
    # Catch errors if they exist.
    throw $_.Exception.Message

    Write-Host "The installer ran into an issue. Try running the installer manually to determine the casue." -ForegroundColor Red

    exit 3
}

Stop-Transcript

# -Verb RunAs