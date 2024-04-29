# Ensure the script is run as an administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "Please run this script as an Administrator!"
    break
}

# Install WSL and Ubuntu
Write-Output "Enabling WSL..."
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Detect processor architecture and install the correct WSL update
$architecture = (Get-WmiObject -Class Win32_Processor).AddressWidth
$wslUpdateUrl = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_"
if ($architecture -eq 64) {
    $wslUpdateUrl += "x64.msi"
} elseif ($architecture -eq 32) {
    Write-Output "32-bit systems are not supported for WSL 2."
    exit
} else {
    $wslUpdateUrl += "arm64.msi"
}

Write-Output "Downloading WSL update package for your architecture..."
Invoke-WebRequest -Uri $wslUpdateUrl -OutFile "wsl_update.msi" -UseBasicParsing
Write-Output "Installing WSL update..."
Start-Process msiexec.exe -ArgumentList '/i', 'wsl_update.msi', '/quiet', '/norestart' -Wait
wsl --install -d Ubuntu

# Ask the user if they want to restart now
$userChoice = Read-Host "WSL Installation is complete. Would you like to restart now? (Y/N)"
if ($userChoice -eq "Y" -or $userChoice -eq "y") {
    Write-Output "Restarting your computer..."
    Restart-Computer
} else {
    Write-Output "Please restart your computer manually to complete the setup."
}
