# 🐳 Chapter 03: Docker Containers - Advanced Container Management & Runtime

Welcome to advanced Docker container management! In this chapter, you'll master container lifecycle, runtime configurations, resource management, and production-ready container patterns.

## 🎯 Learning Objectives

By the end of this chapter, you will:
- ✅ Master advanced container lifecycle management
- ✅ Configure container runtime settings and resource limits
- ✅ Implement container health checks and monitoring
- ✅ Manage container networking and inter-container communication
- ✅ Use advanced container patterns for production
- ✅ Troubleshoot container issues effectively

## 🏗️ Container Architecture Deep Dive

### Container vs. Process vs. Virtual Machine

```
┌─────────────────────────────────────────┐
│               Virtual Machine           │
├─────────────────────────────────────────┤
│  Guest OS  │  Guest OS  │  Guest OS     │ ← Full OS overhead
├─────────────────────────────────────────┤
│              Hypervisor                 │
├─────────────────────────────────────────┤
│               Host OS                   │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│            Docker Containers           │
├─────────────────────────────────────────┤
│   App A   │   App B   │   App C        │ ← Shared kernel
├─────────────────────────────────────────┤
│           Docker Engine                 │
├─────────────────────────────────────────┤
│               Host OS                   │
└─────────────────────────────────────────┘
```

### Container Namespaces & Control Groups

**Linux Namespaces isolate:**
- **PID**: Process IDs
- **NET**: Network interfaces
- **MNT**: Mount points
- **UTS**: Hostname
- **IPC**: Inter-process communication
- **USER**: User and group IDs

**Control Groups (cgroups) limit:**
- **CPU**: Processing power
- **Memory**: RAM usage
- **Block I/O**: Disk operations
- **Network**: Bandwidth

## 🚀 Advanced Container Lifecycle Management

### 1. Container States & Transitions

```bash
# Container lifecycle states
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

# State transitions
Created → Running → Paused → Stopped → Removed
    ↓        ↓        ↓        ↓
  Start    Pause    Stop    Remove
```

**Advanced container management:**
```bash
# Create container without starting
docker create --name myapp nginx:alpine

# Start created container
docker start myapp

# Pause/unpause running container
docker pause myapp
docker unpause myapp

# Send signals to container
docker kill --signal=SIGUSR1 myapp
docker kill --signal=SIGTERM myapp

# Wait for container to exit
docker wait myapp

# Get container exit code
echo $?
```

### 2. Container Inspection & Debugging

```bash
# Comprehensive container inspection
docker inspect myapp

# Get specific information with format
docker inspect myapp --format='{{.State.Status}}'
docker inspect myapp --format='{{.NetworkSettings.IPAddress}}'
docker inspect myapp --format='{{.Config.Env}}'

# Container processes
docker top myapp

# Container resource usage
docker stats myapp

# Container changes (filesystem diff)
docker diff myapp

# Export container as tar
docker export myapp > myapp.tar
```

### 3. Container Logs & Monitoring

```bash
# Basic logging
docker logs myapp

# Follow logs in real-time
docker logs -f myapp

# Show timestamps
docker logs -t myapp

# Show last N lines
docker logs --tail 50 myapp

# Filter logs by time
docker logs --since="2023-01-01T10:00:00" myapp
docker logs --until="2023-01-01T12:00:00" myapp

# JSON log driver details
docker logs myapp --details
```

**Advanced logging configuration:**
```bash
# Run with specific log driver
docker run -d \
  --name myapp \
  --log-driver=json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  nginx:alpine

# Syslog driver
docker run -d \
  --log-driver=syslog \
  --log-opt syslog-address=tcp://192.168.1.100:514 \
  --log-opt tag="myapp" \
  nginx:alpine

# Disable logging (performance)
docker run -d --log-driver=none nginx:alpine
```

## ⚙️ Container Runtime Configuration

### 1. Resource Limits & Constraints

