# 🚀 Chapter 09: Docker Best Practices - Production Excellence

Welcome to Docker production mastery! In this chapter, you'll learn enterprise-grade best practices, performance optimization, troubleshooting methodologies, and operational excellence patterns used by leading technology companies.

## 🎯 Learning Objectives

By the end of this chapter, you will:
- ✅ Implement production-ready deployment patterns
- ✅ Optimize Docker performance for enterprise workloads
- ✅ Master troubleshooting and debugging techniques
- ✅ Establish operational excellence practices
- ✅ Design scalable container architectures
- ✅ Implement comprehensive monitoring and observability

## 🏗️ Production Deployment Patterns

### 1. The Twelve-Factor App Methodology

#### I. Codebase
```dockerfile
# ✅ One codebase tracked in revision control
FROM node:18-alpine AS base

# Version control integration
ARG GIT_COMMIT
ARG BUILD_DATE
ARG VERSION

LABEL org.opencontainers.image.revision=${GIT_COMMIT} \
      org.opencontainers.image.created=${BUILD_DATE} \
      org.opencontainers.image.version=${VERSION}

WORKDIR /app
```

#### II. Dependencies
```dockerfile
# ✅ Explicitly declare and isolate dependencies
FROM base AS dependencies

# Lock dependencies with specific versions
COPY package-lock.json package.json ./
RUN npm ci --only=production && npm cache clean --force

# Verify integrity
RUN npm audit --audit-level high
```

#### III. Config
```dockerfile
# ✅ Store config in the environment
FROM dependencies AS application

# Configuration via environment variables
ENV NODE_ENV=production \
    PORT=3000 \
    LOG_LEVEL=info

# No hardcoded config in image
COPY src/ ./src/
```

#### IV. Backing Services
```yaml
# ✅ Treat backing services as attached resources
version: '3.8'

services:
  app:
    image: myapp:${VERSION}
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - QUEUE_URL=${QUEUE_URL}
    depends_on:
      - database
      - redis
      - queue

  database:
    image: postgres:15
    environment:
      - POSTGRES_DB=${DB_NAME}
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
```

### 2. Immutable Infrastructure Pattern

```dockerfile
# ✅ Immutable container pattern
FROM node:18-alpine AS production

# Copy everything needed at build time
COPY --from=dependencies /app/node_modules ./node_modules
COPY --from=application /app/src ./src
COPY --from=application /app/package.json ./

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S appuser -u 1001 -G nodejs

# Set ownership and permissions
RUN chown -R appuser:nodejs /app
USER appuser

# Read-only filesystem
VOLUME ["/tmp"]

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js

EXPOSE 3000
CMD ["node", "src/server.js"]
```

### 3. Progressive Deployment Strategies

#### Blue-Green Deployment
```bash
#!/bin/bash
# blue-green-deploy.sh

set -e

SERVICE_NAME="myapp"
NEW_VERSION=$1
CURRENT_COLOR=$(docker service inspect ${SERVICE_NAME} --format '{{.Spec.Labels.color}}' 2>/dev/null || echo "blue")
NEW_COLOR=$([ "$CURRENT_COLOR" = "blue" ] && echo "green" || echo "blue")

echo "🚀 Deploying ${SERVICE_NAME}:${NEW_VERSION} as ${NEW_COLOR}"

# Deploy new version
docker service create \
  --name ${SERVICE_NAME}-${NEW_COLOR} \
  --label color=${NEW_COLOR} \
  --label version=${NEW_VERSION} \
  --replicas 3 \
  --update-config delay=10s,parallelism=1,failure-action=rollback \
  --rollback-config parallelism=1,failure-action=pause \
  --health-cmd "curl -f http://localhost:3000/health" \
  --health-interval 30s \
  --health-retries 3 \
  --health-timeout 10s \
  ${SERVICE_NAME}:${NEW_VERSION}

# Wait for service to be healthy
echo "⏳ Waiting for ${NEW_COLOR} deployment to be healthy..."
while [ "$(docker service inspect ${SERVICE_NAME}-${NEW_COLOR} --format '{{.ServiceStatus.RunningTasks}}')" != "3" ]; do
  sleep 5
done

# Health check
echo "🔍 Performing health checks..."
sleep 30

HEALTHY_TASKS=$(docker service ps ${SERVICE_NAME}-${NEW_COLOR} --filter desired-state=running --format '{{.CurrentState}}' | grep -c Running || true)

if [ "$HEALTHY_TASKS" -eq 3 ]; then
  echo "✅ ${NEW_COLOR} deployment healthy, switching traffic"
  
  # Update load balancer to point to new version
  docker service update \
    --label-add active=true \
    ${SERVICE_NAME}-${NEW_COLOR}
  
  # Remove old version
  if docker service inspect ${SERVICE_NAME}-${CURRENT_COLOR} >/dev/null 2>&1; then
    docker service rm ${SERVICE_NAME}-${CURRENT_COLOR}
  fi
  
  # Update service alias
  docker service update \
    --label-rm active \
    --publish-rm 80:3000 \
    --publish-add 80:3000 \
    ${SERVICE_NAME}-${NEW_COLOR}
  
  echo "🎉 Blue-green deployment completed successfully"
else
  echo "❌ Health check failed, rolling back"
  docker service rm ${SERVICE_NAME}-${NEW_COLOR}
  exit 1
fi
```

