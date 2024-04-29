#!/bin/bash

# Author: Kanthi Kiran K
# Description: Automates the setup of a Magento development environment with elasticsearch on WSL2.
# Version: 1.0

# Ensure the script is run with normal user privileges and not as root
if [[ $EUID -eq 0 ]]; then
    echo "This script must not run as root" >&2
    exit 1
fi

# Redirect all output to a logfile except echo statements
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>Install.log 2>&1

# Handling Ctrl+C (SIGINT) to allow graceful exit
trap 'echo "Script interrupted by user. Exiting..." >&3; exit 2' SIGINT

# Initial echo to console and log file setup
echo "Starting the full stack setup..." >&3

# Collecting essential Magento setup information
echo "Collecting Magento setup information..." >&3

# Function to read inputs with validation and ensure visibility on the console
read_input() {
    local prompt="$1"
    local varname="$2"
    local is_secret="$3"
    local input_value

    while true; do
        echo -n "$prompt" >&3
        if [[ "$is_secret" == "yes" ]]; then
            read -s input_value
            echo >&3  # Ensure we move to a new line after the input
        else
            read input_value
        fi

        if [[ -z "$input_value" ]]; then
            echo "Input cannot be empty. Please try again or press Ctrl+C to exit." >&3
        else
            eval $varname="'$input_value'"
            break
        fi
    done
}
# Function to find an available port starting from a given base (e.g., 80)
find_available_port() {
    local base_port=$1
    local port=$base_port
    local max_port=$(($base_port + 20))

    while [ $port -le $max_port ]; do
        local result=$(powershell.exe -Command "& {
            \$connection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
            if (\$connection) {
                Write-Output \"used\"
            } else {
                Write-Output \"$port\"
            }
        }" | tr -d '\r')

        if [[ "$result" =~ ^[0-9]+$ ]]; then
            echo $result
            return 0
        fi
        ((port++))
    done

    echo "No free port found in range $base_port to $max_port." >&2
    return 1
}

# Gathering user inputs with validation
read_input "Enter First Name: " FIRST_NAME no
read_input "Enter Last Name: " LAST_NAME no
read_input "Enter Email: " MAGENTO_EMAIL no
read_input "Enter Username: " MAGENTO_USERNAME no
read_input "Enter Password(Min 7 chars, alpha-numeric): " MAGENTO_PASSWORD yes
read_input "Enter Site URL (e.g., magento.local): " MAGENTO_BASE_URL no
read_input "Enter Admin URL (e.g., admin): " MAGENTO_ADMIN_URL no
read_input "Enter Magento API Public Key: " MAGENTO_PUBLIC_KEY no
read_input "Enter Magento API Private Key: " MAGENTO_PRIVATE_KEY yes

# System updates and package installations
echo "Updating system packages..." >&3
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget tar curl software-properties-common lsb-release ca-certificates apt-transport-https zip unzip

# Setting up Composer's auth.json configuration
COMPOSER_AUTH_DIR="$HOME/.config/composer"
mkdir -p "$COMPOSER_AUTH_DIR" && echo "Created Composer config directory at $COMPOSER_AUTH_DIR"
AUTH_JSON_FILE="$COMPOSER_AUTH_DIR/auth.json"
echo "Configuring auth.json for Composer at $AUTH_JSON_FILE" >&3
cat > "$AUTH_JSON_FILE" <<EOF
{
    "http-basic": {
        "repo.magento.com": {
            "username": "${MAGENTO_PUBLIC_KEY}",
            "password": "${MAGENTO_PRIVATE_KEY}"
        }
    }
}
EOF

# Apache and PHP installation
echo "Installing Apache and PHP..." >&3
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install -y apache2 php8.2 libapache2-mod-php8.2 php8.2-cli php8.2-common php8.2-mbstring php8.2-xml php8.2-mysql php8.2-curl php8.2-gd php8.2-bcmath php8.2-intl php8.2-soap php8.2-zip php8.2-xmlrpc
if [ $? -eq 0 ]; then
    echo "Apache and PHP installed successfully."
else
    echo "Failed to install Apache and PHP."
    exit 1
fi

# Automatically find an available port starting from 80
port=$(find_available_port 80)
if [ "$port" -ne 80 ]; then
    echo "Port $port is available for configuration."
else
    echo "Failed to find an available port."
    exit 1
fi

# Update the VirtualHost configuration with the determined port
if [ "$port" -ne 80 ]; then
    sudo tee /etc/apache2/ports.conf > /dev/null <<EOT
Listen $port
EOT
fi

# Apache configuration
echo "Configuring Apache..." >&3
sudo a2enmod rewrite headers ssl
# Apache VirtualHost Configuration
sudo tee /etc/apache2/sites-available/magento.conf > /dev/null <<EOT
<VirtualHost *:$port>
    ServerAdmin ${MAGENTO_EMAIL}
    DocumentRoot /var/www/html/magento
    ServerName ${MAGENTO_BASE_URL}

    <Directory /var/www/html/magento>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/magento_error.log
    CustomLog \${APACHE_LOG_DIR}/magento_access.log combined
</VirtualHost>
EOT
sudo a2ensite magento.conf
sudo a2dissite 000-default.conf
sudo service apache2 restart
# Apache configuration files
APACHE_ENVVARS="/etc/apache2/envvars"
sudo sed -i "s/export APACHE_RUN_USER=.*/export APACHE_RUN_USER=$(whoami)/" $APACHE_ENVVARS
sudo service apache2 restart
if [ $? -eq 0 ]; then
    echo "Apache configured successfully."