**Memory limits:**
```bash
# Memory limits
docker run -d --name memory-test \
  --memory=512m \
  --memory-swap=1g \
  --memory-swappiness=60 \
  nginx:alpine

# OOM kill protection
docker run -d --name critical-app \
  --memory=256m \
  --oom-kill-disable \
  nginx:alpine

# Memory reservation (soft limit)
docker run -d --name flexible-app \
  --memory=1g \
  --memory-reservation=512m \
  nginx:alpine
```

**CPU limits:**
```bash
# CPU constraints
docker run -d --name cpu-test \
  --cpus="1.5" \
  --cpu-shares=1024 \
  nginx:alpine

# CPU pinning
docker run -d --name pinned-app \
  --cpuset-cpus="0,1" \
  --cpuset-mems="0" \
  nginx:alpine

# CPU quota (more granular)
docker run -d --name quota-app \
  --cpu-period=100000 \
  --cpu-quota=50000 \
  nginx:alpine
```

**I/O limits:**
```bash
# Block I/O limits
docker run -d --name io-test \
  --device-read-bps /dev/sda:1mb \
  --device-write-bps /dev/sda:1mb \
  --device-read-iops /dev/sda:1000 \
  --device-write-iops /dev/sda:1000 \
  nginx:alpine

# Blkio weight (relative I/O priority)
docker run -d --name heavy-io \
  --blkio-weight=600 \
  nginx:alpine
```

### 2. Security & Isolation

**User namespace mapping:**
```bash
# Run as specific user
docker run -d --name secure-app \
  --user 1001:1001 \
  nginx:alpine

# Read-only filesystem
docker run -d --name readonly-app \
  --read-only \
  --tmpfs /tmp \
  --tmpfs /var/cache/nginx \
  nginx:alpine

# Drop capabilities
docker run -d --name minimal-caps \
  --cap-drop ALL \
  --cap-add NET_BIND_SERVICE \
  nginx:alpine

# Security options
docker run -d --name secure-container \
  --security-opt no-new-privileges:true \
  --security-opt apparmor:docker-nginx \
  nginx:alpine
```

**Privileged vs unprivileged containers:**
```bash
# Privileged container (avoid in production)
docker run -d --name privileged-container \
  --privileged \
  nginx:alpine

# Unprivileged with specific access
docker run -d --name device-access \
  --device /dev/sda:/dev/xvda:r \
  nginx:alpine
```

### 3. Environment & Configuration

```bash
# Environment variables
docker run -d --name env-app \
  -e NODE_ENV=production \
  -e DATABASE_URL=postgresql://user:pass@db:5432/app \
  --env-file .env \
  node:16-alpine

# Working directory
docker run -d --name workdir-app \
  --workdir /app \
  node:16-alpine

# Entry point and command override
docker run -d --name custom-cmd \
  --entrypoint="" \
  nginx:alpine \
  sh -c "echo 'Custom command' && nginx -g 'daemon off;'"
```

## 🔗 Container Networking Basics

### 1. Network Modes

```bash
# Default bridge network
docker run -d --name bridge-app nginx:alpine

# Host network (shares host network stack)
docker run -d --name host-app --network host nginx:alpine

# No network
docker run -d --name isolated-app --network none alpine sleep 3600

# Container network (share with another container)
docker run -d --name app1 nginx:alpine
docker run -d --name app2 --network container:app1 alpine sleep 3600
```

### 2. Port Mapping & Exposure

```bash
# Basic port mapping
docker run -d --name web-app -p 8080:80 nginx:alpine

# Multiple ports
docker run -d --name multi-port \
  -p 8080:80 \
  -p 8443:443 \
  nginx:alpine

# Bind to specific interface
docker run -d --name specific-bind \
  -p 127.0.0.1:8080:80 \
  nginx:alpine

# Random port assignment
docker run -d --name random-port -P nginx:alpine

# Check port mappings
docker port random-port
```

