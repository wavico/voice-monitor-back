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

# Start Grafana in the background with debug mode
echo "Starting Grafana..."
su grafana -c "/usr/sbin/grafana-server \
    --config=/etc/grafana/grafana.ini \
    --homepath=/usr/share/grafana \
    --pidfile=/var/run/grafana/grafana-server.pid \
    -debug" &

# Wait for Grafana to be ready
wait_for_service localhost 3000 "Grafana"

# Start FastAPI
echo "Starting FastAPI application..."
uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}