#### Canary Deployment
```python
#!/usr/bin/env python3
# canary-deploy.py

import docker
import time
import requests
import sys
from typing import Dict, List

class CanaryDeployment:
    def __init__(self, service_name: str, new_image: str):
        self.client = docker.from_env()
        self.service_name = service_name
        self.new_image = new_image
        self.canary_percentage = 10  # Start with 10% traffic
        
    def deploy_canary(self) -> bool:
        """Deploy canary version"""
        try:
            canary_name = f"{self.service_name}-canary"
            
            # Create canary service with limited replicas
            canary_service = self.client.services.create(
                image=self.new_image,
                name=canary_name,
                labels={
                    'version': 'canary',
                    'traffic_percentage': str(self.canary_percentage)
                },
                mode={'Replicated': {'Replicas': 1}},
                endpoint_spec={
                    'Ports': [{'Protocol': 'tcp', 'TargetPort': 3000, 'PublishedPort': 3001}]
                }
            )
            
            print(f"🐤 Canary deployed: {canary_name}")
            return True
            
        except Exception as e:
            print(f"❌ Canary deployment failed: {e}")
            return False
    
    def run_canary_tests(self) -> Dict:
        """Run tests against canary version"""
        test_results = {
            'health_check': False,
            'performance_test': False,
            'error_rate': 0.0,
            'response_time': 0.0
        }
        
        canary_url = "http://localhost:3001"
        
        try:
            # Health check
            health_response = requests.get(f"{canary_url}/health", timeout=10)
            test_results['health_check'] = health_response.status_code == 200
            
            # Performance test
            response_times = []
            errors = 0
            
            for i in range(100):
                try:
                    start_time = time.time()
                    response = requests.get(f"{canary_url}/api/test", timeout=5)
                    response_time = time.time() - start_time
                    response_times.append(response_time)
                    
                    if response.status_code >= 400:
                        errors += 1
                        
                except Exception:
                    errors += 1
            
            test_results['error_rate'] = (errors / 100) * 100
            test_results['response_time'] = sum(response_times) / len(response_times) if response_times else 0
            test_results['performance_test'] = test_results['error_rate'] < 5 and test_results['response_time'] < 1.0
            
        except Exception as e:
            print(f"⚠️ Canary testing failed: {e}")
        
        return test_results
    
    def promote_or_rollback(self, test_results: Dict) -> bool:
        """Decide whether to promote canary or rollback"""
        if (test_results['health_check'] and 
            test_results['performance_test'] and 
            test_results['error_rate'] < 2.0):
            
            return self.promote_canary()
        else:
            return self.rollback_canary()
    
    def promote_canary(self) -> bool:
        """Promote canary to full deployment"""
        try:
            # Update main service to new image
            main_service = self.client.services.get(self.service_name)
            main_service.update(image=self.new_image)
            
            # Remove canary service
            canary_service = self.client.services.get(f"{self.service_name}-canary")
            canary_service.remove()
            
            print("🎉 Canary promoted to production")
            return True
            
        except Exception as e:
            print(f"❌ Canary promotion failed: {e}")
            return False
    
    def rollback_canary(self) -> bool:
        """Rollback canary deployment"""
        try:
            canary_service = self.client.services.get(f"{self.service_name}-canary")
            canary_service.remove()
            
            print("🔄 Canary rolled back")
            return True
            
        except Exception as e:
            print(f"❌ Canary rollback failed: {e}")
            return False

def main():
    if len(sys.argv) != 3:
        print("Usage: python canary-deploy.py <service_name> <new_image>")
        sys.exit(1)
    
    service_name = sys.argv[1]
    new_image = sys.argv[2]
    
    canary = CanaryDeployment(service_name, new_image)
    
    # Deploy canary
    if not canary.deploy_canary():
        sys.exit(1)
    
    # Wait for startup
    time.sleep(30)
    
    # Run tests
    print("🧪 Running canary tests...")
    test_results = canary.run_canary_tests()
    
    print(f"📊 Test Results:")
    print(f"  Health Check: {'✅' if test_results['health_check'] else '❌'}")
    print(f"  Performance: {'✅' if test_results['performance_test'] else '❌'}")
    print(f"  Error Rate: {test_results['error_rate']:.2f}%")
    print(f"  Response Time: {test_results['response_time']:.3f}s")
    
    # Promote or rollback
    success = canary.promote_or_rollback(test_results)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
```

## ⚡ Performance Optimization

### 1. Resource Management

#### CPU Optimization
```yaml
# CPU-optimized deployment
version: '3.8'

services:
  web:
    image: myapp:latest
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
      placement:
        constraints:
          - node.role == worker
          - node.labels.cpu_type == high_performance
    environment:
      # Optimize Node.js for container
      - NODE_OPTIONS=--max-old-space-size=768
      - UV_THREADPOOL_SIZE=4
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
```

#### Memory Management
```dockerfile
# Memory-optimized container
FROM node:18-alpine AS production

# Set memory limits for Node.js
ENV NODE_OPTIONS="--max-old-space-size=512 --max-semi-space-size=64"

# Optimize garbage collection
ENV V8_FLAGS="--gc-interval=100 --optimize-for-size"

# Copy application
COPY --from=build /app .

# Health check with memory monitoring
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "
        const used = process.memoryUsage();
        const total = parseInt(process.env.MEMORY_LIMIT || '536870912');
        if (used.heapUsed > total * 0.9) process.exit(1);
        require('http').get('http://localhost:3000/health', (res) => {
            process.exit(res.statusCode === 200 ? 0 : 1);
        });
    "

CMD ["node", "server.js"]
```