### 3. Inter-Container Communication

```bash
# Legacy linking (deprecated)
docker run -d --name database postgres:13
docker run -d --name webapp --link database:db nginx:alpine

# Modern approach: Custom networks
docker network create mynetwork
docker run -d --name database --network mynetwork postgres:13
docker run -d --name webapp --network mynetwork nginx:alpine

# DNS resolution works automatically
# webapp can reach database using hostname 'database'
```

## 🔍 Health Checks & Monitoring

### 1. Container Health Checks

**Dockerfile health check:**
```dockerfile
FROM nginx:alpine

# Add health check endpoint
RUN echo 'server { listen 8080; location /health { return 200 "OK\n"; } }' > /etc/nginx/conf.d/health.conf

# Health check instruction
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 80 8080
```

**Runtime health check:**
```bash
# Add health check to running container
docker run -d --name healthy-app \
  --health-cmd="curl -f http://localhost:8080/health || exit 1" \
  --health-interval=30s \
  --health-timeout=3s \
  --health-start-period=10s \
  --health-retries=3 \
  nginx:alpine

# Check health status
docker ps
docker inspect healthy-app --format='{{.State.Health.Status}}'

# Health check logs
docker inspect healthy-app --format='{{range .State.Health.Log}}{{.Output}}{{end}}'
```

### 2. Container Metrics & Statistics

```bash
# Real-time resource usage
docker stats

# Specific container stats
docker stats myapp --no-stream

# Format output
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Export stats for monitoring
docker stats --no-stream --format json > container-stats.json
```

**Custom monitoring script:**
```bash
#!/bin/bash
# monitor-containers.sh

# Function to check container health
check_container_health() {
    local container=$1
    local status=$(docker inspect $container --format='{{.State.Health.Status}}' 2>/dev/null)
    
    case $status in
        "healthy")
            echo "✅ $container: Healthy"
            ;;
        "unhealthy")
            echo "❌ $container: Unhealthy"
            # Get last health check log
            docker inspect $container --format='{{range .State.Health.Log}}{{.Output}}{{end}}' | tail -1
            ;;
        "starting")
            echo "🔄 $container: Starting health checks"
            ;;
        *)
            echo "⚠️  $container: No health check configured"
            ;;
    esac
}

# Check all running containers
for container in $(docker ps --format "{{.Names}}"); do
    check_container_health $container
done
```

## 🐍 Advanced Container Patterns

### 1. Init Process & Signal Handling

**Problem:** PID 1 signal handling and zombie processes

**Solution:** Use proper init system

```dockerfile
# Option 1: tini
FROM node:16-alpine
RUN apk add --no-cache tini
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]

# Option 2: dumb-init
FROM node:16-alpine
RUN apk add --no-cache dumb-init
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]

# Option 3: Built-in init
# docker run --init myapp
```

### 2. Multi-Process Containers

**Using supervisord:**
```dockerfile
FROM python:3.11-alpine

# Install supervisord
RUN apk add --no-cache supervisor

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy applications
COPY web-app.py /app/
COPY worker.py /app/
COPY nginx.conf /etc/nginx/

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
```

**supervisord.conf:**
```ini
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/nginx.err.log
stdout_logfile=/var/log/supervisor/nginx.out.log

[program:webapp]
command=python /app/web-app.py
directory=/app
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/webapp.err.log
stdout_logfile=/var/log/supervisor/webapp.out.log

[program:worker]
command=python /app/worker.py
directory=/app
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/worker.err.log
stdout_logfile=/var/log/supervisor/worker.out.log
```

### 3. Sidecar Pattern

```bash
# Main application container
docker run -d --name main-app \
  -v shared-data:/data \
  myapp:latest

# Sidecar for logging
docker run -d --name log-shipper \
  -v shared-data:/data:ro \
  --log-driver=syslog \
  fluent/fluent-bit

# Sidecar for monitoring
docker run -d --name metrics-collector \
  --pid container:main-app \
  --network container:main-app \
  prometheus/node-exporter
```

