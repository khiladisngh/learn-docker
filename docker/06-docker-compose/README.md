# 🐙 Chapter 06: Docker Compose - Multi-Container Application Orchestration

Welcome to Docker Compose mastery! In this chapter, you'll learn to orchestrate multi-container applications, manage complex deployments, and implement production-ready compose configurations.

## 🎯 Learning Objectives

By the end of this chapter, you will:
- ✅ Master Docker Compose file syntax and best practices
- ✅ Orchestrate complex multi-container applications
- ✅ Implement service scaling and load balancing
- ✅ Manage environments and configuration
- ✅ Handle secrets and sensitive data securely
- ✅ Deploy production applications with Compose

## 🏗️ Docker Compose Architecture

### Compose Overview

```
┌─────────────────────────────────────────┐
│          Docker Compose Project        │
├─────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  │
│  │Service A│  │Service B│  │Service C│  │
│  │(Web)    │  │(API)    │  │(DB)     │  │
│  └────┬────┘  └────┬────┘  └────┬────┘  │
│       │            │            │       │
│  ┌────┴────────────┴────────────┴────┐  │
│  │         Shared Networks          │  │
│  └─────────────────────────────────────┘  │
│  ┌─────────────────────────────────────┐  │
│  │         Shared Volumes           │  │
│  └─────────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Key Concepts

- **Services**: Individual containers defined in compose file
- **Networks**: Custom networks for service communication
- **Volumes**: Shared storage between services
- **Secrets**: Secure management of sensitive data
- **Configs**: Non-sensitive configuration management
- **Environment**: Variables and environment-specific settings

## 📄 Compose File Basics

### Compose File Structure

```yaml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "8080:80"
    depends_on:
      - db
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/myapp
    networks:
      - frontend
      - backend
    volumes:
      - ./app:/app
      - uploads:/app/uploads

  db:
    image: postgres:13
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - backend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true

volumes:
  db_data:
  uploads:
```

### Version Compatibility

| Version | Docker Engine | Features |
|---------|---------------|----------|
| 3.8 | 19.03.0+ | Latest features, secrets, configs |
| 3.7 | 18.06.0+ | External networks, secrets |
| 3.6 | 18.02.0+ | tmpfs, external configs |
| 3.5 | 17.12.0+ | Named networks, isolation |

## 🚀 Service Configuration

### Basic Service Definition

```yaml
services:
  webapp:
    # Image specification
    image: nginx:alpine
    # or build from Dockerfile
    build:
      context: .
      dockerfile: Dockerfile.prod
      args:
        - NODE_ENV=production
        - API_URL=https://api.example.com
    
    # Container configuration
    container_name: webapp-container
    hostname: webapp
    restart: unless-stopped
    
    # Port mapping
    ports:
      - "80:80"
      - "443:443"
    
    # Environment variables
    environment:
      - NODE_ENV=production
      - DEBUG=false
    env_file:
      - .env
      - .env.production
    
    # Volume mounts
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - uploads:/var/www/uploads
    
    # Network configuration
    networks:
      - frontend
      - backend
    
    # Dependencies
    depends_on:
      - api
      - db
```

### Advanced Service Configuration

```yaml
services:
  api:
    build:
      context: ./api
      target: production
      cache_from:
        - myapp/api:cache
    
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    
    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    
    # Security
    user: "1001:1001"
    read_only: true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    
    # Logging
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    
    # Labels
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`api.example.com`)"
```

## 🔗 Networks in Compose

### Network Types and Configuration

```yaml
networks:
  # Default bridge network
  frontend:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1
    
  # Internal network (no external access)
  backend:
    driver: bridge
    internal: true
    ipam:
      config:
        - subnet: 172.21.0.0/16
  
  # External network (pre-existing)
  production-network:
    external: true
    name: prod-network
  
  # Custom driver network
  overlay-network:
    driver: overlay
    attachable: true
    driver_opts:
      encrypted: "true"
```

### Service Network Configuration

```yaml
services:
  web:
    image: nginx:alpine
    networks:
      frontend:
        ipv4_address: 172.20.0.10
        aliases:
          - webserver
          - www
      backend:
        aliases:
          - web-internal
    
  api:
    image: myapp:api
    networks:
      - backend
    # Service can be reached as 'api' or 'backend-service'
    network_mode: "bridge"  # or "host", "none", "service:name"
