#!/bin/bash

# Deploy script for Novu Service
# This script should be run on the production server

set -e

echo "🚀 Starting deployment process..."

# Navigate to project directory
cd /home/dev/novuservice

# Create backup of current deployment
echo "📦 Creating backup..."
if [ -d "backup" ]; then
    rm -rf backup
fi
mkdir -p backup
cp -r . backup/ 2>/dev/null || true

# Pull latest changes from Git
echo "📥 Pulling latest changes..."
git pull origin main

# Pull latest Docker images
echo "🐳 Pulling latest Docker images..."
docker-compose pull

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose down

# Remove unused images and containers
echo "🧹 Cleaning up unused Docker resources..."
docker system prune -f

# Start services
echo "▶️ Starting services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Check if services are running
echo "🔍 Checking service status..."
docker-compose ps

# Check health endpoints
echo "🏥 Performing health checks..."
sleep 10

# Check API health
if wget -q --spider http://localhost:3000/v1/health-check > /dev/null 2>&1; then
    echo "✅ API service is healthy"
else
    echo "❌ API service health check failed"
    docker-compose logs novu-api
    exit 1
fi

# Check Dashboard
if wget -q --spider http://localhost:4200 > /dev/null 2>&1; then
    echo "✅ Dashboard service is healthy"
else
    echo "❌ Dashboard service health check failed"
    docker-compose logs novu-dashboard
    exit 1
fi

# Restart nginx
echo "🔄 Reloading nginx..."
sudo systemctl reload nginx

echo "✅ Deployment completed successfully!"
echo "🌐 Application is available at: https://novuservice.quantriso.vn"

# Show running containers
echo "📊 Current running containers:"
docker-compose ps