## 🛠️ Container Troubleshooting

### 1. Debugging Techniques

```bash
# Execute commands in running container
docker exec -it myapp bash
docker exec -it myapp sh  # for alpine
docker exec myapp ls -la /app

# Debug container that won't start
docker logs myapp
docker inspect myapp --format='{{.State.ExitCode}}'

# Run container in interactive debug mode
docker run -it --rm myapp:latest sh

# Override entrypoint for debugging
docker run -it --rm --entrypoint="" myapp:latest sh

# Debug with different user
docker exec -it --user root myapp bash
```

### 2. Common Issues & Solutions

**Container exits immediately:**
```bash
# Check exit code and logs
docker logs myapp
docker inspect myapp --format='{{.State.ExitCode}}'

# Common causes:
# Exit code 125: Docker daemon error
# Exit code 126: Container command not executable
# Exit code 127: Container command not found
# Exit code 1: General application error
```

**Out of memory issues:**
```bash
# Check memory usage
docker stats myapp

# Check system messages for OOM kills
dmesg | grep -i "killed process"

# Increase memory limit
docker update --memory=1g myapp
```

**Permission issues:**
```bash
# Check container user
docker exec myapp id

# Run as root for debugging
docker exec -it --user root myapp bash

# Fix ownership
docker exec --user root myapp chown -R appuser:appuser /app
```

### 3. Performance Optimization

```bash
# Analyze container performance
docker stats myapp --no-stream

# CPU optimization
docker update --cpus="2" myapp
docker update --cpu-shares=512 myapp

# Memory optimization
docker update --memory=512m --memory-swap=1g myapp

# I/O optimization
docker run -d --name optimized-app \
  --device-read-bps /dev/sda:10mb \
  --device-write-bps /dev/sda:5mb \
  myapp:latest
```

## 🔧 Container Management Scripts

### 1. Container Health Monitoring

**health-monitor.py:**
```python
#!/usr/bin/env python3
import docker
import time
import json
from datetime import datetime

class ContainerHealthMonitor:
    def __init__(self):
        self.client = docker.from_env()
        self.unhealthy_containers = set()
    
    def check_container_health(self, container):
        """Check individual container health"""
        try:
            health = container.attrs['State'].get('Health', {})
            status = health.get('Status', 'none')
            
            return {
                'name': container.name,
                'id': container.short_id,
                'status': status,
                'failing_streak': health.get('FailingStreak', 0),
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            return {
                'name': container.name,
                'id': container.short_id,
                'status': 'error',
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    def monitor_all_containers(self):
        """Monitor health of all running containers"""
        containers = self.client.containers.list()
        health_report = []
        
        for container in containers:
            health_info = self.check_container_health(container)
            health_report.append(health_info)
            
            # Alert on unhealthy containers
            if health_info['status'] == 'unhealthy':
                if container.name not in self.unhealthy_containers:
                    self.send_alert(health_info)
                    self.unhealthy_containers.add(container.name)
            else:
                # Remove from unhealthy set if recovered
                self.unhealthy_containers.discard(container.name)
        
        return health_report
    
    def send_alert(self, health_info):
        """Send alert for unhealthy container"""
        print(f"🚨 ALERT: Container {health_info['name']} is unhealthy!")
        # Add webhook, email, or Slack notification here
    
    def run_continuous_monitoring(self, interval=30):
        """Run continuous health monitoring"""
        print(f"🔍 Starting container health monitoring (interval: {interval}s)")
        
        while True:
            try:
                health_report = self.monitor_all_containers()
                
                # Print summary
                healthy = sum(1 for h in health_report if h['status'] == 'healthy')
                unhealthy = sum(1 for h in health_report if h['status'] == 'unhealthy')
                
                print(f"📊 Health Summary: {healthy} healthy, {unhealthy} unhealthy")
                
                time.sleep(interval)
                
            except KeyboardInterrupt:
                print("\n👋 Monitoring stopped by user")
                break
            except Exception as e:
                print(f"❌ Monitoring error: {e}")
                time.sleep(interval)

if __name__ == "__main__":
    monitor = ContainerHealthMonitor()
    monitor.run_continuous_monitoring()
```

