# 🔬 Chapter 09 Lab: Docker Best Practices Implementation

## 🎯 Lab Objectives

In this hands-on lab, you'll implement production-grade Docker best practices:
- Production deployment patterns (Blue-Green, Canary)
- Performance optimization techniques
- Comprehensive monitoring and observability
- Troubleshooting and debugging workflows
- Operational excellence practices

**Estimated Time:** 3 hours  
**Difficulty:** Advanced  
**Prerequisites:** Completed Chapters 01-08

---

## 🚀 Lab Setup

### Initial Environment

```bash
# Create lab directory
mkdir -p docker-best-practices-lab/{apps,monitoring,deployment,scripts}
cd docker-best-practices-lab

# Create sample application
cat > apps/app.py << 'EOF'
from flask import Flask, jsonify, request
import time
import random
import os
import redis

app = Flask(__name__)
redis_client = redis.Redis(host=os.getenv('REDIS_HOST', 'localhost'), port=6379, decode_responses=True)

@app.route('/')
def home():
    return jsonify({
        'message': 'Production Flask App',
        'version': os.getenv('APP_VERSION', '1.0.0'),
        'hostname': os.getenv('HOSTNAME', 'unknown')
    })

@app.route('/health')
def health():
    try:
        redis_client.ping()
        return jsonify({'status': 'healthy', 'redis': 'connected'})
    except:
        return jsonify({'status': 'unhealthy', 'redis': 'disconnected'}), 503

@app.route('/api/data')
def get_data():
    # Simulate processing time
    time.sleep(random.uniform(0.1, 0.5))
    
    # Random failure simulation
    if random.random() < 0.05:  # 5% error rate
        return jsonify({'error': 'Internal server error'}), 500
    
    return jsonify({
        'data': f'response_data_{int(time.time())}',
        'timestamp': time.time()
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

# Create requirements.txt
cat > apps/requirements.txt << 'EOF'
Flask==2.3.2
redis==4.5.4
gunicorn==20.1.0
EOF
```

---

## 🏗️ Exercise 1: Production Deployment Patterns

### Task 1.1: Create Production-Ready Dockerfile

Create `apps/Dockerfile`:

```dockerfile
# Multi-stage production build
FROM python:3.11-alpine AS base

# Install security updates
RUN apk update && apk upgrade && apk add --no-cache dumb-init

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

FROM base AS dependencies

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir --require-hashes -r requirements.txt

FROM dependencies AS application

# Copy application with proper ownership
COPY --chown=appuser:appgroup app.py .

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

EXPOSE 5000

# Use init system and production server
ENTRYPOINT ["dumb-init", "--"]
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "app:app"]
```

### Task 1.2: Blue-Green Deployment Script

Create `deployment/blue-green-deploy.sh`:

```bash
#!/bin/bash
set -e

SERVICE_NAME="production-app"
NEW_VERSION=${1:-"latest"}
HEALTH_CHECK_URL="http://localhost:5001/health"

# Get current deployment color
CURRENT_COLOR=$(docker ps --filter "label=color" --format "{{.Label \"color\"}}" | head -1 || echo "blue")
NEW_COLOR=$([ "$CURRENT_COLOR" = "blue" ] && echo "green" || echo "blue")

echo "🚀 Starting Blue-Green deployment"
echo "   Current: $CURRENT_COLOR"
echo "   Deploying: $NEW_COLOR"
echo "   Version: $NEW_VERSION"

# Build new image
docker build -t ${SERVICE_NAME}:${NEW_VERSION} apps/

# Deploy new version
docker run -d \
  --name ${SERVICE_NAME}-${NEW_COLOR} \
  --label color=${NEW_COLOR} \
  --label version=${NEW_VERSION} \
  -p $([ "$NEW_COLOR" = "blue" ] && echo "5001:5000" || echo "5002:5000") \
  -e APP_VERSION=${NEW_VERSION} \
  -e REDIS_HOST=redis \
  --network docker-best-practices-lab_default \
  ${SERVICE_NAME}:${NEW_VERSION}

# Wait for service to be healthy
echo "⏳ Waiting for ${NEW_COLOR} deployment to be healthy..."
for i in {1..30}; do
  if curl -f ${HEALTH_CHECK_URL} >/dev/null 2>&1; then
    echo "✅ ${NEW_COLOR} deployment is healthy"
    break
  fi
  
  if [ $i -eq 30 ]; then
    echo "❌ Health check failed, rolling back"
    docker stop ${SERVICE_NAME}-${NEW_COLOR}
    docker rm ${SERVICE_NAME}-${NEW_COLOR}
    exit 1
  fi
  
  sleep 2
done

# Switch traffic (simulate load balancer update)
echo "🔄 Switching traffic to ${NEW_COLOR}"

# Stop old version
if docker ps -q --filter "name=${SERVICE_NAME}-${CURRENT_COLOR}" | grep -q .; then
  docker stop ${SERVICE_NAME}-${CURRENT_COLOR}
  docker rm ${SERVICE_NAME}-${CURRENT_COLOR}
fi

# Update main service port
docker stop ${SERVICE_NAME}-${NEW_COLOR} 2>/dev/null || true
docker rm ${SERVICE_NAME}-${NEW_COLOR} 2>/dev/null || true

docker run -d \
  --name ${SERVICE_NAME} \
  --label color=${NEW_COLOR} \
  --label version=${NEW_VERSION} \
  -p 5000:5000 \
  -e APP_VERSION=${NEW_VERSION} \
  -e REDIS_HOST=redis \
  --network docker-best-practices-lab_default \
  ${SERVICE_NAME}:${NEW_VERSION}

echo "🎉 Blue-Green deployment completed successfully"
echo "   Active color: ${NEW_COLOR}"
echo "   Version: ${NEW_VERSION}"
```

