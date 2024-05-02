# WSL2 Magento Development Environment Setup Script

## Overview
This script automates the process of setting up a Magento development environment on Windows Subsystem for Linux (WSL2). It configures necessary services like Apache, MySQL, and OpenSearch, and installs Magento with all required dependencies.

## Author
- **Name:** Kanthi Kiran K
- **Version:** 1.0

## Features
- Checks for non-root user execution.
- Redirects output to a log file, keeping the console clean.
- Handles interrupts gracefully.
- Sets up Apache, PHP, MySQL, and OpenSearch.
- Configures Apache with a Magento-specific virtual host.
- Securely collects sensitive inputs without displaying them in the terminal.
- Sets up Composer's authentication for Magento repository.
- Installs Magento and configures it using provided user inputs.

## Prerequisites
- Windows 10 or later with WSL2 enabled.
- Ubuntu or other Debian-based WSL distribution.
- Internet connection to download necessary packages.

## Usage
1. Ensure WSL2 is installed and configured on your Windows machine.
2. Open your WSL2 terminal.
3. Download this script to a convenient location in your WSL2 environment.
4. Make the script executable:
   ```bash
   chmod +x install_magento.sh
   ```
5. Run the script:
   ```bash
   bash install_magento.sh
   ```
## Quickstart
   ```bash
   curl -s https://raw.githubusercontent.com/kanthikiran1988/MagentoWSL2Quickstart/master/install_magento.sh > install_magento.sh
   bash install_magento.sh
   ```
## Important Notes
- Do not run this script as the root user. It checks for root access and will exit if run as root.
- The script will prompt you to enter several pieces of information including Magento API keys, personal details for Magento's admin user, and database credentials. Ensure you have this information available before starting.
- All operations that modify system settings (like installing packages or editing system files) require sudo access and will prompt for your password.
- This script will modify Apache's configuration. If you have an existing Apache setup, please back up your configuration files before running this script.
- Outputs are logged to `Install.log` in the same directory as the script.

## Logs
- To view detailed logs of the setup process, refer to `Install.log` generated in the directory where the script is executed.

## License
This script is distributed under the MIT License. See `LICENSE` for more details.

## Contributions
Contributions are welcome. Please fork the repository, make your changes, and submit a pull request.