### 2. Container Resource Manager

**resource-manager.sh:**
```bash
#!/bin/bash
# Container Resource Management Script

# Configuration
MAX_MEMORY_PERCENT=80
MAX_CPU_PERCENT=80
ALERT_THRESHOLD=90

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

get_container_stats() {
    docker stats --no-stream --format json | jq -r '
        .Name + "," + 
        (.CPUPerc | gsub("%"; "")) + "," + 
        (.MemPerc | gsub("%"; "")) + "," + 
        .MemUsage + "," + 
        .BlockIO
    '
}

check_resource_usage() {
    log "📊 Checking container resource usage..."
    
    while IFS=',' read -r name cpu_percent mem_percent mem_usage block_io; do
        # Skip header
        [[ "$name" == "NAME" ]] && continue
        
        cpu_int=${cpu_percent%.*}
        mem_int=${mem_percent%.*}
        
        status="✅"
        alerts=""
        
        # Check CPU usage
        if (( cpu_int > ALERT_THRESHOLD )); then
            status="🚨"
            alerts+=" CPU:${cpu_percent}%"
        elif (( cpu_int > MAX_CPU_PERCENT )); then
            status="⚠️"
            alerts+=" CPU:${cpu_percent}%"
        fi
        
        # Check memory usage
        if (( mem_int > ALERT_THRESHOLD )); then
            status="🚨"
            alerts+=" MEM:${mem_percent}%"
        elif (( mem_int > MAX_MEMORY_PERCENT )); then
            status="⚠️"
            alerts+=" MEM:${mem_percent}%"
        fi
        
        # Log status
        if [[ -n "$alerts" ]]; then
            echo -e "${status} ${name}: ${alerts} | Memory: ${mem_usage}"
        else
            echo -e "${status} ${name}: Normal (CPU: ${cpu_percent}%, Mem: ${mem_percent}%)"
        fi
        
    done < <(get_container_stats)
}

auto_scale_container() {
    local container_name=$1
    local current_cpu=$2
    local current_mem=$3
    
    log "🔧 Auto-scaling $container_name (CPU: $current_cpu%, Mem: $current_mem%)"
    
    # Example: Increase memory limit if usage is high
    if (( current_mem > 85 )); then
        current_limit=$(docker inspect $container_name --format='{{.HostConfig.Memory}}')
        new_limit=$((current_limit * 120 / 100))  # Increase by 20%
        
        docker update --memory=${new_limit} $container_name
        log "📈 Increased memory limit for $container_name to $new_limit bytes"
    fi
}

restart_unhealthy_containers() {
    log "🔄 Checking for unhealthy containers..."
    
    unhealthy_containers=$(docker ps --filter health=unhealthy --format "{{.Names}}")
    
    for container in $unhealthy_containers; do
        log "⚕️ Restarting unhealthy container: $container"
        docker restart $container
        
        # Wait and check if restart helped
        sleep 10
        health_status=$(docker inspect $container --format='{{.State.Health.Status}}')
        
        if [[ "$health_status" == "healthy" ]]; then
            log "✅ Container $container is now healthy"
        else
            log "❌ Container $container is still unhealthy after restart"
        fi
    done
}

cleanup_resources() {
    log "🧹 Cleaning up unused resources..."
    
    # Remove stopped containers
    stopped_containers=$(docker ps -aq --filter status=exited)
    if [[ -n "$stopped_containers" ]]; then
        docker rm $stopped_containers
        log "🗑️ Removed stopped containers"
    fi
    
    # Remove unused images
    docker image prune -f
    log "🗑️ Removed unused images"
    
    # Remove unused networks
    docker network prune -f
    log "🗑️ Removed unused networks"
    
    # Remove unused volumes (be careful!)
    # docker volume prune -f
}

main() {
    case "${1:-status}" in
        "monitor")
            while true; do
                check_resource_usage
                restart_unhealthy_containers
                echo "---"
                sleep 60
            done
            ;;
        "cleanup")
            cleanup_resources
            ;;
        "status")
            check_resource_usage
            ;;
        *)
            echo "Usage: $0 {monitor|cleanup|status}"
            echo "  monitor  - Continuous monitoring"
            echo "  cleanup  - Clean unused resources"
            echo "  status   - Check current status"
            exit 1
            ;;
    esac
}

main "$@"
```

