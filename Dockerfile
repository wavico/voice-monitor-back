FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    netcat-traditional \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Make the entrypoint script executable
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# Expose ports
EXPOSE 8000 3000 9090

# Set the entrypoint
ENTRYPOINT ["./entrypoint.sh"]
