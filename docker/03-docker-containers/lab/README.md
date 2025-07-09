# 🧪 Lab 03: Advanced Container Management

In this lab, you'll practice advanced Docker container management including resource limits, health checks, monitoring, and troubleshooting.

## 🎯 Lab Objectives

By completing this lab, you will:
- Configure container resource limits and constraints
- Implement health checks and monitoring
- Practice container debugging techniques
- Create production-ready container configurations
- Use advanced container patterns

## 📋 Prerequisites

- Docker Engine installed and running
- Basic understanding of Docker commands
- Text editor (VS Code, nano, vim)
- Basic knowledge of bash scripting

## 🚀 Lab Exercises

### Exercise 1: Container Resource Management

**Goal:** Configure and test container resource limits.

#### Step 1: Memory Limits

Create a memory-intensive container to test limits:

```bash
# Create a simple memory test script
cat > memory-test.py << 'EOF'
#!/usr/bin/env python3
import time

def consume_memory(mb):
    """Consume specified amount of memory"""
    data = []
    for i in range(mb):
        # Allocate 1MB of memory
        chunk = 'x' * (1024 * 1024)
        data.append(chunk)
        print(f"Allocated {i+1} MB")
        time.sleep(0.1)
    
    print(f"Total allocated: {mb} MB")
    input("Press Enter to release memory...")

if __name__ == "__main__":
    consume_memory(100)  # Try to allocate 100MB
EOF

# Build container for memory testing
cat > Dockerfile.memory << 'EOF'
FROM python:3.11-alpine
COPY memory-test.py /app/
WORKDIR /app
CMD ["python", "memory-test.py"]
EOF

docker build -f Dockerfile.memory -t memory-test .
```

Test different memory limits:

```bash
# Test 1: Run without memory limit (should work)
docker run --rm --name unlimited-memory memory-test

# Test 2: Run with 50MB limit (should be killed)
docker run --rm --name limited-memory --memory=50m memory-test

# Test 3: Run with adequate memory
docker run --rm --name adequate-memory --memory=150m memory-test

# Monitor memory usage in real-time
docker stats limited-memory
```

#### Step 2: CPU Limits

Create CPU-intensive workload:

```bash
# Create CPU stress test
cat > cpu-test.py << 'EOF'
#!/usr/bin/env python3
import multiprocessing
import time
import math

def cpu_intensive_task(duration):
    """CPU-intensive computation"""
    start_time = time.time()
    while time.time() - start_time < duration:
        # Calculate prime numbers
        for i in range(1000):
            math.sqrt(i * i * i)

def stress_test():
    cores = multiprocessing.cpu_count()
    print(f"Starting CPU stress test on {cores} cores for 30 seconds...")
    
    processes = []
    for i in range(cores):
        p = multiprocessing.Process(target=cpu_intensive_task, args=(30,))
        p.start()
        processes.append(p)
    
    for p in processes:
        p.join()
    
    print("CPU stress test completed")

if __name__ == "__main__":
    stress_test()
EOF

cat > Dockerfile.cpu << 'EOF'
FROM python:3.11-alpine
COPY cpu-test.py /app/
WORKDIR /app
CMD ["python", "cpu-test.py"]
EOF

docker build -f Dockerfile.cpu -t cpu-test .
```

Test CPU limits:

```bash
# Test 1: Unlimited CPU
docker run --rm --name unlimited-cpu cpu-test &
docker stats unlimited-cpu

# Test 2: Limited to 0.5 CPU cores
docker run --rm --name limited-cpu --cpus="0.5" cpu-test &
docker stats limited-cpu

# Test 3: CPU pinning
docker run --rm --name pinned-cpu --cpuset-cpus="0" cpu-test &
docker stats pinned-cpu
```

#### Step 3: I/O Limits