## 🚀 Production Container Patterns

### 1. Blue-Green Deployment with Containers

```bash
#!/bin/bash
# blue-green-deploy.sh

BLUE_CONTAINER="myapp-blue"
GREEN_CONTAINER="myapp-green"
NGINX_CONTAINER="nginx-proxy"
NEW_IMAGE="myapp:v2.0.0"

deploy_green() {
    echo "🟢 Deploying green environment..."
    
    # Start green container
    docker run -d --name $GREEN_CONTAINER \
        --network myapp-network \
        -e ENVIRONMENT=production \
        $NEW_IMAGE
    
    # Wait for health check
    echo "⏳ Waiting for green container to be healthy..."
    while [[ "$(docker inspect $GREEN_CONTAINER --format='{{.State.Health.Status}}')" != "healthy" ]]; do
        sleep 5
    done
    
    echo "✅ Green container is healthy"
}

switch_traffic() {
    echo "🔄 Switching traffic to green..."
    
    # Update nginx config to point to green
    docker exec $NGINX_CONTAINER \
        sh -c "sed -i 's/$BLUE_CONTAINER/$GREEN_CONTAINER/g' /etc/nginx/conf.d/default.conf"
    
    # Reload nginx
    docker exec $NGINX_CONTAINER nginx -s reload
    
    echo "✅ Traffic switched to green"
}

cleanup_blue() {
    echo "🔵 Cleaning up blue environment..."
    docker stop $BLUE_CONTAINER
    docker rm $BLUE_CONTAINER
    echo "✅ Blue environment cleaned up"
}

# Execute deployment
deploy_green
switch_traffic
cleanup_blue
```

### 2. Rolling Updates

```bash
#!/bin/bash
# rolling-update.sh

APP_NAME="myapp"
NEW_IMAGE="myapp:v2.0.0"
REPLICAS=3

rolling_update() {
    echo "🔄 Starting rolling update for $APP_NAME..."
    
    for i in $(seq 1 $REPLICAS); do
        container_name="${APP_NAME}-${i}"
        
        echo "📦 Updating $container_name..."
        
        # Stop old container
        docker stop $container_name
        docker rm $container_name
        
        # Start new container
        docker run -d --name $container_name \
            --network myapp-network \
            -e REPLICA_ID=$i \
            $NEW_IMAGE
        
        # Wait for health check
        while [[ "$(docker inspect $container_name --format='{{.State.Health.Status}}')" != "healthy" ]]; do
            echo "⏳ Waiting for $container_name to be healthy..."
            sleep 5
        done
        
        echo "✅ $container_name updated successfully"
        
        # Wait before updating next replica
        sleep 10
    done
    
    echo "🎉 Rolling update completed!"
}

rolling_update
```

## 🔍 Container Security Best Practices

### 1. Security Scanning Integration

