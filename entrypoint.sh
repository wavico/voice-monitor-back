#!/bin/bash
set -e

# Add Prometheus and Grafana to PATH
export PATH="/usr/local/bin:$PATH"

# Function to wait for a service to be ready
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3
    
    echo "Waiting for $service to be ready..."
    while ! nc -z $host $port; do
        sleep 1
    done
    echo "$service is ready!"
}

# Start Prometheus in the background
echo "Starting Prometheus..."
/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus &

# Wait for Prometheus to be ready
wait_for_service localhost 9090 "Prometheus"

# Start Grafana in the background
echo "Starting Grafana..."
su grafana -c "/usr/sbin/grafana-server --config=/app/grafana/grafana.ini --homepath=/usr/share/grafana --pidfile=/var/run/grafana/grafana-server.pid cfg:default.paths.data=/var/lib/grafana cfg:default.paths.logs=/var/log/grafana cfg:default.paths.plugins=/var/lib/grafana/plugins" &

# Wait for Grafana to be ready
wait_for_service localhost 3000 "Grafana"

# Start FastAPI
echo "Starting FastAPI application..."
uvicorn main:app --host 0.0.0.0 --port 8000 --reload 