# 🌐 Chapter 04: Docker Networking - Advanced Network Management & Service Discovery

Welcome to advanced Docker networking! In this chapter, you'll master container networking, service discovery, load balancing, and network security for production environments.

## 🎯 Learning Objectives

By the end of this chapter, you will:
- ✅ Understand Docker networking architecture and drivers
- ✅ Create and manage custom Docker networks
- ✅ Implement service discovery and load balancing
- ✅ Configure network security and isolation
- ✅ Set up multi-host networking solutions
- ✅ Troubleshoot complex networking issues

## 🏗️ Docker Networking Architecture

### Network Architecture Overview

```
┌─────────────────────────────────────────┐
│            Host System                  │
├─────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  │
│  │Container│  │Container│  │Container│  │
│  │   A     │  │   B     │  │   C     │  │
│  └────┬────┘  └────┬────┘  └────┬────┘  │
│       │            │            │       │
│  ┌────┴────────────┴────────────┴────┐  │
│  │        Docker Bridge Network      │  │
│  │         (docker0: 172.17.0.1)     │  │
│  └─────────────────┬─────────────────┘  │
│                    │                    │
│  ┌─────────────────┴─────────────────┐  │
│  │          Host Network Stack       │  │
│  │            (eth0: External)       │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Network Drivers

Docker supports multiple network drivers:

1. **Bridge** (default): Isolated network on single host
2. **Host**: Container uses host network stack
3. **None**: No networking
4. **Overlay**: Multi-host networking
5. **Macvlan**: Direct physical network access
6. **IPvlan**: Layer 3 routing

## 🔗 Default Docker Networking

### Bridge Network Basics

```bash
# View default networks
docker network ls

# Inspect default bridge network
docker network inspect bridge

# Default bridge network details
# Network: 172.17.0.0/16
# Gateway: 172.17.0.1
# DNS: 127.0.0.11
```

**Default bridge limitations:**
- No automatic service discovery
- Containers communicate via IP addresses only
- No built-in load balancing
- Limited network isolation

### Container Communication on Default Bridge

```bash
# Start containers on default bridge
docker run -d --name web nginx:alpine
docker run -d --name db postgres:13

# Get container IPs
docker inspect web --format='{{.NetworkSettings.IPAddress}}'
docker inspect db --format='{{.NetworkSettings.IPAddress}}'

# Test connectivity (by IP only)
docker exec web ping 172.17.0.3  # db container IP
```

## 🌉 Custom Networks

### Creating Custom Bridge Networks

```bash
# Create custom bridge network
docker network create mynetwork

# Create with custom settings
docker network create \
  --driver bridge \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.1 \
  --ip-range=192.168.1.0/28 \
  production-network

# Advanced network configuration
docker network create \
  --driver bridge \
  --subnet=10.0.0.0/16 \
  --gateway=10.0.0.1 \
  --ip-range=10.0.1.0/24 \
  --aux-address="host1=10.0.1.5" \
  --aux-address="host2=10.0.1.6" \
  --opt com.docker.network.bridge.name=docker-br0 \
  --opt com.docker.network.bridge.enable_icc=true \
  --opt com.docker.network.bridge.enable_ip_masquerade=true \
  --opt com.docker.network.driver.mtu=1500 \
  advanced-network
```

### Service Discovery in Custom Networks

**Automatic DNS resolution:**
```bash
# Create network and containers
docker network create webapp-network

docker run -d --name database \
  --network webapp-network \
  -e POSTGRES_PASSWORD=secret \
  postgres:13

docker run -d --name backend \
  --network webapp-network \
  -e DATABASE_URL=postgresql://postgres:secret@database:5432/app \
  myapp:backend

docker run -d --name frontend \
  --network webapp-network \
  -e API_URL=http://backend:8080/api \
  myapp:frontend

# Test service discovery
docker exec frontend nslookup backend
docker exec frontend nslookup database
docker exec backend ping database
```

### Network Aliases

```bash
# Create containers with network aliases
docker run -d --name web1 \
  --network mynetwork \
  --network-alias webserver \
  nginx:alpine

docker run -d --name web2 \
  --network mynetwork \
  --network-alias webserver \
  nginx:alpine

# Both containers respond to 'webserver' hostname
docker run --rm --network mynetwork alpine nslookup webserver
```

## 🔍 Network Inspection & Management

### Network Commands

```bash
# List all networks
docker network ls