**security-scan.sh:**
```bash
#!/bin/bash
# Container security scanning script

CONTAINER_NAME=$1
SCAN_RESULTS_DIR="./security-scans"

if [[ -z "$CONTAINER_NAME" ]]; then
    echo "Usage: $0 <container-name>"
    exit 1
fi

mkdir -p $SCAN_RESULTS_DIR

echo "🔍 Starting security scan for $CONTAINER_NAME..."

# Get container image
IMAGE=$(docker inspect $CONTAINER_NAME --format='{{.Config.Image}}')
echo "📦 Scanning image: $IMAGE"

# Trivy vulnerability scan
echo "🛡️ Running vulnerability scan with Trivy..."
trivy image --format json --output "$SCAN_RESULTS_DIR/${CONTAINER_NAME}-vulnerabilities.json" $IMAGE

# Docker bench security
echo "🔒 Running Docker Bench Security..."
docker run --rm -it \
    --net host \
    --pid host \
    --userns host \
    --cap-add audit_control \
    -e DOCKER_CONTENT_TRUST=$DOCKER_CONTENT_TRUST \
    -v /etc:/etc:ro \
    -v /var/lib:/var/lib:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v /usr/bin/containerd:/usr/bin/containerd:ro \
    -v /usr/bin/runc:/usr/bin/runc:ro \
    -v /usr/lib/systemd:/usr/lib/systemd:ro \
    -v /usr/bin/docker:/usr/bin/docker:ro \
    --label docker_bench_security \
    docker/docker-bench-security > "$SCAN_RESULTS_DIR/${CONTAINER_NAME}-bench.txt"

# Check for secrets
echo "🕵️ Scanning for secrets..."
docker exec $CONTAINER_NAME find / -name "*.key" -o -name "*.pem" -o -name "*password*" 2>/dev/null > "$SCAN_RESULTS_DIR/${CONTAINER_NAME}-secrets.txt"

echo "✅ Security scan completed. Results saved to $SCAN_RESULTS_DIR/"
```

### 2. Runtime Security Monitoring

```python
#!/usr/bin/env python3
# runtime-security-monitor.py

import docker
import psutil
import time
import json
from datetime import datetime

class RuntimeSecurityMonitor:
    def __init__(self):
        self.client = docker.from_env()
        self.baseline_processes = {}
        
    def get_container_processes(self, container):
        """Get processes running in container"""
        try:
            result = container.exec_run("ps aux", stdout=True, stderr=True)
            if result.exit_code == 0:
                return result.output.decode().strip().split('\n')[1:]  # Skip header
            return []
        except Exception as e:
            print(f"Error getting processes for {container.name}: {e}")
            return []
    
    def establish_baseline(self, container):
        """Establish baseline processes for container"""
        processes = self.get_container_processes(container)
        self.baseline_processes[container.name] = set(
            line.split()[10] for line in processes if len(line.split()) > 10
        )
        print(f"📊 Established baseline for {container.name}: {len(self.baseline_processes[container.name])} processes")
    
    def detect_anomalies(self, container):
        """Detect process anomalies"""
        current_processes = set(
            line.split()[10] for line in self.get_container_processes(container) 
            if len(line.split()) > 10
        )
        
        baseline = self.baseline_processes.get(container.name, set())
        
        # New processes
        new_processes = current_processes - baseline
        if new_processes:
            print(f"🚨 New processes detected in {container.name}: {new_processes}")
            return True
        
        return False
    
    def check_network_connections(self, container):
        """Check for suspicious network connections"""
        try:
            result = container.exec_run("netstat -tuln", stdout=True, stderr=True)
            if result.exit_code == 0:
                connections = result.output.decode().strip().split('\n')
                listening_ports = []
                for line in connections:
                    if 'LISTEN' in line:
                        parts = line.split()
                        if len(parts) >= 4:
                            listening_ports.append(parts[3])
                
                # Alert on unexpected ports
                unexpected_ports = [p for p in listening_ports if ':22' in p or ':23' in p]
                if unexpected_ports:
                    print(f"🚨 Suspicious ports detected in {container.name}: {unexpected_ports}")
                    return True
        except Exception as e:
            print(f"Error checking network for {container.name}: {e}")
        
        return False
    
    def monitor_file_integrity(self, container):
        """Monitor critical file changes"""
        critical_files = ['/etc/passwd', '/etc/shadow', '/etc/hosts', '/root/.ssh/authorized_keys']
        
        try:
            for file_path in critical_files:
                result = container.exec_run(f"stat {file_path}", stdout=True, stderr=True)
                if result.exit_code == 0:
                    # In production, you'd store and compare file hashes
                    pass
        except Exception as e:
            print(f"Error checking file integrity for {container.name}: {e}")
    
    def run_security_monitoring(self, interval=60):
        """Run continuous security monitoring"""
        print("🛡️ Starting runtime security monitoring...")
        
        # Establish baselines for all containers
        for container in self.client.containers.list():
            self.establish_baseline(container)
        
        while True:
            try:
                print(f"\n🔍 Security check at {datetime.now().strftime('%H:%M:%S')}")
                
                for container in self.client.containers.list():
                    anomaly_detected = False
                    
                    # Check for process anomalies
                    if self.detect_anomalies(container):
                        anomaly_detected = True
                    
                    # Check network connections
                    if self.check_network_connections(container):
                        anomaly_detected = True
                    
                    # Monitor file integrity
                    self.monitor_file_integrity(container)
                    
                    if not anomaly_detected:
                        print(f"✅ {container.name}: No anomalies detected")
                
                time.sleep(interval)
                
            except KeyboardInterrupt:
                print("\n👋 Security monitoring stopped")
                break
            except Exception as e:
                print(f"❌ Monitoring error: {e}")
                time.sleep(interval)

if __name__ == "__main__":
    monitor = RuntimeSecurityMonitor()
    monitor.run_security_monitoring()
```