### 2. Caching Strategies

#### Multi-layer Caching
```python
#!/usr/bin/env python3
# cache-optimizer.py

import redis
import memcache
import time
from typing import Optional, Any
import json
import hashlib

class MultiLayerCache:
    def __init__(self):
        # L1: In-memory cache (fastest)
        self.memory_cache = {}
        self.memory_ttl = {}
        
        # L2: Redis cache (fast, shared)
        self.redis_client = redis.Redis(
            host='redis',
            port=6379,
            decode_responses=True,
            socket_connect_timeout=5,
            socket_timeout=5,
            retry_on_timeout=True
        )
        
        # L3: Memcached (distributed)
        self.memcached_client = memcache.Client(['memcached:11211'])
        
    def _generate_key(self, key: str, params: dict = None) -> str:
        """Generate cache key with parameters"""
        if params:
            key_data = f"{key}:{json.dumps(params, sort_keys=True)}"
            return hashlib.md5(key_data.encode()).hexdigest()
        return key
    
    def get(self, key: str, params: dict = None) -> Optional[Any]:
        """Get value from multi-layer cache"""
        cache_key = self._generate_key(key, params)
        
        # L1: Check memory cache
        if cache_key in self.memory_cache:
            if time.time() < self.memory_ttl.get(cache_key, 0):
                return self.memory_cache[cache_key]
            else:
                # Expired, remove from memory
                del self.memory_cache[cache_key]
                del self.memory_ttl[cache_key]
        
        # L2: Check Redis
        try:
            redis_value = self.redis_client.get(cache_key)
            if redis_value:
                value = json.loads(redis_value)
                # Store in L1 for faster access
                self.memory_cache[cache_key] = value
                self.memory_ttl[cache_key] = time.time() + 300  # 5 min TTL
                return value
        except Exception as e:
            print(f"Redis error: {e}")
        
        # L3: Check Memcached
        try:
            memcached_value = self.memcached_client.get(cache_key)
            if memcached_value:
                # Store in L2 and L1
                self.redis_client.setex(cache_key, 3600, json.dumps(memcached_value))
                self.memory_cache[cache_key] = memcached_value
                self.memory_ttl[cache_key] = time.time() + 300
                return memcached_value
        except Exception as e:
            print(f"Memcached error: {e}")
        
        return None
    
    def set(self, key: str, value: Any, ttl: int = 3600, params: dict = None):
        """Set value in all cache layers"""
        cache_key = self._generate_key(key, params)
        
        # Store in all layers
        try:
            # L1: Memory (short TTL)
            self.memory_cache[cache_key] = value
            self.memory_ttl[cache_key] = time.time() + min(ttl, 300)
            
            # L2: Redis (medium TTL)
            self.redis_client.setex(cache_key, ttl, json.dumps(value))
            
            # L3: Memcached (long TTL)
            self.memcached_client.set(cache_key, value, time=ttl * 2)
            
        except Exception as e:
            print(f"Cache write error: {e}")
    
    def invalidate(self, key: str, params: dict = None):
        """Invalidate cache entry from all layers"""
        cache_key = self._generate_key(key, params)
        
        # Remove from all layers
        if cache_key in self.memory_cache:
            del self.memory_cache[cache_key]
            del self.memory_ttl[cache_key]
        
        try:
            self.redis_client.delete(cache_key)
            self.memcached_client.delete(cache_key)
        except Exception as e:
            print(f"Cache invalidation error: {e}")

# Flask application with caching
from flask import Flask, request, jsonify
import time

app = Flask(__name__)
cache = MultiLayerCache()

@app.route('/api/data/<data_id>')
def get_data(data_id):
    # Check cache first
    cached_data = cache.get(f"data:{data_id}")
    if cached_data:
        return jsonify({
            'data': cached_data,
            'cached': True,
            'timestamp': time.time()
        })
    
    # Simulate expensive operation
    time.sleep(0.1)
    data = {
        'id': data_id,
        'value': f"computed_value_{data_id}",
        'computed_at': time.time()
    }
    
    # Cache the result
    cache.set(f"data:{data_id}", data, ttl=3600)
    
    return jsonify({
        'data': data,
        'cached': False,
        'timestamp': time.time()
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

### 3. Database Connection Pooling

```python
#!/usr/bin/env python3
# db-pool-manager.py

import asyncio
import asyncpg
import aioredis
from contextlib import asynccontextmanager
import os
from typing import Optional
import logging