# Inspect network details
docker network inspect mynetwork

# View containers in network
docker network inspect mynetwork --format='{{range .Containers}}{{.Name}} {{.IPv4Address}}{{"\n"}}{{end}}'

# Connect container to network
docker network connect mynetwork existing-container

# Disconnect container from network
docker network disconnect mynetwork existing-container

# Remove network
docker network rm mynetwork

# Prune unused networks
docker network prune
```

### Network Troubleshooting

```bash
# Check container networking
docker exec mycontainer ip addr show
docker exec mycontainer ip route show
docker exec mycontainer cat /etc/resolv.conf

# Test connectivity
docker exec mycontainer ping google.com
docker exec mycontainer nslookup database
docker exec mycontainer telnet backend 8080

# Check port bindings
docker port mycontainer

# Inspect network namespace
docker exec mycontainer netstat -tuln
docker exec mycontainer ss -tuln
```

## 🏢 Multi-Host Networking

### Overlay Networks

**Docker Swarm overlay:**
```bash
# Initialize swarm
docker swarm init --advertise-addr 192.168.1.100

# Create overlay network
docker network create \
  --driver overlay \
  --attachable \
  multi-host-network

# Join worker nodes
docker swarm join --token <token> 192.168.1.100:2377

# Deploy service across nodes
docker service create \
  --name web \
  --network multi-host-network \
  --replicas 3 \
  nginx:alpine
```

**Standalone overlay (without swarm):**
```bash
# Setup external key-value store (Consul)
docker run -d --name consul \
  -p 8500:8500 \
  consul:latest agent -server -bootstrap -ui -client=0.0.0.0

# Configure Docker daemon for external store
# /etc/docker/daemon.json
{
  "cluster-store": "consul://192.168.1.100:8500",
  "cluster-advertise": "192.168.1.100:2376"
}

# Create overlay network
docker network create \
  --driver overlay \
  --subnet=10.0.9.0/24 \
  external-overlay
```

### Macvlan Networks

**Direct physical network access:**
```bash
# Create macvlan network
docker network create \
  --driver macvlan \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.1 \
  --opt parent=eth0 \
  macvlan-network

# Run container with direct network access
docker run -d --name direct-access \
  --network macvlan-network \
  --ip=192.168.1.100 \
  nginx:alpine

# Container appears as physical device on network
ping 192.168.1.100  # From external hosts
```

### IPvlan Networks

**Layer 3 routing:**
```bash
# L3 IPvlan network
docker network create \
  --driver ipvlan \
  --subnet=192.168.100.0/24 \
  --gateway=192.168.100.1 \
  --opt parent=eth0 \
  --opt ipvlan_mode=l3 \
  ipvlan-l3

# L2 IPvlan network
docker network create \
  --driver ipvlan \
  --subnet=192.168.101.0/24 \
  --opt parent=eth0 \
  --opt ipvlan_mode=l2 \
  ipvlan-l2
```

## ⚖️ Load Balancing & Service Discovery

### Built-in Load Balancing

```bash
# Create network with multiple backend instances
docker network create lb-network

# Start multiple backend instances
for i in {1..3}; do
  docker run -d --name backend-$i \
    --network lb-network \
    --network-alias backend \
    -e INSTANCE_ID=$i \
    myapp:backend
done

# Frontend automatically load balances across backends
docker run -d --name frontend \
  --network lb-network \
  -p 80:80 \
  -e BACKEND_URL=http://backend:8080 \
  myapp:frontend

# Docker's built-in DNS round-robin load balancing
docker exec frontend nslookup backend  # Returns multiple IPs
```

### External Load Balancers

**HAProxy configuration:**
```bash
# Create HAProxy configuration
cat > haproxy.cfg << 'EOF'
global
    daemon

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend web_frontend
    bind *:80
    default_backend web_servers

backend web_servers
    balance roundrobin
    server web1 web1:80 check
    server web2 web2:80 check
    server web3 web3:80 check
EOF

# Deploy HAProxy
docker run -d --name haproxy \
  --network mynetwork \
  -p 80:80 \
  -v $(pwd)/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
  haproxy:latest
