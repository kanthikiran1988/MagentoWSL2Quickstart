#!/bin/bash

# Function to stop a service using systemd and check the status
stop_service() {
    local service_name=$1
    echo "Stopping $service_name..."
    if sudo service $service_name stop >& /dev/null; then
        echo "$service_name stopped successfully."
    else
        echo "Failed to stop $service_name."
        exit 1
    fi
}

# Stop Apache, MySQL, and Elasticsearch
stop_service "apache2"
stop_service "mysql"

# Elasticsearch may require a specific command to stop gracefully
ELASTICSEARCH_DIR="/opt/elasticsearch-7.9.0"
ELASTICSEARCH_BIN="$ELASTICSEARCH_DIR/bin/elasticsearch"

# Attempt to find the Elasticsearch process
ES_PID=$(pgrep -f "$ELASTICSEARCH_BIN")
if [ -n "$ES_PID" ]; then
    echo "Elasticsearch is running with PID: $ES_PID. Attempting to stop..."
    kill $ES_PID

    # Wait a bit to ensure the process has been terminated
    sleep 5

    # Check if the process is still running and try to kill it again using kill -9 if needed
    if ps -p $ES_PID > /dev/null 2>&1; then
        echo "Regular stop failed, using kill -9..."
        kill -9 $ES_PID
        sleep 5
    fi

    # Confirm process is stopped
    if ps -p $ES_PID > /dev/null 2>&1; then
        echo "Failed to stop Elasticsearch process."
        exit 1
    else
        echo "Elasticsearch stopped successfully."
    fi
else
    echo "No Elasticsearch process found."
fi