### Task 1.3: Test Blue-Green Deployment

```bash
# Make script executable
chmod +x deployment/blue-green-deploy.sh

# Start Redis for dependency
docker run -d --name redis --network docker-best-practices-lab_default redis:alpine

# Initial deployment
./deployment/blue-green-deploy.sh v1.0.0

# Test the service
curl http://localhost:5000/
curl http://localhost:5000/health

# Deploy new version
./deployment/blue-green-deploy.sh v1.1.0

# Verify deployment
curl http://localhost:5000/
```

**Questions:**
1. How does blue-green deployment minimize downtime?
2. What happens if the health check fails?
3. How would you implement this with a load balancer?

---

## ⚡ Exercise 2: Performance Optimization

### Task 2.1: Resource-Optimized Deployment

Create `deployment/optimized-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    build: 
      context: ../apps
      dockerfile: Dockerfile
    environment:
      - APP_VERSION=optimized
      - REDIS_HOST=redis
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 128M
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    command: redis-server --maxmemory 128mb --maxmemory-policy allkeys-lru
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.1'
          memory: 64M
    networks:
      - app-network

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ../monitoring/nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - app
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
```

### Task 2.2: Load Testing Script

Create `scripts/load-test.py`:

```python
#!/usr/bin/env python3
import asyncio
import aiohttp
import time
import statistics
from concurrent.futures import ThreadPoolExecutor

class LoadTester:
    def __init__(self, base_url="http://localhost"):
        self.base_url = base_url
        self.results = []
    
    async def make_request(self, session, endpoint="/"):
        start_time = time.time()
        try:
            async with session.get(f"{self.base_url}{endpoint}") as response:
                await response.text()
                response_time = time.time() - start_time
                return {
                    'status': response.status,
                    'response_time': response_time,
                    'success': response.status < 400
                }
        except Exception as e:
            return {
                'status': 0,
                'response_time': time.time() - start_time,
                'success': False,
                'error': str(e)
            }
    
    async def run_load_test(self, concurrent_users=10, duration=60):
        print(f"🔥 Starting load test: {concurrent_users} users, {duration}s duration")
        
        connector = aiohttp.TCPConnector(limit=100)
        async with aiohttp.ClientSession(connector=connector) as session:
            tasks = []
            start_time = time.time()
            
            while time.time() - start_time < duration:
                if len(tasks) < concurrent_users:
                    task = asyncio.create_task(self.make_request(session, "/api/data"))
                    tasks.append(task)
                
                # Collect completed tasks
                done_tasks = [task for task in tasks if task.done()]
                for task in done_tasks:
                    result = await task
                    self.results.append(result)
                    tasks.remove(task)
                
                await asyncio.sleep(0.1)
            
            # Wait for remaining tasks
            if tasks:
                remaining_results = await asyncio.gather(*tasks, return_exceptions=True)
                for result in remaining_results:
                    if isinstance(result, dict):
                        self.results.append(result)
    
    def generate_report(self):
        if not self.results:
            return {"error": "No results to analyze"}
        
        response_times = [r['response_time'] for r in self.results if 'response_time' in r]
        successful_requests = [r for r in self.results if r.get('success', False)]
        failed_requests = [r for r in self.results if not r.get('success', True)]
        
        report = {
            'total_requests': len(self.results),
            'successful_requests': len(successful_requests),
            'failed_requests': len(failed_requests),
            'success_rate': len(successful_requests) / len(self.results) * 100,
            'average_response_time': statistics.mean(response_times) if response_times else 0,
            'median_response_time': statistics.median(response_times) if response_times else 0,
            'p95_response_time': self.percentile(response_times, 95) if response_times else 0,
            'min_response_time': min(response_times) if response_times else 0,
            'max_response_time': max(response_times) if response_times else 0
        }
        
        return report
    
    def percentile(self, data, percentile):
        size = len(data)
        return sorted(data)[int(size * percentile / 100)]
    
    def print_report(self):
        report = self.generate_report()
        
        print("\n📊 Load Test Results:")
        print("=" * 40)
        print(f"Total Requests: {report['total_requests']}")
        print(f"Successful: {report['successful_requests']}")
        print(f"Failed: {report['failed_requests']}")
        print(f"Success Rate: {report['success_rate']:.2f}%")
        print(f"\nResponse Times (ms):")
        print(f"  Average: {report['average_response_time'] * 1000:.2f}")
        print(f"  Median: {report['median_response_time'] * 1000:.2f}")
        print(f"  95th Percentile: {report['p95_response_time'] * 1000:.2f}")
        print(f"  Min: {report['min_response_time'] * 1000:.2f}")
        print(f"  Max: {report['max_response_time'] * 1000:.2f}")

async def main():
    import sys
    
    users = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    duration = int(sys.argv[2]) if len(sys.argv) > 2 else 60
    
    tester = LoadTester()
    await tester.run_load_test(users, duration)
    tester.print_report()

if __name__ == "__main__":
    asyncio.run(main())
```