class DatabasePoolManager:
    def __init__(self):
        self.pg_pool: Optional[asyncpg.Pool] = None
        self.redis_pool: Optional[aioredis.ConnectionPool] = None
        self.logger = logging.getLogger(__name__)
        
    async def initialize_pools(self):
        """Initialize connection pools"""
        # PostgreSQL pool
        self.pg_pool = await asyncpg.create_pool(
            dsn=os.getenv('DATABASE_URL'),
            min_size=5,
            max_size=20,
            command_timeout=30,
            server_settings={
                'application_name': 'myapp',
                'tcp_keepalives_idle': '600',
                'tcp_keepalives_interval': '30',
                'tcp_keepalives_count': '3',
            }
        )
        
        # Redis pool
        self.redis_pool = aioredis.ConnectionPool.from_url(
            os.getenv('REDIS_URL'),
            max_connections=10,
            retry_on_timeout=True,
            socket_keepalive=True,
            socket_keepalive_options={
                'TCP_KEEPIDLE': 60,
                'TCP_KEEPINTVL': 10,
                'TCP_KEEPCNT': 3
            }
        )
        
        self.logger.info("Database pools initialized")
    
    @asynccontextmanager
    async def get_pg_connection(self):
        """Get PostgreSQL connection from pool"""
        async with self.pg_pool.acquire() as connection:
            try:
                yield connection
            except Exception as e:
                self.logger.error(f"Database error: {e}")
                raise
    
    @asynccontextmanager
    async def get_redis_connection(self):
        """Get Redis connection from pool"""
        redis = aioredis.Redis(connection_pool=self.redis_pool)
        try:
            yield redis
        except Exception as e:
            self.logger.error(f"Redis error: {e}")
            raise
        finally:
            await redis.close()
    
    async def health_check(self) -> dict:
        """Check pool health"""
        health = {
            'postgres': {'status': 'unknown', 'pool_size': 0, 'free_size': 0},
            'redis': {'status': 'unknown', 'connections': 0}
        }
        
        # Check PostgreSQL
        try:
            async with self.get_pg_connection() as conn:
                await conn.fetchval('SELECT 1')
                health['postgres']['status'] = 'healthy'
                health['postgres']['pool_size'] = self.pg_pool.get_size()
                health['postgres']['free_size'] = self.pg_pool.get_size() - self.pg_pool.get_busy_size()
        except Exception as e:
            health['postgres']['status'] = f'error: {e}'
        
        # Check Redis
        try:
            async with self.get_redis_connection() as redis:
                await redis.ping()
                health['redis']['status'] = 'healthy'
                health['redis']['connections'] = len(self.redis_pool._available_connections)
        except Exception as e:
            health['redis']['status'] = f'error: {e}'
        
        return health
    
    async def close_pools(self):
        """Close all connection pools"""
        if self.pg_pool:
            await self.pg_pool.close()
        if self.redis_pool:
            await self.redis_pool.disconnect()
        
        self.logger.info("Database pools closed")

# FastAPI application with connection pooling
from fastapi import FastAPI, HTTPException
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    app.state.db = DatabasePoolManager()
    await app.state.db.initialize_pools()
    yield
    # Shutdown
    await app.state.db.close_pools()

app = FastAPI(lifespan=lifespan)

@app.get("/api/users/{user_id}")
async def get_user(user_id: int):
    async with app.state.db.get_pg_connection() as conn:
        user = await conn.fetchrow(
            "SELECT id, name, email FROM users WHERE id = $1",
            user_id
        )
        
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        return dict(user)

@app.get("/api/cache/{key}")
async def get_cached_value(key: str):
    async with app.state.db.get_redis_connection() as redis:
        value = await redis.get(key)
        
        if not value:
            raise HTTPException(status_code=404, detail="Key not found")
        
        return {"key": key, "value": value}

@app.get("/health")
async def health_check():
    return await app.state.db.health_check()
```

## 🔧 Troubleshooting & Debugging

### 1. Debugging Tools & Techniques

#### Container Debugging Toolkit
```dockerfile
# Debug-enabled image
FROM node:18-alpine AS debug

# Install debugging tools
RUN apk add --no-cache \
    htop \
    curl \
    netstat-nat \
    tcpdump \
    strace \
    gdb \
    valgrind

# Install Node.js debugging tools
RUN npm install -g clinic doctor clinic bubbleprof

# Copy application
COPY . .

# Debug-friendly configuration
ENV NODE_ENV=development \
    DEBUG=* \
    NODE_OPTIONS="--inspect=0.0.0.0:9229"

EXPOSE 3000 9229

CMD ["node", "--inspect=0.0.0.0:9229", "server.js"]
```

#### Performance Debugging Script
```python
#!/usr/bin/env python3
# container-diagnostics.py

import docker
import psutil
import json
import time
from datetime import datetime
from typing import Dict, List

