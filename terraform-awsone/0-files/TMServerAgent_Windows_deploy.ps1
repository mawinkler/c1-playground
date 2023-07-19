Start-Transcript -Path $HOME/Downloads/PS-logs.txt

Set-Location $HOME/Downloads

if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You are not running as an Administrator. Please try again with admin privileges."
    exit 1
}


$archive="TMServerAgent_Windows_auto_64_Server_-_Workload_Protection_Manager.zip"
if (Test-Path $archive) {

    Write-Host "Extracting XBC/Basecamp Package" -ForegroundColor Green

    Expand-Archive -LiteralPath $HOME/Downloads/TMServerAgent_Windows_auto_64_Server_-_Workload_Protection_Manager.zip -DestinationPath $HOME/Downloads -Force

    try {
        Write-Host "Starting XBC/Basecamp Install Process" -ForegroundColor Green

        Start-Process -FilePath $HOME/Downloads/EndpointBasecamp.exe -WorkingDirectory $HOME/Downloads -NoNewWindow

        Write-Host "Install Process Completed" -ForegroundColor Green
    }
    catch {
        # Catch errors if they exist.
        throw $_.Exception.Message

        Write-Host "The installer ran into an issue. Try running the installer manually to determine the casue." -ForegroundColor Red

        exit 3
    }
}

Stop-Transcript
