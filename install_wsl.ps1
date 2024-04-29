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
Write-Output "Downloading WSL update package for your architecture..."
wsl --update
Write-Output "Installing WSL Ubuntu..."
wsl --install -d Ubuntu

# Ask the user if they want to restart now
$userChoice = Read-Host "WSL Installation is complete. Would you like to restart now? (Y/N)"
if ($userChoice -eq "Y" -or $userChoice -eq "y") {
    Write-Output "Restarting your computer..."
    Restart-Computer
} else {
    Write-Output "Please restart your computer manually to complete the setup."
}