```bash
# Create I/O intensive test
cat > io-test.sh << 'EOF'
#!/bin/bash
echo "Starting I/O stress test..."

# Write test
dd if=/dev/zero of=/tmp/testfile bs=1M count=100 oflag=dsync

# Read test
dd if=/tmp/testfile of=/dev/null bs=1M

echo "I/O test completed"
rm -f /tmp/testfile
EOF

chmod +x io-test.sh

cat > Dockerfile.io << 'EOF'
FROM alpine:latest
COPY io-test.sh /app/
WORKDIR /app
CMD ["./io-test.sh"]
EOF

docker build -f Dockerfile.io -t io-test .

# Test I/O limits
docker run --rm --name unlimited-io io-test

docker run --rm --name limited-io \
  --device-read-bps /dev/sda:1mb \
  --device-write-bps /dev/sda:1mb \
  io-test
```

### Exercise 2: Health Checks Implementation

**Goal:** Create and configure container health checks.

#### Step 1: Simple Web Application with Health Check

```python
# Create a web application with health endpoint
cat > web-app.py << 'EOF'
#!/usr/bin/env python3
from flask import Flask, jsonify
import time
import random
import os
import psutil

app = Flask(__name__)

# Simulate application state
app_start_time = time.time()
healthy = True

@app.route('/')
def index():
    return jsonify({
        'message': 'Web Application',
        'uptime': time.time() - app_start_time,
        'status': 'healthy' if healthy else 'unhealthy'
    })

@app.route('/health')
def health_check():
    """Comprehensive health check"""
    global healthy
    
    # Simulate random failures (10% chance)
    if random.random() < 0.1:
        healthy = False
    
    # Check system resources
    memory_percent = psutil.virtual_memory().percent
    cpu_percent = psutil.cpu_percent(interval=1)
    disk_percent = psutil.disk_usage('/').percent
    
    status = {
        'status': 'healthy' if healthy else 'unhealthy',
        'timestamp': time.time(),
        'uptime': time.time() - app_start_time,
        'system': {
            'memory_percent': memory_percent,
            'cpu_percent': cpu_percent,
            'disk_percent': disk_percent
        }
    }
    
    # Return unhealthy if resources are too high
    if memory_percent > 90 or cpu_percent > 90 or disk_percent > 90:
        status['status'] = 'unhealthy'
        healthy = False
    
    response_code = 200 if status['status'] == 'healthy' else 503
    return jsonify(status), response_code

@app.route('/toggle-health')
def toggle_health():
    """Toggle health status for testing"""
    global healthy
    healthy = not healthy
    return jsonify({'status': 'healthy' if healthy else 'unhealthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# Create requirements file
cat > requirements.txt << 'EOF'
Flask==2.3.2
psutil==5.9.5
EOF

# Create Dockerfile with health check
cat > Dockerfile.webapp << 'EOF'
FROM python:3.11-alpine

# Install system dependencies
RUN apk add --no-cache curl

# Install Python dependencies
COPY requirements.txt /app/
WORKDIR /app
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY web-app.py /app/

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5000/health || exit 1

EXPOSE 5000
CMD ["python", "web-app.py"]
EOF

docker build -f Dockerfile.webapp -t webapp-health .
```

#### Step 2: Test Health Check Behavior

```bash
# Run container with health check
docker run -d --name webapp-test -p 5000:5000 webapp-health

# Monitor health status
watch -n 2 'docker ps --format "table {{.Names}}\t{{.Status}}"'

# Check health status details
docker inspect webapp-test --format='{{.State.Health.Status}}'
docker inspect webapp-test --format='{{json .State.Health}}' | jq .

# Test health endpoint manually
curl http://localhost:5000/health | jq .

# Force unhealthy state
curl http://localhost:5000/toggle-health
```

#### Step 3: Advanced Health Check Script