```

**NGINX load balancer:**
```bash
# NGINX upstream configuration
cat > nginx.conf << 'EOF'
upstream backend {
    server backend1:8080;
    server backend2:8080;
    server backend3:8080;
}

server {
    listen 80;
    
    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

docker run -d --name nginx-lb \
  --network mynetwork \
  -p 80:80 \
  -v $(pwd)/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
  nginx:alpine
```

### Service Mesh with Consul Connect

```bash
# Start Consul
docker run -d --name consul \
  --network consul-network \
  -p 8500:8500 \
  consul:latest agent -server -bootstrap -ui -client=0.0.0.0

# Register services
curl -X PUT \
  -d '{
    "ID": "web-1",
    "Name": "web",
    "Tags": ["v1"],
    "Address": "192.168.1.10",
    "Port": 80,
    "Check": {
      "HTTP": "http://192.168.1.10:80/health",
      "Interval": "10s"
    }
  }' \
  http://localhost:8500/v1/agent/service/register

# Service discovery query
curl http://localhost:8500/v1/health/service/web?passing
```

## 🔒 Network Security

### Network Isolation

```bash
# Create isolated networks
docker network create frontend-network
docker network create backend-network
docker network create database-network

# Deploy with network isolation
docker run -d --name database \
  --network database-network \
  postgres:13

docker run -d --name backend \
  --network backend-network \
  --network database-network \
  myapp:backend

docker run -d --name frontend \
  --network frontend-network \
  --network backend-network \
  -p 80:80 \
  myapp:frontend

# Database only accessible from backend
# Frontend cannot directly access database
```

### Network Policies with iptables

```bash
# Create network security script
cat > network-security.sh << 'EOF'
#!/bin/bash

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow Docker bridge traffic
iptables -A FORWARD -i docker0 -o docker0 -j ACCEPT

# Allow specific container communication
iptables -A FORWARD -s 172.18.0.0/16 -d 172.19.0.0/16 -j ACCEPT

# Block direct access to database network
iptables -A FORWARD -d 172.20.0.0/16 -j DROP

# Allow HTTP/HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow SSH (be careful!)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

echo "Network security rules applied"
EOF

chmod +x network-security.sh
sudo ./network-security.sh
```

### Container-to-Container Encryption

**TLS between containers:**
```bash
# Generate certificates
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Backend with TLS
docker run -d --name secure-backend \
  --network secure-network \
  -v $(pwd)/cert.pem:/app/cert.pem:ro \
  -v $(pwd)/key.pem:/app/key.pem:ro \
  -e TLS_CERT=/app/cert.pem \
  -e TLS_KEY=/app/key.pem \
  myapp:secure-backend

# Frontend with TLS client
docker run -d --name secure-frontend \
  --network secure-network \
  -v $(pwd)/cert.pem:/app/ca.pem:ro \
  -e BACKEND_URL=https://secure-backend:8443 \
  -e CA_CERT=/app/ca.pem \
  myapp:secure-frontend
```

## 🔧 Advanced Networking Patterns

### Reverse Proxy Pattern

```python
# Smart reverse proxy with service discovery
# proxy-app.py
from flask import Flask, request, Response
import requests
import consul
import random

app = Flask(__name__)
consul_client = consul.Consul(host='consul', port=8500)

def get_healthy_backends(service_name):
    """Get healthy backend instances from Consul"""
    try:
        _, services = consul_client.health.service(service_name, passing=True)
        backends = []
        for service in services:
            addr = service['Service']['Address']
            port = service['Service']['Port']
            backends.append(f"http://{addr}:{port}")
        return backends
    except Exception as e:
        print(f"Error getting backends: {e}")
        return []

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def proxy(path):
    """Proxy requests to backend services"""
    backends = get_healthy_backends('backend')
    
    if not backends:
        return "No healthy backends available", 503
    
    # Simple round-robin load balancing
    backend = random.choice(backends)
    
    try:
        # Forward request to backend
        resp = requests.request(
            method=request.method,
            url=f"{backend}/{path}",
            headers={key: value for (key, value) in request.headers if key != 'Host'},
            data=request.get_data(),
            cookies=request.cookies,
            allow_redirects=False,
            timeout=30
        )
        
        # Forward response
        response = Response(
            resp.content,
            status=resp.status_code,
            headers=dict(resp.headers)
        )
        
        return response
        
    except Exception as e:
        print(f"Proxy error: {e}")
        return "Backend unavailable", 502

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
```

### Circuit Breaker Pattern

```python
# circuit-breaker.py
import time
import requests
from enum import Enum
from threading import Lock