```

## 💾 Volumes in Compose

### Volume Types and Patterns

```yaml
volumes:
  # Named volume (Docker managed)
  db_data:
    driver: local
    driver_opts:
      type: ext4
      device: /dev/sdb1
  
  # External volume (pre-existing)
  shared_storage:
    external: true
    name: production-shared-data
  
  # NFS volume
  nfs_storage:
    driver: local
    driver_opts:
      type: nfs
      o: addr=nfs.example.com,rw
      device: ":/exports/data"

services:
  app:
    image: myapp:latest
    volumes:
      # Named volume
      - db_data:/var/lib/mysql
      
      # Bind mount
      - ./config:/app/config:ro
      - ./logs:/app/logs
      
      # tmpfs mount
      - type: tmpfs
        target: /tmp
        tmpfs:
          size: 100M
      
      # Volume with specific options
      - type: volume
        source: uploads
        target: /app/uploads
        volume:
          nocopy: true
```

## 🔧 Environment Management

### Environment Variables

```yaml
services:
  app:
    image: myapp:latest
    environment:
      # Direct assignment
      - NODE_ENV=production
      - DEBUG=false
      - DATABASE_URL=postgresql://user:pass@db:5432/myapp
      
      # From host environment
      - SECRET_KEY=${SECRET_KEY}
      - API_TOKEN=${API_TOKEN:-default_token}
    
    # Environment file
    env_file:
      - .env
      - .env.production
      - secrets.env
```

**.env file:**
```env
# Database configuration
POSTGRES_DB=myapp
POSTGRES_USER=appuser
POSTGRES_PASSWORD=secure_password

# Application settings
NODE_ENV=production
LOG_LEVEL=info
MAX_CONNECTIONS=100

# External services
REDIS_URL=redis://redis:6379
ELASTICSEARCH_URL=http://elasticsearch:9200
```

### Environment-Specific Compose Files

**docker-compose.yml (base):**
```yaml
version: '3.8'

services:
  app:
    build: .
    environment:
      - NODE_ENV=development
    volumes:
      - .:/app
    networks:
      - app-network

  db:
    image: postgres:13
    environment:
      - POSTGRES_DB=myapp
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - app-network

networks:
  app-network:

volumes:
  db_data:
```

**docker-compose.override.yml (development):**
```yaml
version: '3.8'

services:
  app:
    ports:
      - "3000:3000"
    environment:
      - DEBUG=true
    volumes:
      - .:/app
      - node_modules:/app/node_modules
    command: npm run dev

  db:
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_PASSWORD=dev_password

volumes:
  node_modules:
```

**docker-compose.prod.yml (production):**
```yaml
version: '3.8'

services:
  app:
    build:
      target: production
    restart: unless-stopped
    environment:
      - NODE_ENV=production
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  db:
    restart: unless-stopped
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    secrets:
      - db_password
    deploy:
      resources:
        limits:
          memory: 1G

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

## 🔐 Secrets Management

### Docker Secrets

```yaml
services:
  app:
    image: myapp:latest
    secrets:
      - db_password
      - api_key
      - ssl_cert
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password
      - API_KEY_FILE=/run/secrets/api_key

secrets:
  db_password:
    file: ./secrets/db_password.txt
  
  api_key:
    external: true
    name: production_api_key
  
  ssl_cert:
    external: true
```

### Configuration Management

```yaml
services:
  nginx:
    image: nginx:alpine
    configs:
      - source: nginx_config
        target: /etc/nginx/nginx.conf
        mode: 0444
      - source: ssl_config
        target: /etc/nginx/conf.d/ssl.conf

configs:
  nginx_config:
    file: ./config/nginx.conf
  
  ssl_config:
    external: true
    name: production_ssl_config
```

## 📈 Service Scaling

### Manual Scaling

```bash
# Scale specific service
docker-compose up -d --scale web=3 --scale api=2

# Scale with resource constraints
docker-compose up -d --scale worker=5
```

### Compose Scaling Configuration

