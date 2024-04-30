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

# Attempt to find the Elasticsearch process
# Find all Elasticsearch process IDs
pids=$(pgrep -f elasticsearch)

# Check if any PIDs were found
if [ -z "$pids" ]; then
    echo "No Elasticsearch processes found."
else
    # Try to gracefully shut down each process
    echo "Attempting to gracefully shut down Elasticsearch processes..."
    kill $pids

    # Wait for a moment to allow processes to terminate
    sleep 5

    # Check if any processes are still running and forcefully kill them
    for pid in $pids; do
        if kill -0 $pid 2>/dev/null; then
            echo "Process $pid did not terminate, forcefully killing it..."
            kill -9 $pid
        fi
    done

    echo "All Elasticsearch processes have been terminated."
fi