class CircuitState(Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"

class CircuitBreaker:
    def __init__(self, failure_threshold=5, timeout=60, expected_exception=Exception):
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.expected_exception = expected_exception
        
        self.failure_count = 0
        self.last_failure_time = None
        self.state = CircuitState.CLOSED
        self.lock = Lock()
    
    def call(self, func, *args, **kwargs):
        with self.lock:
            if self.state == CircuitState.OPEN:
                if time.time() - self.last_failure_time > self.timeout:
                    self.state = CircuitState.HALF_OPEN
                    self.failure_count = 0
                else:
                    raise Exception("Circuit breaker is OPEN")
            
            try:
                result = func(*args, **kwargs)
                self.on_success()
                return result
            except self.expected_exception as e:
                self.on_failure()
                raise e
    
    def on_success(self):
        self.failure_count = 0
        self.state = CircuitState.CLOSED
    
    def on_failure(self):
        self.failure_count += 1
        self.last_failure_time = time.time()
        
        if self.failure_count >= self.failure_threshold:
            self.state = CircuitState.OPEN

# Usage example
def make_api_call(url):
    response = requests.get(url, timeout=5)
    response.raise_for_status()
    return response.json()

# Create circuit breaker
breaker = CircuitBreaker(failure_threshold=3, timeout=30)

# Protected API call
try:
    data = breaker.call(make_api_call, "http://backend:8080/api/data")
    print(f"Success: {data}")
except Exception as e:
    print(f"Failed: {e}")
```

### Health Check Load Balancer

```python
# health-aware-lb.py
import asyncio
import aiohttp
import time
from typing import List, Dict, Optional

class HealthAwareLoadBalancer:
    def __init__(self):
        self.backends: List[Dict] = []
        self.current_index = 0
        self.health_check_interval = 30
        
    def add_backend(self, url: str, weight: int = 1):
        """Add backend with health status tracking"""
        backend = {
            'url': url,
            'weight': weight,
            'healthy': True,
            'last_check': 0,
            'consecutive_failures': 0
        }
        self.backends.append(backend)
    
    async def check_backend_health(self, backend: Dict) -> bool:
        """Check if backend is healthy"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    f"{backend['url']}/health",
                    timeout=aiohttp.ClientTimeout(total=5)
                ) as response:
                    if response.status == 200:
                        backend['consecutive_failures'] = 0
                        return True
                    else:
                        backend['consecutive_failures'] += 1
                        return False
        except Exception:
            backend['consecutive_failures'] += 1
            return False
    
    async def health_check_loop(self):
        """Continuous health checking"""
        while True:
            for backend in self.backends:
                current_time = time.time()
                if current_time - backend['last_check'] > self.health_check_interval:
                    backend['healthy'] = await self.check_backend_health(backend)
                    backend['last_check'] = current_time
                    
                    # Mark unhealthy after 3 consecutive failures
                    if backend['consecutive_failures'] >= 3:
                        backend['healthy'] = False
            
            await asyncio.sleep(10)
    
    def get_healthy_backends(self) -> List[Dict]:
        """Get list of healthy backends"""
        return [b for b in self.backends if b['healthy']]
    
    def get_next_backend(self) -> Optional[str]:
        """Get next backend using weighted round-robin"""
        healthy_backends = self.get_healthy_backends()
        
        if not healthy_backends:
            return None
        
        # Simple round-robin (can be enhanced with weights)
        backend = healthy_backends[self.current_index % len(healthy_backends)]
        self.current_index += 1
        
        return backend['url']

# Usage example
async def main():
    lb = HealthAwareLoadBalancer()
    lb.add_backend('http://backend1:8080', weight=2)
    lb.add_backend('http://backend2:8080', weight=1)
    lb.add_backend('http://backend3:8080', weight=1)
    
    # Start health checking
    asyncio.create_task(lb.health_check_loop())
    
    # Load balancing logic
    while True:
        backend = lb.get_next_backend()
        if backend:
            print(f"Routing to: {backend}")
        else:
            print("No healthy backends available")
        
        await asyncio.sleep(1)

if __name__ == "__main__":
    asyncio.run(main())
```

## 🐍 Production Network Examples

### 1. Microservices Network Architecture

```yaml
# docker-compose.yml for microservices
version: '3.8'

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
  database:
    driver: bridge
    internal: true  # No external access

services:
  # Reverse Proxy / Load Balancer
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    networks:
      - frontend
    depends_on:
      - api-gateway

  # API Gateway
  api-gateway:
    image: myapp/api-gateway:latest
    environment:
      - CONSUL_URL=http://consul:8500
    networks:
      - frontend
      - backend
    depends_on:
      - consul

  # Service Discovery
  consul:
    image: consul:latest
    command: agent -server -bootstrap -ui -client=0.0.0.0
    ports:
      - "8500:8500"
    networks:
      - backend

  # Microservices
  user-service:
    image: myapp/user-service:latest
    environment:
      - DATABASE_URL=postgresql://postgres:secret@user-db:5432/users
      - CONSUL_URL=http://consul:8500
    networks:
      - backend
      - database
    depends_on:
      - user-db
      - consul

  order-service:
    image: myapp/order-service:latest
    environment:
      - DATABASE_URL=postgresql://postgres:secret@order-db:5432/orders
      - CONSUL_URL=http://consul:8500
    networks:
      - backend
      - database
    depends_on:
      - order-db
      - consul

  # Databases (isolated network)
  user-db:
    image: postgres:13
    environment:
      - POSTGRES_DB=users
      - POSTGRES_PASSWORD=secret
    volumes:
      - user_data:/var/lib/postgresql/data
    networks:
      - database

  order-db:
    image: postgres:13
    environment:
      - POSTGRES_DB=orders
      - POSTGRES_PASSWORD=secret
    volumes:
      - order_data:/var/lib/postgresql/data
    networks:
      - database

volumes:
  user_data:
  order_data:
```

### 2. High-Availability Web Application

```bash
# Create production network setup
#!/bin/bash

# Create networks
docker network create \
  --driver bridge \
  --subnet=10.0.1.0/24 \
  --ip-range=10.0.1.0/28 \
  frontend-net

docker network create \
  --driver bridge \
  --subnet=10.0.2.0/24 \
  --ip-range=10.0.2.0/28 \
  backend-net

docker network create \
  --driver bridge \
  --subnet=10.0.3.0/24 \
  --ip-range=10.0.3.0/28 \
  --internal \
  database-net

# Deploy load balancer
docker run -d --name haproxy \
  --network frontend-net \
  -p 80:80 \
  -p 443:443 \
  -p 8404:8404 \
  -v $(pwd)/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
  haproxy:latest

# Deploy backend instances
for i in {1..3}; do
  docker run -d --name backend-$i \
    --network backend-net \
    --network frontend-net \
    -e INSTANCE_ID=$i \
    -e DATABASE_URL=postgresql://postgres:secret@postgres:5432/app \
    myapp:backend
done

# Deploy database cluster
docker run -d --name postgres-master \
  --network database-net \
  --network backend-net \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_REPLICATION_MODE=master \
  -e POSTGRES_REPLICATION_USER=replicator \
  -e POSTGRES_REPLICATION_PASSWORD=reppass \
  -v postgres_master_data:/var/lib/postgresql/data \
  bitnami/postgresql:13

docker run -d --name postgres-slave \
  --network database-net \
  -e POSTGRES_MASTER_HOST=postgres-master \
  -e POSTGRES_REPLICATION_MODE=slave \
  -e POSTGRES_REPLICATION_USER=replicator \
  -e POSTGRES_REPLICATION_PASSWORD=reppass \
  -e POSTGRES_MASTER_PORT_NUMBER=5432 \
  bitnami/postgresql:13

# Deploy monitoring
docker run -d --name monitoring \
  --network frontend-net \
  --network backend-net \
  --network database-net \
  -p 3000:3000 \
  -v monitoring_data:/var/lib/grafana \
  grafana/grafana:latest

echo "Production setup complete!"
```

### 3. Container Network Monitoring

```python
# network-monitor.py
import docker
import time
import json
import subprocess
from datetime import datetime

class NetworkMonitor:
    def __init__(self):
        self.client = docker.from_env()
        
    def get_network_stats(self, container):
        """Get network statistics for container"""
        try:
            stats = container.stats(stream=False)
            networks = stats.get('networks', {})
            
            total_stats = {
                'rx_bytes': 0,
                'tx_bytes': 0,
                'rx_packets': 0,
                'tx_packets': 0,
                'rx_errors': 0,
                'tx_errors': 0,
                'rx_dropped': 0,
                'tx_dropped': 0
            }
            
            for interface, net_stats in networks.items():
                for key in total_stats:
                    total_stats[key] += net_stats.get(key, 0)
            
            return {
                'container': container.name,
                'networks': list(networks.keys()),
                'stats': total_stats,
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            return {
                'container': container.name,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    def get_network_topology(self):
        """Get current network topology"""
        networks = {}
        
        for network in self.client.networks.list():
            if network.name in ['bridge', 'host', 'none']:
                continue
                
            network_info = {
                'name': network.name,
                'driver': network.attrs['Driver'],
                'subnet': network.attrs['IPAM']['Config'][0]['Subnet'] if network.attrs['IPAM']['Config'] else 'N/A',
                'containers': []
            }
            
            for container_id, container_info in network.attrs['Containers'].items():
                try:
                    container = self.client.containers.get(container_id)
                    network_info['containers'].append({
                        'name': container.name,
                        'ip': container_info['IPv4Address'].split('/')[0],
                        'mac': container_info['MacAddress']
                    })
                except:
                    pass
            
            networks[network.name] = network_info
        
        return networks
    
    def test_connectivity(self, source_container, target_container):
        """Test connectivity between containers"""
        try:
            result = source_container.exec_run(
                f"ping -c 3 {target_container.name}",
                stdout=True,
                stderr=True
            )
            
            return {
                'source': source_container.name,
                'target': target_container.name,
                'success': result.exit_code == 0,
                'output': result.output.decode(),
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            return {
                'source': source_container.name,
                'target': target_container.name,
                'success': False,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    def monitor_network_traffic(self, duration=60):
        """Monitor network traffic for specified duration"""
        print(f"🔍 Monitoring network traffic for {duration} seconds...")
        
        containers = self.client.containers.list()
        start_stats = {}
        
        # Get initial stats
        for container in containers:
            start_stats[container.name] = self.get_network_stats(container)
        
        time.sleep(duration)
        
        # Get end stats and calculate differences
        traffic_report = []
        for container in containers:
            end_stats = self.get_network_stats(container)
            
            if container.name in start_stats and 'error' not in start_stats[container.name]:
                start = start_stats[container.name]['stats']
                end = end_stats['stats']
                
                traffic = {
                    'container': container.name,
                    'rx_bytes_delta': end['rx_bytes'] - start['rx_bytes'],
                    'tx_bytes_delta': end['tx_bytes'] - start['tx_bytes'],
                    'rx_packets_delta': end['rx_packets'] - start['rx_packets'],
                    'tx_packets_delta': end['tx_packets'] - start['tx_packets'],
                    'duration': duration
                }
                
                traffic_report.append(traffic)
        
        return traffic_report
    
    def generate_report(self):
        """Generate comprehensive network report"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'topology': self.get_network_topology(),
            'traffic': self.monitor_network_traffic(30),
            'connectivity': []
        }
        
        # Test connectivity between containers
        containers = self.client.containers.list()
        for i, source in enumerate(containers):
            for target in containers[i+1:]:
                connectivity = self.test_connectivity(source, target)
                report['connectivity'].append(connectivity)
        
        return report