```yaml
services:
  web:
    image: nginx:alpine
    ports:
      - "80-85:80"  # Port range for scaling
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
      restart_policy:
        condition: on-failure
  
  worker:
    image: myapp:worker
    deploy:
      replicas: 5
      resources:
        limits:
          cpus: '0.25'
          memory: 256M
```

### Load Balancing with HAProxy

```yaml
services:
  haproxy:
    image: haproxy:alpine
    ports:
      - "80:80"
      - "8080:8080"  # Stats page
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
    depends_on:
      - web

  web:
    image: nginx:alpine
    expose:
      - "80"
    deploy:
      replicas: 3
```

**haproxy.cfg:**
```
global
    daemon
    log stdout local0

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    log global
    option httplog

frontend web_frontend
    bind *:80
    default_backend web_servers

backend web_servers
    balance roundrobin
    server-template web 3 web:80 check
    
stats enable
stats uri /stats
stats refresh 30s
```

## 🏢 Production Compose Examples

### 1. Full-Stack Web Application

```yaml
version: '3.8'

services:
  # Reverse Proxy & Load Balancer
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - static_files:/var/www/static:ro
    depends_on:
      - frontend
      - api
    networks:
      - frontend
    restart: unless-stopped

  # Frontend Application
  frontend:
    build:
      context: ./frontend
      target: production
      args:
        - REACT_APP_API_URL=https://api.example.com
    environment:
      - NODE_ENV=production
    volumes:
      - static_files:/app/build
    networks:
      - frontend
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # API Backend
  api:
    build:
      context: ./api
      target: production
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://api_user:${DB_PASSWORD}@postgres:5432/api_db
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET_FILE=/run/secrets/jwt_secret
    secrets:
      - jwt_secret
      - db_password
    volumes:
      - uploads:/app/uploads
    networks:
      - frontend
      - backend
    depends_on:
      - postgres
      - redis
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Background Workers
  worker:
    build:
      context: ./api
      target: production
    command: npm run worker
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://api_user:${DB_PASSWORD}@postgres:5432/api_db
      - REDIS_URL=redis://redis:6379
    secrets:
      - db_password
    volumes:
      - uploads:/app/uploads
    networks:
      - backend
    depends_on:
      - postgres
      - redis
    restart: unless-stopped
    deploy:
      replicas: 3

  # Database
  postgres:
    image: postgres:13
    environment:
      - POSTGRES_DB=api_db
      - POSTGRES_USER=api_user
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgres/init:/docker-entrypoint-initdb.d:ro
    networks:
      - backend
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U api_user -d api_db"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Cache & Session Store
  redis:
    image: redis:alpine
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    environment:
      - REDIS_PASSWORD_FILE=/run/secrets/redis_password
    secrets:
      - redis_password
    volumes:
      - redis_data:/data
    networks:
      - backend
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Monitoring & Logging
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    networks:
      - monitoring
    restart: unless-stopped

  grafana:
    image: grafana/grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD_FILE=/run/secrets/grafana_password
    secrets:
      - grafana_password
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana:/etc/grafana/provisioning:ro
    networks:
      - monitoring
    restart: unless-stopped

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true
  monitoring:
    driver: bridge
    internal: true

volumes:
  postgres_data:
  redis_data:
  static_files:
  uploads:
  prometheus_data:
  grafana_data:

secrets:
  jwt_secret:
    file: ./secrets/jwt_secret.txt
  db_password:
    file: ./secrets/db_password.txt
  redis_password:
    file: ./secrets/redis_password.txt
  grafana_password:
    file: ./secrets/grafana_password.txt
```

### 2. Microservices Architecture

