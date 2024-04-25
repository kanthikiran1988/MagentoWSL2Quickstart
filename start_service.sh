#!/bin/bash

# Define paths
ELASTICSEARCH_DIR="/opt/elasticsearch-7.9.0"
ELASTICSEARCH_BIN="$ELASTICSEARCH_DIR/bin/elasticsearch"

# Function to start a service using systemd and check the status
start_service() {
    local service_name=$1
    echo "Starting $service_name..."
    if sudo service $service_name start >& /dev/null; then
        echo "$service_name started successfully."
    else
        echo "Failed to start $service_name."
        exit 1
    fi
}

# Start Apache and MySQL
start_service "apache2"
start_service "mysql"

# Start Elasticsearch
echo "Starting Elasticsearch..."
if sudo -u $(whoami) $ELASTICSEARCH_BIN >& /dev/null & then
    sleep 10  # Allow some time for Elasticsearch to start
    NEW_ES_PID=$!
    if ps -p $NEW_ES_PID > /dev/null; then
        echo "Elasticsearch started successfully."
    else
        echo "Failed to start Elasticsearch."
        exit 1
    fi
else
    echo "Failed to start Elasticsearch."
    exit 1
fi