if __name__ == "__main__":
    monitor = NetworkMonitor()
    
    print("📊 Generating network report...")
    report = monitor.generate_report()
    
    with open(f"network-report-{int(time.time())}.json", 'w') as f:
        json.dump(report, f, indent=2)
    
    print("✅ Network report generated!")
```

## 🛠️ Network Troubleshooting Tools

### 1. Network Diagnostic Script

```bash
#!/bin/bash
# network-diagnostics.sh

CONTAINER_NAME=${1:-""}

if [[ -z "$CONTAINER_NAME" ]]; then
    echo "Usage: $0 <container-name>"
    exit 1
fi

echo "🔍 Network Diagnostics for: $CONTAINER_NAME"
echo "================================================"

# Container information
echo "📦 Container Information:"
docker inspect $CONTAINER_NAME --format='{{.Name}}: {{.State.Status}}'
echo ""

# Network configuration
echo "🌐 Network Configuration:"
docker inspect $CONTAINER_NAME --format='{{range $net, $conf := .NetworkSettings.Networks}}Network: {{$net}} | IP: {{$conf.IPAddress}} | Gateway: {{$conf.Gateway}}{{"\n"}}{{end}}'
echo ""

# Port bindings
echo "🔌 Port Bindings:"
docker port $CONTAINER_NAME 2>/dev/null || echo "No port bindings"
echo ""