### Task 2.3: Performance Testing

```bash
# Install dependencies
pip install aiohttp

# Deploy optimized stack
cd deployment
docker-compose -f optimized-compose.yml up -d --scale app=3

# Run load tests
cd ../scripts
python load-test.py 50 120  # 50 users, 2 minutes

# Monitor during load test
docker stats

# Analyze results
docker-compose -f ../deployment/optimized-compose.yml logs app
```

**Analysis Questions:**
1. What was the average response time under load?
2. How did CPU and memory usage change?
3. What optimizations could improve performance?

---

## 📊 Exercise 3: Monitoring & Observability

### Task 3.1: Monitoring Stack Setup

Create `monitoring/docker-compose.monitoring.yml`:

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:

networks:
  monitoring:
    driver: bridge
```

### Task 3.2: Application Metrics

Create `apps/app-with-metrics.py`:

```python
from flask import Flask, jsonify, request
import time
import random
import os
import redis
from prometheus_client import Counter, Histogram, Gauge, generate_latest

app = Flask(__name__)
redis_client = redis.Redis(host=os.getenv('REDIS_HOST', 'localhost'), port=6379, decode_responses=True)

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration')
ACTIVE_CONNECTIONS = Gauge('http_active_connections', 'Active HTTP connections')

@app.before_request
def before_request():
    request.start_time = time.time()
    ACTIVE_CONNECTIONS.inc()

@app.after_request
def after_request(response):
    REQUEST_COUNT.labels(request.method, request.endpoint).inc()
    REQUEST_DURATION.observe(time.time() - request.start_time)
    ACTIVE_CONNECTIONS.dec()
    return response

@app.route('/')
def home():
    return jsonify({
        'message': 'Production Flask App with Metrics',
        'version': os.getenv('APP_VERSION', '1.0.0'),
        'hostname': os.getenv('HOSTNAME', 'unknown')
    })

@app.route('/health')
def health():
    try:
        redis_client.ping()
        return jsonify({'status': 'healthy', 'redis': 'connected'})
    except:
        return jsonify({'status': 'unhealthy', 'redis': 'disconnected'}), 503