```bash
# Create custom health check script
cat > health-check.py << 'EOF'
#!/usr/bin/env python3
import requests
import sys
import time
import json

def check_application_health():
    """Comprehensive application health check"""
    try:
        # Check main endpoint
        response = requests.get('http://localhost:5000/', timeout=5)
        if response.status_code != 200:
            print(f"Main endpoint failed: {response.status_code}")
            return False
        
        # Check health endpoint
        health_response = requests.get('http://localhost:5000/health', timeout=5)
        health_data = health_response.json()
        
        if health_data.get('status') != 'healthy':
            print(f"Health check failed: {health_data}")
            return False
        
        # Check resource usage
        system_info = health_data.get('system', {})
        if system_info.get('memory_percent', 0) > 85:
            print(f"High memory usage: {system_info['memory_percent']}%")
            return False
        
        print("All health checks passed")
        return True
        
    except Exception as e:
        print(f"Health check error: {e}")
        return False

if __name__ == "__main__":
    if check_application_health():
        sys.exit(0)
    else:
        sys.exit(1)
EOF

# Update Dockerfile to use custom health check
cat > Dockerfile.webapp-advanced << 'EOF'
FROM python:3.11-alpine

# Install system dependencies
RUN apk add --no-cache curl
RUN pip install requests

# Install Python dependencies
COPY requirements.txt /app/
WORKDIR /app
RUN pip install --no-cache-dir -r requirements.txt

# Copy application and health check
COPY web-app.py health-check.py /app/

# Advanced health check
HEALTHCHECK --interval=20s --timeout=10s --start-period=15s --retries=3 \
  CMD python health-check.py

EXPOSE 5000
CMD ["python", "web-app.py"]
EOF

docker build -f Dockerfile.webapp-advanced -t webapp-advanced .
docker run -d --name webapp-advanced -p 5001:5000 webapp-advanced
```

### Exercise 3: Container Monitoring and Debugging

**Goal:** Implement comprehensive container monitoring and practice debugging techniques.

#### Step 1: Monitoring Script

