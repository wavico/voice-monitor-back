FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    netcat-traditional \
    wget \
    curl \
    gnupg2 \
    && rm -rf /var/lib/apt/lists/*

# Install Prometheus
RUN wget https://github.com/prometheus/prometheus/releases/download/v2.47.2/prometheus-2.47.2.linux-amd64.tar.gz \
    && tar xvfz prometheus-2.47.2.linux-amd64.tar.gz \
    && mv prometheus-2.47.2.linux-amd64/prometheus /usr/local/bin/ \
    && mv prometheus-2.47.2.linux-amd64/promtool /usr/local/bin/ \
    && mkdir -p /etc/prometheus \
    && mv prometheus-2.47.2.linux-amd64/prometheus.yml /etc/prometheus/ \
    && rm -rf prometheus-2.47.2.linux-amd64*

# Install Grafana
RUN curl -fsSL https://packages.grafana.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/grafana-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/grafana-archive-keyring.gpg] https://packages.grafana.com/oss/deb stable main" | tee /etc/apt/sources.list.d/grafana.list \
    && apt-get update \
    && apt-get install -y grafana \
    && rm -rf /var/lib/apt/lists/*

# Create Grafana directories and set permissions
RUN mkdir -p /var/lib/grafana \
    && mkdir -p /var/log/grafana \
    && mkdir -p /var/lib/grafana/plugins \
    && mkdir -p /var/run/grafana \
    && mkdir -p /var/lib/grafana/dashboards \
    && mkdir -p /etc/grafana/provisioning/dashboards \
    && mkdir -p /etc/grafana/provisioning/datasources \
    && chown -R grafana:grafana /var/lib/grafana \
    && chown -R grafana:grafana /var/log/grafana \
    && chown -R grafana:grafana /usr/share/grafana \
    && chown -R grafana:grafana /var/run/grafana \
    && chown -R grafana:grafana /etc/grafana

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create necessary directories first
RUN mkdir -p /prometheus /grafana /var/lib/grafana/dashboards

# Copy Grafana configuration files BEFORE copying app code
COPY grafana/grafana.ini /etc/grafana/grafana.ini
COPY grafana/provisioning/dashboards/default.yml /etc/grafana/provisioning/dashboards/
COPY grafana/provisioning/datasources/prometheus.yml /etc/grafana/provisioning/datasources/
COPY grafana/dashboards/fastapi-monitoring.json /var/lib/grafana/dashboards/fastapi-monitoring.json

# Verify dashboard file was copied - BUILD_ID to bust cache
RUN echo "Build: 2025-10-13-v2" && ls -la /var/lib/grafana/dashboards/ && cat /var/lib/grafana/dashboards/fastapi-monitoring.json | head -20

# Copy application code and entrypoint script
COPY app ./app
COPY entrypoint.sh .
COPY prometheus ./prometheus

RUN chmod +x entrypoint.sh


# Expose necessary ports
# FastAPI: 8000, Grafana: 3000, Prometheus: 9090
EXPOSE 8000 3000 9090

# Set the entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