@app.route('/api/data')
def get_data():
    # Simulate processing time
    time.sleep(random.uniform(0.1, 0.5))
    
    # Random failure simulation
    if random.random() < 0.05:  # 5% error rate
        return jsonify({'error': 'Internal server error'}), 500
    
    return jsonify({
        'data': f'response_data_{int(time.time())}',
        'timestamp': time.time()
    })

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': 'text/plain'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
```

### Task 3.3: Deploy Full Monitoring

```bash
# Update requirements.txt
echo "prometheus_client==0.17.0" >> apps/requirements.txt

# Replace app.py with metrics version
cp apps/app-with-metrics.py apps/app.py

# Create Prometheus config
cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'app'
    static_configs:
      - targets: ['app:5000']
    scrape_interval: 5s

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
EOF

# Deploy monitoring stack
cd monitoring
docker-compose -f docker-compose.monitoring.yml up -d

# Rebuild and deploy app with metrics
cd ../deployment
docker-compose -f optimized-compose.yml down
docker-compose -f optimized-compose.yml up -d --build

# Generate some traffic
cd ../scripts
python load-test.py 10 60 &

# Access monitoring
echo "📊 Access Prometheus: http://localhost:9090"
echo "📈 Access Grafana: http://localhost:3000 (admin/admin)"
echo "🐳 Access cAdvisor: http://localhost:8080"
```

**Monitoring Tasks:**
1. Create Grafana dashboard for application metrics
2. Set up alerts for high error rates
3. Monitor container resource usage
4. Analyze traffic patterns during load tests

---

## 🔧 Exercise 4: Troubleshooting Workflow

### Task 4.1: Container Diagnostics Script

Create `scripts/diagnose.py`:

```python
#!/usr/bin/env python3
import docker
import subprocess
import json
import time

class ContainerDiagnostics:
    def __init__(self):
        self.client = docker.from_env()
    
    def diagnose_container(self, container_name):
        """Run comprehensive container diagnostics"""
        print(f"🔍 Diagnosing container: {container_name}")
        
        try:
            container = self.client.containers.get(container_name)
            
            # Basic info
            print(f"\n📊 Container Status: {container.status}")
            print(f"🏷️ Image: {container.image.tags[0] if container.image.tags else container.image.id[:12]}")
            
            # Resource usage
            stats = container.stats(stream=False)
            self.print_resource_usage(stats)
            
            # Health check
            health = container.attrs.get('State', {}).get('Health', {})
            if health:
                print(f"\n🏥 Health Status: {health.get('Status', 'N/A')}")
            
            # Recent logs
            print(f"\n📋 Recent Logs (last 10 lines):")
            logs = container.logs(tail=10).decode('utf-8')
            for line in logs.strip().split('\n')[-10:]:
                print(f"  {line}")
            
            # Network info
            self.print_network_info(container)
            
            # Recommendations
            self.generate_recommendations(container, stats)
            
        except docker.errors.NotFound:
            print(f"❌ Container '{container_name}' not found")
        except Exception as e:
            print(f"❌ Error diagnosing container: {e}")
    
    def print_resource_usage(self, stats):
        """Print resource usage statistics"""
        # CPU usage
        cpu_stats = stats['cpu_stats']
        precpu_stats = stats['precpu_stats']
        
        cpu_usage = 0.0
        if 'cpu_usage' in cpu_stats and 'cpu_usage' in precpu_stats:
            cpu_delta = cpu_stats['cpu_usage']['total_usage'] - precpu_stats['cpu_usage']['total_usage']
            system_delta = cpu_stats['system_cpu_usage'] - precpu_stats['system_cpu_usage']
            if system_delta > 0:
                cpu_usage = (cpu_delta / system_delta) * len(cpu_stats['cpu_usage']['percpu_usage']) * 100
        
        # Memory usage
        memory_stats = stats['memory_stats']
        memory_usage = memory_stats.get('usage', 0)
        memory_limit = memory_stats.get('limit', 0)
        memory_percent = (memory_usage / memory_limit) * 100 if memory_limit > 0 else 0
        
        print(f"\n⚡ Resource Usage:")
        print(f"  CPU: {cpu_usage:.2f}%")
        print(f"  Memory: {memory_usage / 1024 / 1024:.1f}MB / {memory_limit / 1024 / 1024:.1f}MB ({memory_percent:.1f}%)")
    
    def print_network_info(self, container):
        """Print network information"""
        networks = container.attrs['NetworkSettings']['Networks']
        print(f"\n🌐 Network Information:")
        for network_name, network_info in networks.items():
            print(f"  Network: {network_name}")
            print(f"  IP: {network_info.get('IPAddress', 'N/A')}")
    
    def generate_recommendations(self, container, stats):
        """Generate performance recommendations"""
        recommendations = []
        
        # Check resource usage
        memory_stats = stats['memory_stats']
        memory_usage = memory_stats.get('usage', 0)
        memory_limit = memory_stats.get('limit', 0)
        memory_percent = (memory_usage / memory_limit) * 100 if memory_limit > 0 else 0
        
        if memory_percent > 90:
            recommendations.append("⚠️ High memory usage - consider increasing memory limit")
        
        # Check restart count
        restart_count = container.attrs['RestartCount']
        if restart_count > 5:
            recommendations.append(f"⚠️ Container has restarted {restart_count} times - check logs for errors")
        
        # Check health status
        health = container.attrs.get('State', {}).get('Health', {})
        if health.get('Status') == 'unhealthy':
            recommendations.append("❌ Container is unhealthy - check health check configuration")
        
        if recommendations:
            print(f"\n💡 Recommendations:")
            for rec in recommendations:
                print(f"  {rec}")
        else:
            print(f"\n✅ No issues detected")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) != 2:
        print("Usage: python diagnose.py <container_name>")
        sys.exit(1)
    
    diagnostics = ContainerDiagnostics()
    diagnostics.diagnose_container(sys.argv[1])