```python
# Create comprehensive monitoring script
cat > monitor.py << 'EOF'
#!/usr/bin/env python3
import docker
import time
import json
import threading
from datetime import datetime
import signal
import sys

class ContainerMonitor:
    def __init__(self):
        self.client = docker.from_env()
        self.monitoring = True
        self.containers_to_monitor = []
        
    def signal_handler(self, signum, frame):
        print("\n🛑 Stopping monitor...")
        self.monitoring = False
        sys.exit(0)
    
    def get_container_stats(self, container):
        """Get real-time container statistics"""
        try:
            stats = container.stats(stream=False)
            
            # Calculate CPU percentage
            cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - \
                       stats['precpu_stats']['cpu_usage']['total_usage']
            system_delta = stats['cpu_stats']['system_cpu_usage'] - \
                          stats['precpu_stats']['system_cpu_usage']
            
            cpu_percent = 0
            if system_delta > 0:
                cpu_percent = (cpu_delta / system_delta) * \
                             len(stats['cpu_stats']['cpu_usage']['percpu_usage']) * 100
            
            # Calculate memory usage
            memory_usage = stats['memory_stats']['usage']
            memory_limit = stats['memory_stats']['limit']
            memory_percent = (memory_usage / memory_limit) * 100
            
            # Network stats
            networks = stats.get('networks', {})
            total_rx = sum(net['rx_bytes'] for net in networks.values())
            total_tx = sum(net['tx_bytes'] for net in networks.values())
            
            return {
                'name': container.name,
                'cpu_percent': round(cpu_percent, 2),
                'memory_usage_mb': round(memory_usage / 1024 / 1024, 2),
                'memory_percent': round(memory_percent, 2),
                'network_rx_mb': round(total_rx / 1024 / 1024, 2),
                'network_tx_mb': round(total_tx / 1024 / 1024, 2),
                'timestamp': datetime.now().isoformat()
            }
            
        except Exception as e:
            return {
                'name': container.name,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    def check_container_health(self, container):
        """Check container health status"""
        try:
            health = container.attrs['State'].get('Health', {})
            return {
                'name': container.name,
                'health_status': health.get('Status', 'none'),
                'failing_streak': health.get('FailingStreak', 0),
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            return {
                'name': container.name,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    def monitor_container(self, container_name):
        """Monitor a specific container"""
        try:
            container = self.client.containers.get(container_name)
            
            while self.monitoring:
                # Get stats
                stats = self.get_container_stats(container)
                health = self.check_container_health(container)
                
                # Print monitoring info
                print(f"\n📊 {container_name} - {datetime.now().strftime('%H:%M:%S')}")
                if 'error' not in stats:
                    print(f"   CPU: {stats['cpu_percent']:.1f}%")
                    print(f"   Memory: {stats['memory_usage_mb']:.1f}MB ({stats['memory_percent']:.1f}%)")
                    print(f"   Network: RX {stats['network_rx_mb']:.1f}MB, TX {stats['network_tx_mb']:.1f}MB")
                else:
                    print(f"   Error: {stats['error']}")
                
                if 'error' not in health:
                    status_emoji = "✅" if health['health_status'] == 'healthy' else "❌"
                    print(f"   Health: {status_emoji} {health['health_status']}")
                    if health['failing_streak'] > 0:
                        print(f"   Failing streak: {health['failing_streak']}")
                
                # Alert on high resource usage
                if 'error' not in stats:
                    if stats['cpu_percent'] > 80:
                        print(f"   🚨 HIGH CPU USAGE: {stats['cpu_percent']:.1f}%")
                    if stats['memory_percent'] > 80:
                        print(f"   🚨 HIGH MEMORY USAGE: {stats['memory_percent']:.1f}%")
                
                time.sleep(5)
                
        except docker.errors.NotFound:
            print(f"❌ Container {container_name} not found")
        except Exception as e:
            print(f"❌ Error monitoring {container_name}: {e}")
    
    def monitor_all_containers(self):
        """Monitor all running containers"""
        signal.signal(signal.SIGINT, self.signal_handler)
        
        print("🔍 Starting container monitoring (Ctrl+C to stop)")
        
        while self.monitoring:
            try:
                containers = self.client.containers.list()
                
                if not containers:
                    print("📭 No running containers found")
                    time.sleep(10)
                    continue
                
                print(f"\n📊 Monitoring {len(containers)} containers - {datetime.now().strftime('%H:%M:%S')}")
                print("-" * 80)
                
                for container in containers:
                    stats = self.get_container_stats(container)
                    health = self.check_container_health(container)
                    
                    # Format output
                    status_line = f"{container.name:20}"
                    
                    if 'error' not in stats:
                        status_line += f" CPU:{stats['cpu_percent']:5.1f}%"
                        status_line += f" MEM:{stats['memory_percent']:5.1f}%"
                        status_line += f" ({stats['memory_usage_mb']:6.1f}MB)"
                    else:
                        status_line += f" ERROR: {stats['error']}"
                    
                    if 'error' not in health and health['health_status'] != 'none':
                        emoji = "✅" if health['health_status'] == 'healthy' else "❌"
                        status_line += f" {emoji}"
                    
                    print(status_line)
                
                time.sleep(10)
                
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"❌ Monitoring error: {e}")
                time.sleep(10)

if __name__ == "__main__":
    monitor = ContainerMonitor()
    
    if len(sys.argv) > 1:
        # Monitor specific container
        container_name = sys.argv[1]
        monitor.monitor_container(container_name)
    else:
        # Monitor all containers
        monitor.monitor_all_containers()
EOF

chmod +x monitor.py
```

#### Step 2: Create Test Containers