class ContainerDiagnostics:
    def __init__(self):
        self.client = docker.from_env()
        
    def get_container_stats(self, container_name: str) -> Dict:
        """Get real-time container statistics"""
        try:
            container = self.client.containers.get(container_name)
            stats = container.stats(stream=False)
            
            # CPU usage calculation
            cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - \
                       stats['precpu_stats']['cpu_usage']['total_usage']
            system_delta = stats['cpu_stats']['system_cpu_usage'] - \
                          stats['precpu_stats']['system_cpu_usage']
            
            cpu_percent = 0.0
            if system_delta > 0 and cpu_delta > 0:
                cpu_percent = (cpu_delta / system_delta) * len(stats['cpu_stats']['cpu_usage']['percpu_usage']) * 100
            
            # Memory usage
            memory_usage = stats['memory_stats']['usage']
            memory_limit = stats['memory_stats']['limit']
            memory_percent = (memory_usage / memory_limit) * 100
            
            # Network I/O
            network_io = stats['networks']
            total_rx = sum(net['rx_bytes'] for net in network_io.values())
            total_tx = sum(net['tx_bytes'] for net in network_io.values())
            
            # Block I/O
            block_io = stats['blkio_stats']['io_service_bytes_recursive']
            read_bytes = sum(item['value'] for item in block_io if item['op'] == 'Read')
            write_bytes = sum(item['value'] for item in block_io if item['op'] == 'Write')
            
            return {
                'timestamp': datetime.now().isoformat(),
                'container': container_name,
                'cpu_percent': round(cpu_percent, 2),
                'memory_usage_mb': round(memory_usage / 1024 / 1024, 2),
                'memory_limit_mb': round(memory_limit / 1024 / 1024, 2),
                'memory_percent': round(memory_percent, 2),
                'network_rx_mb': round(total_rx / 1024 / 1024, 2),
                'network_tx_mb': round(total_tx / 1024 / 1024, 2),
                'disk_read_mb': round(read_bytes / 1024 / 1024, 2),
                'disk_write_mb': round(write_bytes / 1024 / 1024, 2)
            }
            
        except Exception as e:
            return {'error': str(e)}
    
    def diagnose_performance_issues(self, container_name: str) -> Dict:
        """Diagnose common performance issues"""
        issues = []
        recommendations = []
        
        try:
            container = self.client.containers.get(container_name)
            stats = self.get_container_stats(container_name)
            
            if 'error' in stats:
                return {'error': stats['error']}
            
            # High CPU usage
            if stats['cpu_percent'] > 80:
                issues.append(f"High CPU usage: {stats['cpu_percent']}%")
                recommendations.append("Consider scaling horizontally or optimizing CPU-intensive operations")
            
            # High memory usage
            if stats['memory_percent'] > 90:
                issues.append(f"High memory usage: {stats['memory_percent']}%")
                recommendations.append("Increase memory limit or optimize memory usage")
            
            # Memory leak detection
            if stats['memory_percent'] > 85:
                recommendations.append("Monitor for memory leaks over time")
            
            # High disk I/O
            if stats['disk_read_mb'] + stats['disk_write_mb'] > 100:
                issues.append(f"High disk I/O: {stats['disk_read_mb'] + stats['disk_write_mb']} MB/s")
                recommendations.append("Optimize database queries or implement caching")
            
            # Container configuration analysis
            config = container.attrs['Config']
            host_config = container.attrs['HostConfig']
            
            # Check resource limits
            if not host_config.get('Memory'):
                issues.append("No memory limit set")
                recommendations.append("Set appropriate memory limits to prevent OOM kills")
            
            if not host_config.get('CpuQuota'):
                issues.append("No CPU limit set")
                recommendations.append("Set CPU limits for better resource management")
            
            # Check health check
            if not config.get('Healthcheck'):
                issues.append("No health check configured")
                recommendations.append("Add health check for better monitoring")
            
            return {
                'container': container_name,
                'stats': stats,
                'issues': issues,
                'recommendations': recommendations,
                'severity': 'HIGH' if len(issues) > 3 else 'MEDIUM' if len(issues) > 1 else 'LOW'
            }
            
        except Exception as e:
            return {'error': str(e)}
    
    def continuous_monitoring(self, container_name: str, duration: int = 300):
        """Monitor container performance over time"""
        print(f"🔍 Monitoring {container_name} for {duration} seconds...")
        
        metrics_history = []
        start_time = time.time()
        
        while time.time() - start_time < duration:
            stats = self.get_container_stats(container_name)
            if 'error' not in stats:
                metrics_history.append(stats)
                
                # Real-time alerts
                if stats['cpu_percent'] > 90:
                    print(f"⚠️ HIGH CPU: {stats['cpu_percent']}%")
                if stats['memory_percent'] > 95:
                    print(f"🚨 CRITICAL MEMORY: {stats['memory_percent']}%")
            
            time.sleep(10)
        
        # Generate summary report
        if metrics_history:
            avg_cpu = sum(m['cpu_percent'] for m in metrics_history) / len(metrics_history)
            avg_memory = sum(m['memory_percent'] for m in metrics_history) / len(metrics_history)
            max_cpu = max(m['cpu_percent'] for m in metrics_history)
            max_memory = max(m['memory_percent'] for m in metrics_history)
            
            report = {
                'container': container_name,
                'duration_seconds': duration,
                'samples': len(metrics_history),
                'average_cpu_percent': round(avg_cpu, 2),
                'average_memory_percent': round(avg_memory, 2),
                'max_cpu_percent': max_cpu,
                'max_memory_percent': max_memory,
                'metrics_history': metrics_history
            }
            
            # Save report
            with open(f'performance-report-{container_name}-{int(time.time())}.json', 'w') as f:
                json.dump(report, f, indent=2)
            
            print(f"📊 Performance Report:")
            print(f"  Average CPU: {avg_cpu:.1f}%")
            print(f"  Average Memory: {avg_memory:.1f}%")
            print(f"  Peak CPU: {max_cpu:.1f}%")
            print(f"  Peak Memory: {max_memory:.1f}%")
            
            return report
        
        return {'error': 'No metrics collected'}

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python container-diagnostics.py <container_name> [duration]")
        sys.exit(1)
    
    container_name = sys.argv[1]
    duration = int(sys.argv[2]) if len(sys.argv) > 2 else 60
    
    diagnostics = ContainerDiagnostics()
    
    # Quick diagnosis
    print("🔧 Running performance diagnosis...")
    diagnosis = diagnostics.diagnose_performance_issues(container_name)
    
    if 'error' in diagnosis:
        print(f"❌ Error: {diagnosis['error']}")
        sys.exit(1)
    
    print(f"📋 Issues found: {len(diagnosis['issues'])}")
    for issue in diagnosis['issues']:
        print(f"  ⚠️ {issue}")
    
    print(f"💡 Recommendations:")
    for rec in diagnosis['recommendations']:
        print(f"  • {rec}")
    
    # Continuous monitoring
    if duration > 0:
        diagnostics.continuous_monitoring(container_name, duration)


