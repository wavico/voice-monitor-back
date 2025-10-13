#!/bin/bash
set -e

# Add Prometheus and Grafana to PATH
export PATH="/usr/local/bin:$PATH"

# Railway 포트 설정 (기본값 8000)
export APP_PORT=${PORT:-8000}

echo "========================================="
echo "Railway Deployment - Port: $APP_PORT"
echo "========================================="

# Function to wait for a service to be ready
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3
    local max_wait=30
    local count=0
    
    echo "Waiting for $service at $host:$port to be ready..."
    while ! nc -z $host $port; do
        sleep 1
        count=$((count + 1))
        if [ $count -ge $max_wait ]; then
            echo "ERROR: $service failed to start within ${max_wait}s"
            return 1
        fi
    done
    echo "✓ $service is ready!"
}

# 1. Start FastAPI in the background FIRST
echo "========================================="
echo "Step 1: Starting FastAPI application..."
echo "========================================="
uvicorn app.server:app --host 0.0.0.0 --port $APP_PORT &
FASTAPI_PID=$!

# Wait for FastAPI to be ready
wait_for_service localhost $APP_PORT "FastAPI"

# 2. Generate Prometheus config with correct FastAPI port
echo "========================================="
echo "Step 2: Generating Prometheus config..."
echo "========================================="
cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 5s
  evaluation_interval: 5s

scrape_configs:
  - job_name: "fastapi"
    static_configs:
      - targets: ["localhost:$APP_PORT"]
    metrics_path: "/metrics"
    scrape_interval: 5s
EOF

echo "✓ Prometheus config generated for localhost:$APP_PORT"

# 3. Start Prometheus in the background
echo "========================================="
echo "Step 3: Starting Prometheus..."
echo "========================================="
/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus \
  --web.listen-address=:9090 &

# Wait for Prometheus to be ready
wait_for_service localhost 9090 "Prometheus"

# 4. Start Grafana in the background
echo "========================================="
echo "Step 4: Starting Grafana..."
echo "========================================="
/usr/sbin/grafana-server \
  --config=/etc/grafana/grafana.ini \
  --homepath=/usr/share/grafana \
  --pidfile=/var/run/grafana/grafana-server.pid \
  --packaging=docker \
  cfg:default.log.mode=console \
  cfg:server.http_port=3000 \
  cfg:security.allow_embedding=true \
  cfg:security.cookie_samesite=none \
  cfg:security.cookie_secure=false \
  cfg:live.max_connections=0 &

# Wait for Grafana to be ready
wait_for_service localhost 3000 "Grafana"

echo "========================================="
echo "✓ All services started successfully!"
echo "  - FastAPI:    localhost:$APP_PORT"
echo "  - Prometheus: localhost:9090"
echo "  - Grafana:    localhost:3000"
echo "========================================="

# Keep FastAPI running in foreground
wait $FASTAPI_PID