```bash
# Create problematic container for debugging practice
cat > problematic-app.py << 'EOF'
#!/usr/bin/env python3
import time
import random
import os
import sys

def memory_leak():
    """Simulate memory leak"""
    data = []
    while True:
        # Allocate memory continuously
        chunk = 'x' * (1024 * 1024)  # 1MB chunks
        data.append(chunk)
        time.sleep(1)
        
        if len(data) > 100:  # Limit to prevent system crash
            print("Memory leak simulation complete")
            break

def cpu_spike():
    """Simulate CPU spike"""
    for i in range(10):
        start = time.time()
        while time.time() - start < 5:  # 5 seconds of high CPU
            x = random.random() ** random.random()
        time.sleep(2)

def random_crash():
    """Randomly crash the application"""
    if random.random() < 0.3:  # 30% chance
        print("Application crashed!")
        sys.exit(1)

def main():
    scenario = os.environ.get('SCENARIO', 'normal')
    
    print(f"Starting application with scenario: {scenario}")
    
    if scenario == 'memory_leak':
        memory_leak()
    elif scenario == 'cpu_spike':
        cpu_spike()
    elif scenario == 'crash':
        random_crash()
    
    # Normal operation
    counter = 0
    while True:
        print(f"Application running... {counter}")
        counter += 1
        time.sleep(5)

if __name__ == "__main__":
    main()
EOF

cat > Dockerfile.problematic << 'EOF'
FROM python:3.11-alpine
COPY problematic-app.py /app/
WORKDIR /app
CMD ["python", "problematic-app.py"]
EOF

docker build -f Dockerfile.problematic -t problematic-app .

# Start test containers
docker run -d --name normal-app problematic-app
docker run -d --name memory-leak-app -e SCENARIO=memory_leak problematic-app
docker run -d --name cpu-spike-app -e SCENARIO=cpu_spike problematic-app
docker run -d --name crash-app -e SCENARIO=crash problematic-app
```

#### Step 3: Debugging Practice

```bash
# Start monitoring
python monitor.py &
MONITOR_PID=$!

# Debug exercises
echo "🔍 Debugging Exercise 1: Check container logs"
docker logs crash-app
docker logs --tail 20 -f memory-leak-app &

echo "🔍 Debugging Exercise 2: Inspect container state"
docker inspect crash-app --format='{{.State.ExitCode}}'
docker inspect memory-leak-app --format='{{.State.Status}}'

echo "🔍 Debugging Exercise 3: Execute commands in containers"
docker exec normal-app ps aux
docker exec memory-leak-app top -n 1

echo "🔍 Debugging Exercise 4: Check resource usage"
docker stats --no-stream

# Clean up
kill $MONITOR_PID 2>/dev/null
```

### Exercise 4: Production Container Patterns

**Goal:** Implement production-ready container patterns.

#### Step 1: Multi-Process Container with Supervisord

```bash
# Create supervisord configuration
cat > supervisord.conf << 'EOF'
[supervisord]
nodaemon=true
user=root

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:app]
command=python /app/app.py
directory=/app
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:worker]
command=python /app/worker.py
directory=/app
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

# Create simple Flask app
cat > app.py << 'EOF'
from flask import Flask, jsonify
import time

app = Flask(__name__)

@app.route('/')
def index():
    return jsonify({'message': 'Multi-process container', 'time': time.time()})

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# Create background worker
cat > worker.py << 'EOF'
import time
import random

def worker_task():
    while True:
        print(f"Worker processing task at {time.time()}")
        time.sleep(random.randint(5, 15))

if __name__ == '__main__':
    worker_task()
EOF

# Create nginx config
cat > nginx.conf << 'EOF'
server {
    listen 80;
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    location /health {
        proxy_pass http://localhost:5000/health;
    }
}
EOF

# Create multi-process Dockerfile
cat > Dockerfile.multiprocess << 'EOF'
FROM python:3.11-alpine

# Install nginx and supervisor
RUN apk add --no-cache nginx supervisor curl

# Install Python dependencies
RUN pip install flask

# Copy configurations
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx.conf /etc/nginx/http.d/default.conf

# Copy applications
COPY app.py worker.py /app/

# Create required directories
RUN mkdir -p /var/log/supervisor /run/nginx

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
EOF

docker build -f Dockerfile.multiprocess -t multiprocess-app .
docker run -d --name multiprocess-test -p 8080:80 multiprocess-app
```