# Network interfaces
echo "🔧 Network Interfaces:"
docker exec $CONTAINER_NAME ip addr show 2>/dev/null || echo "Cannot access container"
echo ""

# Routing table
echo "🗺️ Routing Table:"
docker exec $CONTAINER_NAME ip route show 2>/dev/null || echo "Cannot access container"
echo ""

# DNS configuration
echo "🌍 DNS Configuration:"
docker exec $CONTAINER_NAME cat /etc/resolv.conf 2>/dev/null || echo "Cannot access container"
echo ""

# Network connections
echo "🔗 Network Connections:"
docker exec $CONTAINER_NAME netstat -tuln 2>/dev/null || docker exec $CONTAINER_NAME ss -tuln 2>/dev/null || echo "Cannot access container"
echo ""

# Test external connectivity
echo "🌐 External Connectivity Test:"
docker exec $CONTAINER_NAME ping -c 3 8.8.8.8 2>/dev/null || echo "Cannot test external connectivity"
echo ""

# Test DNS resolution
echo "🔍 DNS Resolution Test:"
docker exec $CONTAINER_NAME nslookup google.com 2>/dev/null || echo "Cannot test DNS resolution"
echo ""

echo "✅ Diagnostics complete!"
```

### 2. Network Performance Testing

```python
#!/usr/bin/env python3
# network-performance.py