### 2. Common Issues & Solutions

#### Container Won't Start
```bash
#!/bin/bash
# container-startup-debug.sh

CONTAINER_NAME=$1

echo "🔍 Debugging container startup issues for: $CONTAINER_NAME"

# Check if container exists
if ! docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container $CONTAINER_NAME not found"
    exit 1
fi

# Get container status
STATUS=$(docker inspect $CONTAINER_NAME --format '{{.State.Status}}')
echo "📊 Container Status: $STATUS"

# If exited, check exit code and logs
if [ "$STATUS" = "exited" ]; then
    EXIT_CODE=$(docker inspect $CONTAINER_NAME --format '{{.State.ExitCode}}')
    echo "🚪 Exit Code: $EXIT_CODE"
    
    case $EXIT_CODE in
        125) echo "💡 Error: Docker daemon error or container command issue" ;;
        126) echo "💡 Error: Container command not executable" ;;
        127) echo "💡 Error: Container command not found" ;;
        *) echo "💡 Application-specific exit code" ;;
    esac
    
    echo "📋 Recent logs:"
    docker logs --tail 50 $CONTAINER_NAME
fi

# Check resource constraints
echo "🔧 Checking resource configuration..."
MEMORY_LIMIT=$(docker inspect $CONTAINER_NAME --format '{{.HostConfig.Memory}}')
CPU_LIMIT=$(docker inspect $CONTAINER_NAME --format '{{.HostConfig.CpuQuota}}')

if [ "$MEMORY_LIMIT" != "0" ]; then
    echo "💾 Memory Limit: $(($MEMORY_LIMIT / 1024 / 1024)) MB"
fi

if [ "$CPU_LIMIT" != "0" ]; then
    echo "⚡ CPU Limit: $CPU_LIMIT"
fi

# Check health status
HEALTH_STATUS=$(docker inspect $CONTAINER_NAME --format '{{.State.Health.Status}}' 2>/dev/null || echo "no healthcheck")
echo "🏥 Health Status: $HEALTH_STATUS"

if [ "$HEALTH_STATUS" = "unhealthy" ]; then
    echo "🏥 Health Check Logs:"
    docker inspect $CONTAINER_NAME --format '{{range .State.Health.Log}}{{.Output}}{{end}}'
fi

# Check network connectivity
echo "🌐 Checking network configuration..."
NETWORKS=$(docker inspect $CONTAINER_NAME --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}')
echo "📡 Networks: $NETWORKS"

# Port bindings
PORTS=$(docker inspect $CONTAINER_NAME --format '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostPort}} {{end}}')
if [ -n "$PORTS" ]; then
    echo "🔌 Port Mappings: $PORTS"
fi

# Volume mounts
echo "💽 Volume Mounts:"
docker inspect $CONTAINER_NAME --format '{{range .Mounts}}{{.Source}} -> {{.Destination}} ({{.Type}}){{println}}{{end}}'

# Environment variables (redacted)
echo "🌍 Environment Variables:"
docker inspect $CONTAINER_NAME --format '{{range .Config.Env}}{{println "  " .}}{{end}}' | head -10

echo "🔧 Troubleshooting complete"
```

