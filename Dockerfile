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
    && chown -R grafana:grafana /var/lib/grafana \
    && chown -R grafana:grafana /var/log/grafana \
    && chown -R grafana:grafana /usr/share/grafana \
    && chown -R grafana:grafana /var/run/grafana

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code and entrypoint script
COPY . .
RUN chmod +x entrypoint.sh

# Create necessary directories
RUN mkdir -p /prometheus /grafana

# Expose necessary ports
# FastAPI: 8000, Grafana: 3000, Prometheus: 9090
EXPOSE 8000 3000 9090

# Set the entrypoint
ENTRYPOINT ["./entrypoint.sh"]
