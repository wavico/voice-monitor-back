#!/bin/bash
set -e

# Add Prometheus and Grafana to PATH
export PATH="/usr/local/bin:$PATH"

# Railway 포트 설정 (기본값 8000)
export APP_PORT=${PORT:-8000}

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

# Prometheus 설정 파일 동적 생성
echo "Generating Prometheus config for port $APP_PORT..."
cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 5s
  evaluation_interval: 5s

scrape_configs:
  - job_name: "fastapi"
    static_configs:
      - targets: ["localhost:$APP_PORT"]
    metrics_path: "/metrics"
EOF

# Start Prometheus in the background
echo "Starting Prometheus..."
/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus &

# Wait for Prometheus to be ready
wait_for_service localhost 9090 "Prometheus"

# Start Grafana in the background with debug mode
echo "Starting Grafana..."
/usr/sbin/grafana-server \
  --config=/etc/grafana/grafana.ini \
  --homepath=/usr/share/grafana \
  --pidfile=/var/run/grafana/grafana-server.pid \
  --packaging=docker \
  cfg:default.log.mode=console \
  cfg:server.http_port=3001 \
  cfg:server.root_url=http://localhost:3001/grafana/ \
  cfg:server.serve_from_sub_path=true \
  cfg:security.allow_embedding=true \
  cfg:security.cookie_samesite=none \
  cfg:security.cookie_secure=false \
  --debug &


# Wait for Grafana to be ready
wait_for_service localhost 3001 "Grafana"

# Start FastAPI
echo "Starting FastAPI application..."
uvicorn app.server:app --host 0.0.0.0 --port ${PORT:-8000}