import subprocess
import time
import json
import statistics
from concurrent.futures import ThreadPoolExecutor
import docker

class NetworkPerformanceTest:
    def __init__(self):
        self.client = docker.from_env()
        
    def ping_test(self, source_container, target, count=10):
        """Perform ping test between containers"""
        try:
            result = source_container.exec_run(
                f"ping -c {count} {target}",
                stdout=True,
                stderr=True
            )
            
            if result.exit_code == 0:
                output = result.output.decode()
                # Parse ping statistics
                lines = output.split('\n')
                for line in lines:
                    if 'min/avg/max' in line:
                        # Extract timing information
                        times = line.split('=')[1].strip().split('/')
                        return {
                            'success': True,
                            'min_ms': float(times[0]),
                            'avg_ms': float(times[1]),
                            'max_ms': float(times[2]),
                            'target': target
                        }
            
            return {'success': False, 'target': target, 'error': result.output.decode()}
            
        except Exception as e:
            return {'success': False, 'target': target, 'error': str(e)}
    
    def bandwidth_test(self, server_container, client_container):
        """Perform bandwidth test using iperf3"""
        try:
            # Start iperf3 server
            server_container.exec_run(
                "iperf3 -s -D",  # Run as daemon
                detach=True
            )
            
            time.sleep(2)  # Wait for server to start
            
            # Run client test
            result = client_container.exec_run(
                f"iperf3 -c {server_container.name} -t 10 -J",  # JSON output
                stdout=True,
                stderr=True
            )
            
            if result.exit_code == 0:
                data = json.loads(result.output.decode())
                return {
                    'success': True,
                    'bandwidth_mbps': data['end']['sum_received']['bits_per_second'] / 1_000_000,
                    'retransmits': data['end']['sum_sent']['retransmits'],
                    'server': server_container.name,
                    'client': client_container.name
                }
            else:
                return {
                    'success': False,
                    'error': result.output.decode(),
                    'server': server_container.name,
                    'client': client_container.name
                }
                
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'server': server_container.name,
                'client': client_container.name
            }
    
    def latency_distribution_test(self, source_container, target, samples=100):
        """Test latency distribution"""
        latencies = []
        
        for i in range(samples):
            try:
                result = source_container.exec_run(
                    f"ping -c 1 {target}",
                    stdout=True,
                    stderr=True
                )
                
                if result.exit_code == 0:
                    output = result.output.decode()
                    for line in output.split('\n'):
                        if 'time=' in line:
                            time_str = line.split('time=')[1].split(' ')[0]
                            latencies.append(float(time_str))
                            break
            except:
                pass
            
            time.sleep(0.1)  # Small delay between pings
        
        if latencies:
            return {
                'target': target,
                'samples': len(latencies),
                'min_ms': min(latencies),
                'max_ms': max(latencies),
                'avg_ms': statistics.mean(latencies),
                'median_ms': statistics.median(latencies),
                'p95_ms': statistics.quantiles(latencies, n=20)[18],  # 95th percentile
                'p99_ms': statistics.quantiles(latencies, n=100)[98],  # 99th percentile
                'stddev_ms': statistics.stdev(latencies) if len(latencies) > 1 else 0
            }
        else:
            return {'target': target, 'error': 'No successful pings'}
    
    def run_comprehensive_test(self):
        """Run comprehensive network performance test"""
        print("🚀 Starting comprehensive network performance test...")
        
        containers = self.client.containers.list()
        results = {
            'timestamp': time.time(),
            'ping_tests': [],
            'latency_distribution': [],
            'bandwidth_tests': []
        }
        
        # Ping tests
        print("📡 Running ping tests...")
        for container in containers:
            for target in containers:
                if container != target:
                    ping_result = self.ping_test(container, target.name)
                    ping_result['source'] = container.name
                    results['ping_tests'].append(ping_result)
        
        # Latency distribution tests
        print("📊 Running latency distribution tests...")
        for container in containers[:2]:  # Limit to first 2 containers
            for target in containers[:2]:
                if container != target:
                    latency_result = self.latency_distribution_test(container, target.name, 50)
                    latency_result['source'] = container.name
                    results['latency_distribution'].append(latency_result)
        
        # Bandwidth tests (requires iperf3 in containers)
        print("🌐 Running bandwidth tests...")
        if len(containers) >= 2:
            bandwidth_result = self.bandwidth_test(containers[0], containers[1])
            results['bandwidth_tests'].append(bandwidth_result)
        
        return results