#### High Memory Usage
```python
#!/usr/bin/env python3
# memory-analyzer.py

import docker
import json
import time
from collections import defaultdict

class MemoryAnalyzer:
    def __init__(self):
        self.client = docker.from_env()
    
    def analyze_memory_usage(self, container_name: str):
        """Analyze memory usage patterns"""
        container = self.client.containers.get(container_name)
        
        # Get memory stats
        stats = container.stats(stream=False)
        memory_stats = stats['memory_stats']
        
        usage = memory_stats['usage']
        limit = memory_stats['limit']
        cache = memory_stats.get('stats', {}).get('cache', 0)
        rss = memory_stats.get('stats', {}).get('rss', 0)
        
        # Calculate percentages
        usage_percent = (usage / limit) * 100
        cache_percent = (cache / usage) * 100 if usage > 0 else 0
        rss_percent = (rss / usage) * 100 if usage > 0 else 0
        
        analysis = {
            'container': container_name,
            'memory_usage_mb': round(usage / 1024 / 1024, 2),
            'memory_limit_mb': round(limit / 1024 / 1024, 2),
            'usage_percent': round(usage_percent, 2),
            'cache_mb': round(cache / 1024 / 1024, 2),
            'cache_percent': round(cache_percent, 2),
            'rss_mb': round(rss / 1024 / 1024, 2),
            'rss_percent': round(rss_percent, 2),
            'recommendations': []
        }
        
        # Generate recommendations
        if usage_percent > 90:
            analysis['recommendations'].append("CRITICAL: Memory usage above 90%")
        elif usage_percent > 80:
            analysis['recommendations'].append("WARNING: Memory usage above 80%")
        
        if cache_percent < 20:
            analysis['recommendations'].append("Low cache usage - consider optimizing caching")
        
        if rss_percent > 70:
            analysis['recommendations'].append("High RSS usage - possible memory leak")
        
        return analysis
    
    def memory_leak_detection(self, container_name: str, duration: int = 300):
        """Detect potential memory leaks"""
        print(f"🔍 Monitoring {container_name} for memory leaks ({duration}s)...")
        
        measurements = []
        start_time = time.time()
        
        while time.time() - start_time < duration:
            analysis = self.analyze_memory_usage(container_name)
            measurements.append({
                'timestamp': time.time(),
                'usage_mb': analysis['memory_usage_mb'],
                'usage_percent': analysis['usage_percent']
            })
            
            print(f"Memory: {analysis['memory_usage_mb']} MB ({analysis['usage_percent']:.1f}%)")
            time.sleep(30)
        
        # Analyze trend
        if len(measurements) >= 3:
            start_usage = measurements[0]['usage_mb']
            end_usage = measurements[-1]['usage_mb']
            growth_rate = (end_usage - start_usage) / (duration / 60)  # MB per minute
            
            leak_report = {
                'container': container_name,
                'duration_minutes': duration / 60,
                'start_usage_mb': start_usage,
                'end_usage_mb': end_usage,
                'growth_rate_mb_per_min': round(growth_rate, 2),
                'measurements': measurements,
                'leak_detected': growth_rate > 1.0  # Growing more than 1MB/min
            }
            
            if leak_report['leak_detected']:
                print(f"🚨 POTENTIAL MEMORY LEAK DETECTED!")
                print(f"   Growth rate: {growth_rate:.2f} MB/min")
            else:
                print(f"✅ No memory leak detected")
            
            return leak_report
        
        return {'error': 'Insufficient measurements'}

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python memory-analyzer.py <container_name> [duration]")
        sys.exit(1)
    
    container_name = sys.argv[1]
    duration = int(sys.argv[2]) if len(sys.argv) > 2 else 300
    
    analyzer = MemoryAnalyzer()
    
    # Quick analysis
    analysis = analyzer.analyze_memory_usage(container_name)
    print(f"📊 Memory Analysis for {container_name}:")
    print(f"  Usage: {analysis['memory_usage_mb']} MB ({analysis['usage_percent']:.1f}%)")
    print(f"  Cache: {analysis['cache_mb']} MB ({analysis['cache_percent']:.1f}%)")
    print(f"  RSS: {analysis['rss_mb']} MB ({analysis['rss_percent']:.1f}%)")
    
    if analysis['recommendations']:
        print("💡 Recommendations:")
        for rec in analysis['recommendations']:
            print(f"  • {rec}")
    
    # Memory leak detection
    if duration > 0:
        leak_report = analyzer.memory_leak_detection(container_name, duration)
        
        # Save report
        with open(f'memory-leak-report-{container_name}.json', 'w') as f:
            json.dump(leak_report, f, indent=2)
```

## 📊 Monitoring & Observability

### 1. Comprehensive Monitoring Stack

#### Prometheus Configuration
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "docker_rules.yml"

scrape_configs:
  - job_name: 'docker'
    static_configs:
      - targets: ['localhost:9323']  # Docker daemon metrics
    scrape_interval: 5s

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
    scrape_interval: 5s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'applications'
    consul_sd_configs:
      - server: 'consul:8500'
        services:
          - 'webapp'
          - 'api'
    relabel_configs:
      - source_labels: [__meta_consul_service]
        target_label: service
      - source_labels: [__meta_consul_node]
        target_label: node

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

#### Docker Metrics Rules
```yaml
# docker_rules.yml
groups:
  - name: docker
    rules:
      - alert: ContainerDown
        expr: absent(container_last_seen{name!="POD"})
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.name }} is down"

      - alert: ContainerHighMemoryUsage
        expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100 > 90
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} memory usage is above 90%"
          description: "Container memory usage is {{ $value }}%"

      - alert: ContainerHighCPUUsage
        expr: rate(container_cpu_usage_seconds_total[5m]) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} CPU usage is above 80%"

      - alert: ContainerRestartingTooOften
        expr: rate(container_start_time_seconds[15m]) > 0
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} is restarting too often"
```

#### Complete Monitoring Stack
```yaml
# monitoring-stack.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./docker_rules.yml:/etc/prometheus/docker_rules.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
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
      - /dev/disk/:/dev/disk:ro
    devices:
      - /dev/kmsg:/dev/kmsg
    privileged: true
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:latest
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager_data:/alertmanager
    networks:
      - monitoring

  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"
      - "14268:14268"
    environment:
      - COLLECTOR_OTLP_ENABLED=true
    networks:
      - monitoring

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.8.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - monitoring

  kibana:
    image: docker.elastic.co/kibana/kibana:8.8.0
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch
    networks:
      - monitoring

  logstash:
    image: docker.elastic.co/logstash/logstash:8.8.0
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline
    depends_on:
      - elasticsearch
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:
  elasticsearch_data:

networks:
  monitoring:
    driver: bridge
```

### 2. Application Performance Monitoring

