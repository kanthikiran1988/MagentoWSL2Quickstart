#!/bin/bash

# Define paths
ELASTICSEARCH_DIR="/opt/elasticsearch-7.9.0"
ELASTICSEARCH_BIN="$ELASTICSEARCH_DIR/bin/elasticsearch"

# Function to restart a service using systemd and check the status
restart_service() {
    local service_name=$1
    echo "Restarting $service_name..."
    if sudo service $service_name restart >& /dev/null; then
        echo "$service_name configured successfully."
    else
        echo "Failed to configure $service_name."
        exit 1
    fi
}

# Restart Apache and MySQL
restart_service "apache2"
restart_service "mysql"

# Kill existing Elasticsearch process if running
ES_PID=$(pgrep -f "$ELASTICSEARCH_BIN")
if [ -n "$ES_PID" ]; then
    echo "Elasticsearch is running with PID: $ES_PID. Attempting to kill..."
    kill $ES_PID && sleep 5
    # Force kill if still running
    if ps -p $ES_PID > /dev/null; then
        echo "Regular kill failed, using kill -9..."
        kill -9 $ES_PID && sleep 5
    fi
    # Final check to confirm process is killed
    if ps -p $ES_PID > /dev/null; then
        echo "Failed to kill Elasticsearch process."
        exit 1
    fi
    echo "Elasticsearch process killed successfully."
else
    echo "No Elasticsearch process found."
fi

# Start Elasticsearch
echo "Starting Elasticsearch..."
sudo -u $(whoami) $ELASTICSEARCH_BIN >& /dev/null &
sleep 10  # Wait for Elasticsearch to start

# Check if Elasticsearch started correctly
NEW_ES_PID=$!
if ps -p $NEW_ES_PID > /dev/null; then
    echo "Elasticsearch configured successfully."
else
    echo "Failed to configure Elasticsearch."
    exit 1
fi