```yaml
version: '3.8'

services:
  # API Gateway
  gateway:
    image: traefik:v2.9
    ports:
      - "80:80"
      - "8080:8080"  # Dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/traefik.yml:/etc/traefik/traefik.yml:ro
    networks:
      - gateway
    restart: unless-stopped
    labels:
      - "traefik.enable=true"

  # User Service
  user-service:
    build: ./services/user
    environment:
      - SERVICE_NAME=user-service
      - DATABASE_URL=postgresql://user:${USER_DB_PASSWORD}@user-db:5432/users
    secrets:
      - user_db_password
    networks:
      - gateway
      - user-network
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.user-service.rule=PathPrefix(`/api/users`)"
      - "traefik.http.services.user-service.loadbalancer.server.port=8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  user-db:
    image: postgres:13
    environment:
      - POSTGRES_DB=users
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD_FILE=/run/secrets/user_db_password
    secrets:
      - user_db_password
    volumes:
      - user_db_data:/var/lib/postgresql/data
    networks:
      - user-network
    restart: unless-stopped

  # Order Service
  order-service:
    build: ./services/order
    environment:
      - SERVICE_NAME=order-service
      - DATABASE_URL=postgresql://order:${ORDER_DB_PASSWORD}@order-db:5432/orders
      - USER_SERVICE_URL=http://user-service:8080
    secrets:
      - order_db_password
    networks:
      - gateway
      - order-network
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.order-service.rule=PathPrefix(`/api/orders`)"
      - "traefik.http.services.order-service.loadbalancer.server.port=8080"

  order-db:
    image: postgres:13
    environment:
      - POSTGRES_DB=orders
      - POSTGRES_USER=order
      - POSTGRES_PASSWORD_FILE=/run/secrets/order_db_password
    secrets:
      - order_db_password
    volumes:
      - order_db_data:/var/lib/postgresql/data
    networks:
      - order-network
    restart: unless-stopped

  # Payment Service
  payment-service:
    build: ./services/payment
    environment:
      - SERVICE_NAME=payment-service
      - REDIS_URL=redis://redis:6379
      - STRIPE_SECRET_KEY_FILE=/run/secrets/stripe_secret
    secrets:
      - stripe_secret
    networks:
      - gateway
      - payment-network
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.payment-service.rule=PathPrefix(`/api/payments`)"

  # Message Queue
  rabbitmq:
    image: rabbitmq:3-management
    environment:
      - RABBITMQ_DEFAULT_USER=admin
      - RABBITMQ_DEFAULT_PASS_FILE=/run/secrets/rabbitmq_password
    secrets:
      - rabbitmq_password
    ports:
      - "15672:15672"  # Management UI
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    networks:
      - message-queue
    restart: unless-stopped

  # Event Processor
  event-processor:
    build: ./services/event-processor
    environment:
      - RABBITMQ_URL=amqp://admin:${RABBITMQ_PASSWORD}@rabbitmq:5672
    secrets:
      - rabbitmq_password
    networks:
      - message-queue
      - gateway
    restart: unless-stopped
    deploy:
      replicas: 2

networks:
  gateway:
    driver: bridge
  user-network:
    driver: bridge
    internal: true
  order-network:
    driver: bridge
    internal: true
  payment-network:
    driver: bridge
    internal: true
  message-queue:
    driver: bridge
    internal: true

volumes:
  user_db_data:
  order_db_data:
  rabbitmq_data:

secrets:
  user_db_password:
    file: ./secrets/user_db_password.txt
  order_db_password:
    file: ./secrets/order_db_password.txt
  stripe_secret:
    file: ./secrets/stripe_secret.txt
  rabbitmq_password:
    file: ./secrets/rabbitmq_password.txt
```

## 🔧 Compose Commands & Workflow

### Essential Commands

```bash
# Basic operations
docker-compose up -d                    # Start services in background
docker-compose down                     # Stop and remove services
docker-compose restart                  # Restart all services
docker-compose pause                    # Pause services
docker-compose unpause                  # Unpause services

# Service management
docker-compose up -d --scale web=3      # Scale specific service
docker-compose restart api              # Restart specific service
docker-compose stop db                  # Stop specific service
docker-compose rm -f db                 # Remove specific service

# Build and deployment
docker-compose build                    # Build all services
docker-compose build --no-cache api     # Build specific service without cache
docker-compose up -d --build            # Build and start
docker-compose pull                     # Pull latest images

# Logs and monitoring
docker-compose logs -f                  # Follow all logs
docker-compose logs -f api              # Follow specific service logs
docker-compose logs --tail=100 api      # Show last 100 lines
docker-compose ps                       # Show service status
docker-compose top                      # Show running processes

# Configuration
docker-compose config                   # Validate and show config
docker-compose config --services        # List all services
docker-compose -f docker-compose.prod.yml config  # Use specific file
```