#### APM Integration
```python
#!/usr/bin/env python3
# apm-instrumentation.py

from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
import logging
import time
from flask import Flask, request, jsonify
import redis
import psycopg2

# Configure OpenTelemetry
resource = Resource.create({
    "service.name": "myapp",
    "service.version": "1.0.0",
    "deployment.environment": "production"
})

trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)

# Configure Jaeger exporter
jaeger_exporter = JaegerExporter(
    agent_host_name="jaeger",
    agent_port=6831,
)

span_processor = BatchSpanProcessor(jaeger_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Flask application with APM
app = Flask(__name__)

# Auto-instrument Flask
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()
Psycopg2Instrumentor().instrument()
RedisInstrumentor().instrument()

# Redis client
redis_client = redis.Redis(host='redis', port=6379, decode_responses=True)

class PerformanceMonitor:
    def __init__(self):
        self.metrics = {
            'request_count': 0,
            'error_count': 0,
            'response_times': []
        }
    
    def record_request(self, response_time: float, status_code: int):
        self.metrics['request_count'] += 1
        self.metrics['response_times'].append(response_time)
        
        if status_code >= 400:
            self.metrics['error_count'] += 1
    
    def get_metrics(self) -> dict:
        if self.metrics['response_times']:
            avg_response_time = sum(self.metrics['response_times']) / len(self.metrics['response_times'])
            p95_response_time = sorted(self.metrics['response_times'])[int(len(self.metrics['response_times']) * 0.95)]
        else:
            avg_response_time = 0
            p95_response_time = 0
        
        error_rate = (self.metrics['error_count'] / self.metrics['request_count'] * 100) if self.metrics['request_count'] > 0 else 0
        
        return {
            'total_requests': self.metrics['request_count'],
            'error_count': self.metrics['error_count'],
            'error_rate_percent': round(error_rate, 2),
            'avg_response_time_ms': round(avg_response_time * 1000, 2),
            'p95_response_time_ms': round(p95_response_time * 1000, 2)
        }

monitor = PerformanceMonitor()

@app.before_request
def before_request():
    request.start_time = time.time()

@app.after_request
def after_request(response):
    response_time = time.time() - request.start_time
    monitor.record_request(response_time, response.status_code)
    
    # Add custom headers
    response.headers['X-Response-Time'] = f"{response_time * 1000:.2f}ms"
    return response

@app.route('/api/users/<int:user_id>')
def get_user(user_id):
    with tracer.start_as_current_span("get_user") as span:
        span.set_attribute("user.id", user_id)
        
        # Check cache first
        cache_key = f"user:{user_id}"
        cached_user = redis_client.get(cache_key)
        
        if cached_user:
            span.add_event("cache_hit")
            return jsonify({"user": cached_user, "cached": True})
        
        # Database query (simulated)
        with tracer.start_as_current_span("database_query"):
            time.sleep(0.1)  # Simulate DB query
            user_data = {"id": user_id, "name": f"User {user_id}"}
        
        # Cache result
        redis_client.setex(cache_key, 3600, str(user_data))
        
        span.add_event("cache_set")
        return jsonify({"user": user_data, "cached": False})

@app.route('/metrics')
def metrics():
    """Prometheus-compatible metrics endpoint"""
    metrics = monitor.get_metrics()
    
    prometheus_metrics = f"""
# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total {metrics['total_requests']}

# HELP http_request_duration_seconds HTTP request duration in seconds
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_avg {metrics['avg_response_time_ms'] / 1000}
http_request_duration_seconds_p95 {metrics['p95_response_time_ms'] / 1000}

# HELP http_errors_total Total number of HTTP errors
# TYPE http_errors_total counter
http_errors_total {metrics['error_count']}

# HELP http_error_rate HTTP error rate percentage
# TYPE http_error_rate gauge
http_error_rate {metrics['error_rate_percent']}
"""
    
    return prometheus_metrics, 200, {'Content-Type': 'text/plain'}

@app.route('/health')
def health():
    """Health check endpoint"""
    health_status = {
        'status': 'healthy',
        'timestamp': time.time(),
        'services': {}
    }
    
    # Check Redis
    try:
        redis_client.ping()
        health_status['services']['redis'] = 'healthy'
    except Exception as e:
        health_status['services']['redis'] = f'unhealthy: {e}'
        health_status['status'] = 'degraded'
    
    # Check database (simulated)
    try:
        # conn = psycopg2.connect(DATABASE_URL)
        # conn.close()
        health_status['services']['database'] = 'healthy'
    except Exception as e:
        health_status['services']['database'] = f'unhealthy: {e}'
        health_status['status'] = 'unhealthy'
    
    status_code = 200 if health_status['status'] == 'healthy' else 503
    return jsonify(health_status), status_code

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
```

## 🚀 What's Next?

In [Chapter 10: Production Docker](../10-production-docker/README.md), you'll learn:
- Enterprise deployment architectures
- Scalability and high availability patterns
- Advanced orchestration with Kubernetes
- Production maintenance and operations

## 📚 Key Takeaways

✅ **Production Patterns**: Twelve-factor methodology and immutable infrastructure  
✅ **Performance**: Resource optimization and caching strategies  
✅ **Deployment**: Blue-green and canary deployment patterns  
✅ **Troubleshooting**: Systematic debugging and performance analysis  
✅ **Monitoring**: Comprehensive observability with metrics and tracing  
✅ **Operational Excellence**: Automated monitoring and alerting systems  

## 📝 Practice Checklist

Before moving on, ensure you can:
- [ ] Implement production deployment patterns
- [ ] Optimize container performance
- [ ] Debug container issues systematically
- [ ] Set up comprehensive monitoring
- [ ] Design scalable architectures
- [ ] Implement automated alerting

---

**🎉 Congratulations!** You now have enterprise-grade Docker skills for production environments. Complete the [lab exercise](lab/README.md) to practice these concepts, then validate your knowledge with the [checkpoint](checkpoint.md)!

---

<div align="center">

**[⬅️ Previous: Docker Security](../08-docker-security/README.md)** | **[Next: Production Docker ➡️](../10-production-docker/README.md)**

</div>
``` 