```

### Task 4.2: Run Diagnostics

```bash
# Make script executable
chmod +x scripts/diagnose.py

# Run diagnostics on your containers
python scripts/diagnose.py deployment_app_1
python scripts/diagnose.py deployment_redis_1

# Test with a problematic container
docker run -d --name memory-hog --memory=100m busybox sh -c "dd if=/dev/zero of=/tmp/bigfile bs=1M count=200"
sleep 5
python scripts/diagnose.py memory-hog
```

---

## 🎯 Lab Assessment

### Completion Checklist

- [ ] **Production Deployment**: Implemented blue-green deployment pattern
- [ ] **Performance**: Optimized resource usage and conducted load testing
- [ ] **Monitoring**: Set up comprehensive monitoring with Prometheus/Grafana
- [ ] **Troubleshooting**: Created diagnostic tools and workflows
- [ ] **Best Practices**: Applied 12-factor methodology and operational excellence

### Performance Metrics

**Deployment Speed:**
- Blue-green deployment time: ___ seconds
- Rollback time: ___ seconds
- Zero-downtime achieved: Yes/No

**Performance Results:**
- Average response time: ___ ms
- 95th percentile: ___ ms
- Success rate: ___%
- Max concurrent users handled: ___

**Monitoring Coverage:**
- Application metrics: ✅/❌
- Infrastructure metrics: ✅/❌
- Custom dashboards: ✅/❌
- Alerting rules: ✅/❌

---

## 🔧 Troubleshooting Common Issues

### Issue: High Memory Usage
```bash
# Check memory usage patterns
docker stats --no-stream

# Analyze memory leaks
python scripts/diagnose.py <container_name>

# Optimize memory limits
docker update --memory=512m <container_name>
```

### Issue: Slow Deployments
```bash
# Optimize image layers
docker history production-app:latest

# Check network latency
docker exec <container> ping -c 5 <target>

# Monitor deployment progress
docker events --filter container=<container_name>
```

---

## 🏆 Advanced Challenges

### Challenge 1: Auto-Scaling Implementation
Implement container auto-scaling based on CPU/memory metrics.

### Challenge 2: Circuit Breaker Pattern
Add circuit breaker functionality to handle service failures gracefully.

### Challenge 3: Distributed Tracing
Implement OpenTelemetry tracing across multiple services.

---

## 📚 Key Takeaways

✅ **Production Patterns**: Blue-green deployments minimize risk and downtime  
✅ **Performance**: Resource optimization and load testing are essential  
✅ **Monitoring**: Comprehensive observability enables proactive operations  
✅ **Troubleshooting**: Systematic debugging saves time and reduces MTTR  
✅ **Best Practices**: Following proven patterns ensures reliability and scalability  

---

**🎉 Congratulations!** You've implemented enterprise-grade Docker best practices for production environments.

**[⬅️ Back to Chapter 09](../README.md)** | **[Next: Checkpoint ➡️](../checkpoint.md)** 