### Environment-Specific Deployments

```bash
# Development
docker-compose up -d

# Production with override
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Testing environment
docker-compose -f docker-compose.yml -f docker-compose.test.yml up -d

# Custom environment
COMPOSE_FILE=docker-compose.yml:docker-compose.custom.yml docker-compose up -d
```

## 🔍 Monitoring & Debugging

### Health Checks and Monitoring

```yaml
services:
  app:
    image: myapp:latest
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    
    # Logging configuration
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        compress: "true"
    
    # Resource monitoring
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

### Debugging Tools

```python
#!/usr/bin/env python3
# compose-monitor.py

import subprocess
import json
import time
from datetime import datetime

class ComposeMonitor:
    def __init__(self, project_name=None):
        self.project_name = project_name
        
    def get_services_status(self):
        """Get status of all services"""
        try:
            cmd = ["docker-compose", "ps", "--format", "json"]
            if self.project_name:
                cmd.extend(["-p", self.project_name])
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                services = []
                for line in result.stdout.strip().split('\n'):
                    if line:
                        services.append(json.loads(line))
                return services
            else:
                return []
        except Exception as e:
            print(f"Error getting services: {e}")
            return []
    
    def get_service_logs(self, service_name, lines=50):
        """Get logs for specific service"""
        try:
            cmd = ["docker-compose", "logs", "--tail", str(lines), service_name]
            result = subprocess.run(cmd, capture_output=True, text=True)
            return result.stdout
        except Exception as e:
            print(f"Error getting logs for {service_name}: {e}")
            return ""
    
    def check_service_health(self, service_name):
        """Check health of specific service"""
        try:
            cmd = ["docker", "inspect", f"{service_name}", "--format", "{{.State.Health.Status}}"]
            result = subprocess.run(cmd, capture_output=True, text=True)
            return result.stdout.strip()
        except:
            return "unknown"
    
    def get_resource_usage(self):
        """Get resource usage for all containers"""
        try:
            cmd = ["docker", "stats", "--no-stream", "--format", 
                   "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"]
            result = subprocess.run(cmd, capture_output=True, text=True)
            return result.stdout
        except Exception as e:
            print(f"Error getting resource usage: {e}")
            return ""
    
    def monitor_services(self, interval=30):
        """Monitor services continuously"""
        print(f"🔍 Starting Compose monitoring (interval: {interval}s)")
        
        while True:
            try:
                print(f"\n📊 Service Status - {datetime.now().strftime('%H:%M:%S')}")
                print("=" * 60)
                
                services = self.get_services_status()
                
                for service in services:
                    name = service.get('Name', 'Unknown')
                    state = service.get('State', 'Unknown')
                    status = service.get('Status', 'Unknown')
                    
                    # Check health if available
                    health = self.check_service_health(name)
                    health_emoji = "✅" if health == "healthy" else "❌" if health == "unhealthy" else "⚪"
                    
                    print(f"{health_emoji} {name}: {state} - {status}")
                
                # Show resource usage
                print(f"\n📈 Resource Usage:")
                resource_usage = self.get_resource_usage()
                print(resource_usage)
                
                time.sleep(interval)
                
            except KeyboardInterrupt:
                print("\n👋 Monitoring stopped by user")
                break
            except Exception as e:
                print(f"❌ Monitoring error: {e}")
                time.sleep(interval)

if __name__ == "__main__":
    monitor = ComposeMonitor()
    monitor.monitor_services()
```

## 🚀 CI/CD Integration

### GitHub Actions with Compose

```yaml
# .github/workflows/deploy.yml
name: Deploy with Docker Compose

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Login to Docker Hub
      uses: docker/login-action@v2
      with:
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}
    
    - name: Build and push images
      run: |
        docker-compose -f docker-compose.prod.yml build
        docker-compose -f docker-compose.prod.yml push
    
    - name: Deploy to production
      run: |
        echo "${{ secrets.DEPLOY_KEY }}" > deploy_key
        chmod 600 deploy_key
        ssh -i deploy_key -o StrictHostKeyChecking=no ${{ secrets.DEPLOY_USER }}@${{ secrets.DEPLOY_HOST }} << 'EOF'
          cd /app
          git pull origin main
          docker-compose -f docker-compose.prod.yml pull
          docker-compose -f docker-compose.prod.yml up -d
          docker system prune -f
        EOF
