FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    netcat-traditional \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code and entrypoint script
COPY . .
RUN chmod +x entrypoint.sh

# Expose necessary ports
# FastAPI: 8000, Grafana: 3000, Prometheus: 9090
EXPOSE 8000 3000 9090

# Set the entrypoint
ENTRYPOINT ["./entrypoint.sh"]