#### Step 2: Sidecar Pattern

```bash
# Main application
docker run -d --name main-app \
  -v shared-logs:/var/log \
  nginx:alpine

# Log shipper sidecar
docker run -d --name log-shipper \
  -v shared-logs:/var/log:ro \
  --link main-app:app \
  alpine:latest \
  sh -c 'while true; do echo "Shipping logs at $(date)"; sleep 30; done'

# Monitoring sidecar
docker run -d --name monitor-sidecar \
  --pid container:main-app \
  --network container:main-app \
  alpine:latest \
  sh -c 'while true; do echo "Monitoring at $(date)"; sleep 10; done'
```

## ✅ Lab Verification

### Verification Steps

1. **Resource Management Verification:**
   ```bash
   # Check that memory-limited container was killed
   docker logs limited-memory | grep -i "killed"
   
   # Verify CPU limits are working
   docker stats limited-cpu --no-stream
   ```

2. **Health Check Verification:**
   ```bash
   # Verify health check is working
   docker inspect webapp-test --format='{{.State.Health.Status}}'
   
   # Test health check failure
   curl http://localhost:5000/toggle-health
   sleep 60
   docker inspect webapp-test --format='{{.State.Health.Status}}'
   ```

3. **Monitoring Verification:**
   ```bash
   # Run monitoring script and verify output
   python monitor.py webapp-test
   ```

4. **Multi-Process Verification:**
   ```bash
   # Check all processes are running
   docker exec multiprocess-test ps aux
   
   # Test application through nginx
   curl http://localhost:8080/
   curl http://localhost:8080/health
   ```

### Expected Outcomes

- Memory-limited containers should be killed when exceeding limits
- CPU-limited containers should show restricted usage in stats
- Health checks should transition between healthy/unhealthy states
- Monitoring script should display real-time container metrics
- Multi-process container should run nginx, app, and worker simultaneously

## 🧹 Cleanup

```bash
# Stop and remove all test containers
docker stop $(docker ps -aq --filter "name=*-test") 2>/dev/null || true
docker stop $(docker ps -aq --filter "name=*-app") 2>/dev/null || true
docker stop $(docker ps -aq --filter "name=*-sidecar") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=*-test") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=*-app") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=*-sidecar") 2>/dev/null || true

# Remove test images
docker rmi memory-test cpu-test io-test webapp-health webapp-advanced problematic-app multiprocess-app 2>/dev/null || true

# Remove test files
rm -f memory-test.py cpu-test.py io-test.sh web-app.py health-check.py
rm -f monitor.py problematic-app.py app.py worker.py
rm -f Dockerfile.* requirements.txt supervisord.conf nginx.conf

# Remove shared volume
docker volume rm shared-logs 2>/dev/null || true

echo "🧹 Lab cleanup completed!"
```

## 📚 Additional Challenges

1. **Create a custom monitoring dashboard** that displays container metrics in a web interface
2. **Implement automatic container scaling** based on resource usage
3. **Set up log aggregation** for multiple containers using ELK stack
4. **Create a container orchestration script** that manages multiple related containers
5. **Implement container backup and restore** procedures

## 🎯 Lab Summary

In this lab, you:
- ✅ Configured and tested container resource limits
- ✅ Implemented comprehensive health checks
- ✅ Created monitoring and debugging tools
- ✅ Practiced container troubleshooting techniques
- ✅ Built production-ready container patterns

**🎉 Congratulations!** You've mastered advanced Docker container management. These skills form the foundation for production container deployments.

---

**[⬅️ Back to Chapter 03](../README.md)** | **[Next: Checkpoint ➡️](../checkpoint.md)** 