```

### Deployment Script

```bash
#!/bin/bash
# deploy.sh

set -e

PROJECT_NAME="myapp"
ENVIRONMENT="${1:-production}"
COMPOSE_FILE="docker-compose.yml"

case $ENVIRONMENT in
  "production")
    COMPOSE_FILE="docker-compose.yml:docker-compose.prod.yml"
    ;;
  "staging")
    COMPOSE_FILE="docker-compose.yml:docker-compose.staging.yml"
    ;;
  "development")
    COMPOSE_FILE="docker-compose.yml:docker-compose.dev.yml"
    ;;
esac

echo "🚀 Deploying $PROJECT_NAME to $ENVIRONMENT"

# Backup current state
echo "📦 Creating backup..."
docker-compose -p ${PROJECT_NAME} -f ${COMPOSE_FILE} config > backup-${ENVIRONMENT}-$(date +%Y%m%d_%H%M%S).yml

# Pull latest images
echo "⬇️ Pulling latest images..."
COMPOSE_FILE=${COMPOSE_FILE} docker-compose -p ${PROJECT_NAME} pull

# Build updated services
echo "🔨 Building services..."
COMPOSE_FILE=${COMPOSE_FILE} docker-compose -p ${PROJECT_NAME} build

# Deploy with zero downtime
echo "🎯 Deploying services..."
COMPOSE_FILE=${COMPOSE_FILE} docker-compose -p ${PROJECT_NAME} up -d

# Wait for health checks
echo "🩺 Waiting for health checks..."
sleep 30

# Verify deployment
echo "✅ Verifying deployment..."
COMPOSE_FILE=${COMPOSE_FILE} docker-compose -p ${PROJECT_NAME} ps

# Cleanup
echo "🧹 Cleaning up..."
docker system prune -f

echo "🎉 Deployment completed successfully!"
```

## 🎯 Chapter Checkpoint

### Questions

1. **What are the main components of a Docker Compose file?**
   - Services, networks, volumes, secrets, configs

2. **How do you scale services in Docker Compose?**
   - Use `--scale service=N` or `deploy.replicas` in compose file

3. **What's the difference between `depends_on` and `links`?**
   - `depends_on` controls startup order, `links` is deprecated

4. **How do you manage environment-specific configurations?**
   - Multiple compose files with override patterns

### Tasks

- [ ] Create multi-service compose applications
- [ ] Implement service scaling and load balancing
- [ ] Configure environment management
- [ ] Set up secrets and configuration management

---

## 🚀 What's Next?

In [Chapter 07: Docker Registry](../07-docker-registry/README.md), you'll learn:
- Private registry setup and management
- Image distribution strategies
- Registry security and authentication
- Content trust and signing
- Registry optimization and monitoring

## 📚 Key Takeaways

✅ **Docker Compose** orchestrates multi-container applications efficiently
✅ **Service scaling** enables horizontal scaling of application components
✅ **Environment management** supports deployment across different stages
✅ **Secrets management** provides secure handling of sensitive data
✅ **Network isolation** ensures proper service segmentation
✅ **Production patterns** enable reliable application deployment

## 📝 Practice Checklist

Before moving on, ensure you can:
- [ ] Write comprehensive Docker Compose files
- [ ] Orchestrate complex multi-container applications
- [ ] Implement service scaling and load balancing
- [ ] Manage environment-specific configurations
- [ ] Handle secrets and sensitive data securely
- [ ] Deploy production applications with Compose

---

**🎉 Congratulations!** You now have advanced Docker Compose skills for production deployments. Complete the [lab exercise](lab/README.md) to practice these concepts, then validate your knowledge with the [checkpoint](checkpoint.md)!

---

<div align="center">

**[⬅️ Previous: Docker Storage](../05-docker-storage/README.md)** | **[Next: Docker Registry ➡️](../07-docker-registry/README.md)**

</div> 