else
    echo "Failed to configure Apache."
    exit 1
fi

# MySQL setup
echo "Installing and configuring MySQL..." >&3
sudo apt-get install -y mysql-server
echo "Starting MySQL service..."
sudo chown -R mysql:mysql /var/run/mysqld
sudo chmod 755 /var/run/mysqld
sudo chmod 777 /var/run/mysqld/mysqld.sock 
sudo service mysql start
sudo mysql -u root -e "CREATE DATABASE magento; CREATE USER 'magento'@'localhost' IDENTIFIED BY 'M@gento777'; GRANT ALL ON magento.* TO 'magento'@'localhost';GRANT SUPER ON *.* TO 'magento'@'localhost'; FLUSH PRIVILEGES;" || { echo "MySQL setup failed"; exit 1; }
if [ $? -eq 0 ]; then
    echo "Mysql installed successfully." >&3
else
    echo "Failed to install Mysql." >&3
    exit 1
fi
# ElasticSearch installation
echo "Installing Java for ElasticSearch..." >&3
sudo apt install -y openjdk-11-jdk
# Download and Setup ElasticSearch with proper permissions
echo "Downloading and setting up ElasticSearch..." >&3
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.9.0-linux-x86_64.tar.gz -O /tmp/elasticsearch-7.9.0-linux-x86_64.tar.gz
echo "Extracting ElasticSearch " >&3
sudo mkdir -p /opt/elasticsearch-7.9.0
sudo tar -xzf /tmp/elasticsearch-7.9.0-linux-x86_64.tar.gz -C /opt/elasticsearch-7.9.0 --strip-components=1
sudo rm /tmp/elasticsearch-7.9.0-linux-x86_64.tar.gz
# Ensure ElasticSearch files ownership is correct
sudo chown -R $(whoami):$(whoami) /opt/elasticsearch-7.9.0

# Starting ElasticSearch in the background
echo "Starting ElasticSearch..." >&3
sudo -u $(whoami) /opt/elasticsearch-7.9.0/bin/elasticsearch >& /dev/null &
if [ $? -eq 0 ]; then
    echo "Elasticsearch Started successfully." >&3
else
    echo "Failed to Start Elasticsearch." >&3
    exit 1
fi
# Conditionally format the base URL depending on the port
if [ "$port" -ne 80 ]; then
    MAGENTO_BASE_URL="${MAGENTO_BASE_URL}:${port}"
fi
# Magento installation
echo -e "Installing Composer" >&3
curl -sS https://getcomposer.org/installer | sudo php
sudo mv composer.phar /usr/local/bin/composer
sudo mkdir -p /var/www/html/magento && sudo chown -R $(whoami):www-data /var/www/html
cd /var/www/html/magento
echo "Downloading Magento" >&3
composer create-project --repository-url=https://repo.magento.com/ magento/project-community-edition /var/www/html/magento
if [ $? -eq 0 ]; then
    echo "Magento Downloaded successfully." >&3
else
    echo "Failed to Downloaded Magento." >&3
    exit 1
fi
reset
echo "Installing Magento" >&3
php bin/magento setup:install --base-url=http://"${MAGENTO_BASE_URL}" --backend-frontname="${MAGENTO_ADMIN_URL}" --db-name=magento --db-user=magento --db-password="M@gento777" --admin-firstname="${FIRST_NAME}" --admin-lastname="${LAST_NAME}" --admin-email="${MAGENTO_EMAIL}" --admin-user="${MAGENTO_USERNAME}" --admin-password="${MAGENTO_PASSWORD}" --language=en_US --currency=USD --timezone=America/Chicago --use-rewrites=1 --search-engine=elasticsearch7 --elasticsearch-host="localhost" --elasticsearch-port=9200
if [ $? -eq 0 ]; then
    echo "Magento Install successfully." >&3
else
    echo "Failed to Install Magento." >&3
    exit 1
fi
php bin/magento module:disable Magento_AdminAdobeImsTwoFactorAuth Magento_TwoFactorAuth
echo "Magento Maintenance " >&3
php bin/magento setup:upgrade
if [ $? -eq 0 ]; then
    echo "Magento Upgrade successfully." >&3
else
    echo "Failed to Upgrade Magento." >&3
    exit 1
fi
echo "Magento Compile " >&3
php bin/magento setup:di:compile
echo "Magento Static Deploy " >&3
php bin/magento setup:static-content:deploy -f
echo "Magento ReIndexing " >&3
php bin/magento index:reindex
echo "Magento Cache Flush " >&3
php bin/magento cache:flush
# Final echo to console indicating completion
echo "Setup completed successfully. ElasticSearch and Apache are running. Here are the details for your environment:" >&3
echo "ElasticSearch Access: http://localhost:9200" >&3
echo "Please Add this line in host file:  127.0.0.1 ${MAGENTO_BASE_URL%%:*}" >&3
echo "Please Add this line in host file:  ::1 ${MAGENTO_BASE_URL%%:*}" >&3
echo "Magento URL: http://${MAGENTO_BASE_URL}" >&3
echo "Magento Admin Panel: http://${MAGENTO_BASE_URL}/${MAGENTO_ADMIN_URL}" >&3