## 🎯 Chapter Checkpoint

### Questions

1. **What are the main differences between containers and virtual machines?**
   - Containers share the host OS kernel, VMs include full guest OS

2. **How do you limit a container's memory usage to 512MB?**
   - `docker run --memory=512m myapp`

3. **What is the purpose of health checks in containers?**
   - Monitor application health and enable automatic recovery

4. **How can you troubleshoot a container that exits immediately?**
   - Check logs (`docker logs`), inspect exit code, override entrypoint

### Tasks

- [ ] Configure resource limits for a container
- [ ] Implement health checks for an application
- [ ] Set up container monitoring and alerting
- [ ] Create a multi-process container using supervisord

---

## 🚀 What's Next?

In [Chapter 04: Docker Networking](../04-docker-networking/README.md), you'll learn:
- Advanced Docker networking concepts
- Custom networks and service discovery
- Load balancing and traffic management
- Network security and isolation
- Multi-host networking

## 📚 Key Takeaways

✅ **Resource limits** prevent containers from consuming excessive system resources
✅ **Health checks** enable automatic monitoring and recovery
✅ **Proper signal handling** ensures graceful container shutdown
✅ **Security best practices** protect against container-based attacks
✅ **Monitoring and logging** provide visibility into container behavior
✅ **Production patterns** enable reliable container deployment strategies

## 📝 Practice Checklist

Before moving on, ensure you can:
- [ ] Configure container resource limits and constraints
- [ ] Implement and troubleshoot health checks
- [ ] Monitor container performance and security
- [ ] Use advanced container patterns for production
- [ ] Debug and resolve common container issues

---

**🎉 Congratulations!** You now have advanced Docker container management skills. Complete the [lab exercise](lab/README.md) to practice these concepts, then validate your knowledge with the [checkpoint](checkpoint.md)!

---

<div align="center">

**[⬅️ Previous: Docker Images](../02-docker-images/README.md)** | **[Next: Docker Networking ➡️](../04-docker-networking/README.md)**

</div> 