if __name__ == "__main__":
    tester = NetworkPerformanceTest()
    results = tester.run_comprehensive_test()
    
    # Save results
    with open(f'network-performance-{int(time.time())}.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print("✅ Performance test complete! Results saved.")
```

## 🎯 Chapter Checkpoint

### Questions

1. **What are the key differences between bridge and overlay networks?**
   - Bridge: Single host, overlay: Multi-host with encryption

2. **How does Docker's built-in load balancing work?**
   - DNS round-robin resolution for containers with same network alias

3. **When would you use macvlan vs ipvlan networks?**
   - Macvlan: Direct L2 access, ipvlan: L3 routing with better performance

4. **How do you troubleshoot container networking issues?**
   - Check network config, test connectivity, inspect DNS resolution

### Tasks

- [ ] Create custom networks with proper isolation
- [ ] Implement service discovery and load balancing
- [ ] Set up network security and monitoring
- [ ] Configure multi-host networking

---

## 🚀 What's Next?

In [Chapter 05: Docker Storage](../05-docker-storage/README.md), you'll learn:
- Docker storage drivers and backends
- Volumes and bind mounts
- Persistent data management
- Storage performance optimization
- Backup and restore strategies

## 📚 Key Takeaways

✅ **Custom networks** enable proper service discovery and isolation
✅ **Load balancing** can be achieved through DNS resolution or external proxies
✅ **Network security** requires proper isolation and encryption
✅ **Multi-host networking** enables distributed applications
✅ **Monitoring and troubleshooting** are essential for production networks
✅ **Performance testing** validates network design decisions

## 📝 Practice Checklist

Before moving on, ensure you can:
- [ ] Create and manage custom Docker networks
- [ ] Implement service discovery and load balancing
- [ ] Configure network security and isolation
- [ ] Set up multi-host networking
- [ ] Troubleshoot networking issues effectively
- [ ] Monitor network performance and traffic

---

**🎉 Congratulations!** You now have advanced Docker networking skills. Complete the [lab exercise](lab/README.md) to practice these concepts, then validate your knowledge with the [checkpoint](checkpoint.md)!

---

<div align="center">

**[⬅️ Previous: Docker Containers](../03-docker-containers/README.md)** | **[Next: Docker Storage ➡️](../05-docker-storage/README.md)**

</div> 