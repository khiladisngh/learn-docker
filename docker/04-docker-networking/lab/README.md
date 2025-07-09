# 🧪 Lab 04: Advanced Docker Networking

In this lab, you'll practice advanced Docker networking including custom networks, service discovery, load balancing, and network security configurations.

## 🎯 Lab Objectives

By completing this lab, you will:
- Create and configure custom Docker networks
- Implement service discovery and load balancing
- Set up network isolation and security
- Test inter-container communication
- Troubleshoot networking issues

## 📋 Prerequisites

- Docker Engine installed and running
- Basic understanding of Docker containers
- Text editor (VS Code, nano, vim)
- Basic networking knowledge (IP, DNS, ports)

## 🚀 Lab Exercises

### Exercise 1: Custom Network Creation & Management

**Goal:** Create and manage custom Docker networks with proper configuration.

#### Step 1: Basic Custom Networks

```bash
# Create basic custom network
docker network create lab-network

# Inspect the network
docker network inspect lab-network

# Create network with custom subnet
docker network create \
  --driver bridge \
  --subnet=192.168.100.0/24 \
  --gateway=192.168.100.1 \
  --ip-range=192.168.100.0/28 \
  custom-network

# Verify network configuration
docker network ls
docker network inspect custom-network
```

#### Step 2: Advanced Network Configuration

```bash
# Create production-like network with custom settings
docker network create \
  --driver bridge \
  --subnet=10.0.1.0/24 \
  --gateway=10.0.1.1 \
  --ip-range=10.0.1.0/28 \
  --aux-address="host1=10.0.1.5" \
  --aux-address="host2=10.0.1.6" \
  --opt com.docker.network.bridge.name=prod-bridge \
  --opt com.docker.network.bridge.enable_icc=true \
  --opt com.docker.network.bridge.enable_ip_masquerade=true \
  --opt com.docker.network.driver.mtu=1500 \
  production-network

# Inspect advanced network
docker network inspect production-network
```

#### Step 3: Test Network Connectivity

```bash
# Start containers in custom network
docker run -d --name web1 \
  --network custom-network \
  nginx:alpine

docker run -d --name web2 \
  --network custom-network \
  nginx:alpine

# Test connectivity between containers
docker exec web1 ping -c 3 web2
docker exec web2 ping -c 3 web1

# Check network interfaces
docker exec web1 ip addr show
docker exec web1 ip route show
```

### Exercise 2: Service Discovery & Load Balancing

**Goal:** Implement service discovery using network aliases and DNS.

#### Step 1: Service Discovery with Network Aliases

```bash
# Create network for service discovery
docker network create service-network

# Create backend services with same alias
docker run -d --name backend1 \
  --network service-network \
  --network-alias backend \
  --network-alias api \
  -e SERVICE_ID=backend1 \
  nginx:alpine

docker run -d --name backend2 \
  --network service-network \
  --network-alias backend \
  --network-alias api \
  -e SERVICE_ID=backend2 \
  nginx:alpine

docker run -d --name backend3 \
  --network service-network \
  --network-alias backend \
  --network-alias api \
  -e SERVICE_ID=backend3 \
  nginx:alpine

# Test service discovery
docker run --rm --network service-network alpine nslookup backend
docker run --rm --network service-network alpine nslookup api

# Create client to test load balancing
docker run -d --name client \
  --network service-network \
  alpine sleep 3600

# Test DNS round-robin load balancing
for i in {1..10}; do
  echo "Request $i:"
  docker exec client nslookup backend
done
```

#### Step 2: Create Custom Load Balancer

Create a simple HTTP load balancer:

```python
# Create load balancer application
cat > load_balancer.py << 'EOF'
#!/usr/bin/env python3
import socket
import threading
import time
import random
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.request
import json

class LoadBalancer:
    def __init__(self):
        self.backends = []
        self.current_backend = 0
        
    def add_backend(self, host, port):
        self.backends.append(f"http://{host}:{port}")
        
    def get_next_backend(self):
        """Simple round-robin load balancing"""
        if not self.backends:
            return None
        backend = self.backends[self.current_backend]
        self.current_backend = (self.current_backend + 1) % len(self.backends)
        return backend
    
    def check_backend_health(self, backend):
        """Check if backend is healthy"""
        try:
            response = urllib.request.urlopen(f"{backend}/health", timeout=5)
            return response.status == 200
        except:
            return False

class LoadBalancerHandler(BaseHTTPRequestHandler):
    lb = LoadBalancer()
    
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            health_status = {
                'status': 'healthy',
                'backends': len(self.lb.backends),
                'timestamp': time.time()
            }
            self.wfile.write(json.dumps(health_status).encode())
            return
            
        backend = self.lb.get_next_backend()
        if not backend:
            self.send_response(503)
            self.end_headers()
            self.wfile.write(b'No backends available')
            return
            
        try:
            # Forward request to backend
            response = urllib.request.urlopen(f"{backend}{self.path}", timeout=10)
            content = response.read()
            
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(content)
            
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(f"Backend error: {str(e)}".encode())

if __name__ == '__main__':
    # Add backends (discovered via DNS)
    try:
        # Resolve backend DNS to get all IPs
        backend_ips = socket.gethostbyname_ex('backend')[2]
        for ip in backend_ips:
            LoadBalancerHandler.lb.add_backend(ip, 80)
        print(f"Added {len(backend_ips)} backends")
    except:
        print("Could not resolve backends")
    
    server = HTTPServer(('0.0.0.0', 8080), LoadBalancerHandler)
    print("Load balancer running on port 8080")
    server.serve_forever()
EOF

# Create Dockerfile for load balancer
cat > Dockerfile.loadbalancer << 'EOF'
FROM python:3.11-alpine
COPY load_balancer.py /app/
WORKDIR /app
EXPOSE 8080
CMD ["python", "load_balancer.py"]
EOF

docker build -f Dockerfile.loadbalancer -t custom-lb .

# Deploy load balancer
docker run -d --name load-balancer \
  --network service-network \
  -p 8080:8080 \
  custom-lb
```

#### Step 3: Test Load Balancing

```bash
# Test load balancer
curl http://localhost:8080/health

# Create test backends with different responses
for i in {1..3}; do
  docker exec backend$i sh -c "echo 'Backend $i Response' > /usr/share/nginx/html/index.html"
done

# Test load balancing multiple times
for i in {1..10}; do
  echo "Request $i:"
  curl -s http://localhost:8080/
  echo ""
done
```

### Exercise 3: Network Isolation & Security

**Goal:** Implement network isolation and security best practices.

#### Step 1: Multi-Tier Network Architecture

```bash
# Create isolated networks for different tiers
docker network create \
  --driver bridge \
  --subnet=10.0.10.0/24 \
  frontend-tier

docker network create \
  --driver bridge \
  --subnet=10.0.20.0/24 \
  backend-tier

docker network create \
  --driver bridge \
  --subnet=10.0.30.0/24 \
  --internal \
  database-tier

# Deploy database (isolated)
docker run -d --name database \
  --network database-tier \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=myapp \
  postgres:13

# Deploy backend (can access database)
docker run -d --name backend-app \
  --network backend-tier \
  --network database-tier \
  -e DATABASE_URL=postgresql://postgres:secret@database:5432/myapp \
  nginx:alpine

# Deploy frontend (can access backend)
docker run -d --name frontend-app \
  --network frontend-tier \
  --network backend-tier \
  -p 80:80 \
  nginx:alpine

# Verify isolation
echo "Testing network isolation:"

# Frontend should NOT access database directly
docker exec frontend-app ping -c 1 database 2>/dev/null && echo "❌ Security breach!" || echo "✅ Database isolated from frontend"

# Backend SHOULD access database
docker exec backend-app ping -c 1 database 2>/dev/null && echo "✅ Backend can access database" || echo "❌ Backend cannot access database"

# Frontend SHOULD access backend
docker exec frontend-app ping -c 1 backend-app 2>/dev/null && echo "✅ Frontend can access backend" || echo "❌ Frontend cannot access backend"
```

#### Step 2: Container Firewall Rules

```bash
# Create network security script
cat > network-security.sh << 'EOF'
#!/bin/bash

echo "🔒 Applying network security rules..."

# Create custom chain for Docker
iptables -N DOCKER-SECURITY 2>/dev/null || true

# Allow established connections
iptables -A DOCKER-SECURITY -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow loopback
iptables -A DOCKER-SECURITY -i lo -j ACCEPT

# Frontend tier rules (10.0.10.0/24)
# Allow HTTP/HTTPS from external
iptables -A DOCKER-SECURITY -p tcp --dport 80 -j ACCEPT
iptables -A DOCKER-SECURITY -p tcp --dport 443 -j ACCEPT

# Allow frontend to backend communication
iptables -A DOCKER-SECURITY -s 10.0.10.0/24 -d 10.0.20.0/24 -j ACCEPT

# Backend tier rules (10.0.20.0/24)
# Allow backend to database communication
iptables -A DOCKER-SECURITY -s 10.0.20.0/24 -d 10.0.30.0/24 -p tcp --dport 5432 -j ACCEPT

# Database tier rules (10.0.30.0/24)
# Block all external access to database tier
iptables -A DOCKER-SECURITY -d 10.0.30.0/24 -j DROP

# Apply rules to Docker bridge
iptables -I DOCKER-USER -j DOCKER-SECURITY

echo "✅ Network security rules applied"
EOF

chmod +x network-security.sh
# sudo ./network-security.sh  # Uncomment to apply (requires root)
```

#### Step 3: TLS/SSL Between Containers

```bash
# Generate certificates for secure communication
mkdir -p certs
cd certs

# Create CA
openssl genrsa -out ca-key.pem 4096
openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem -subj "/C=US/ST=CA/L=SF/O=MyOrg/OU=IT/CN=MyCA"

# Create server certificate
openssl genrsa -out server-key.pem 4096
openssl req -subj "/CN=backend-secure" -sha256 -new -key server-key.pem -out server.csr
openssl x509 -req -days 365 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem -out server-cert.pem -CAcreateserial

# Create client certificate
openssl genrsa -out client-key.pem 4096
openssl req -subj "/CN=frontend-client" -new -key client-key.pem -out client.csr
openssl x509 -req -days 365 -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem -out client-cert.pem -CAcreateserial

cd ..

# Create secure backend
cat > secure-backend.py << 'EOF'
#!/usr/bin/env python3
import ssl
import socket
from http.server import HTTPServer, BaseHTTPRequestHandler

class SecureBackendHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        response = {
            'message': 'Secure backend response',
            'client_cert': self.headers.get('X-Client-Cert', 'None'),
            'secure': True
        }
        self.wfile.write(str(response).encode())

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8443), SecureBackendHandler)
    
    # Configure SSL
    context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    context.load_cert_chain('/app/certs/server-cert.pem', '/app/certs/server-key.pem')
    context.load_verify_locations('/app/certs/ca.pem')
    context.verify_mode = ssl.CERT_REQUIRED
    
    server.socket = context.wrap_socket(server.socket, server_side=True)
    
    print("Secure backend running on port 8443")
    server.serve_forever()
EOF

cat > Dockerfile.secure << 'EOF'
FROM python:3.11-alpine
RUN apk add --no-cache openssl
COPY secure-backend.py /app/
COPY certs/ /app/certs/
WORKDIR /app
EXPOSE 8443
CMD ["python", "secure-backend.py"]
EOF

# Build and deploy secure backend
docker build -f Dockerfile.secure -t secure-backend .

docker run -d --name secure-backend \
  --network backend-tier \
  secure-backend
```

### Exercise 4: Network Monitoring & Troubleshooting

**Goal:** Monitor network traffic and troubleshoot connectivity issues.

#### Step 1: Network Monitoring Setup

```python
# Create network monitoring script
cat > network_monitor.py << 'EOF'
#!/usr/bin/env python3
import docker
import time
import json
import threading
from datetime import datetime

class NetworkMonitor:
    def __init__(self):
        self.client = docker.from_env()
        self.monitoring = True
        
    def get_container_networks(self, container):
        """Get network information for container"""
        try:
            networks = container.attrs['NetworkSettings']['Networks']
            network_info = []
            
            for net_name, net_config in networks.items():
                network_info.append({
                    'network': net_name,
                    'ip_address': net_config['IPAddress'],
                    'gateway': net_config['Gateway'],
                    'mac_address': net_config['MacAddress']
                })
            
            return network_info
        except Exception as e:
            return [{'error': str(e)}]
    
    def get_network_stats(self, container):
        """Get network statistics"""
        try:
            stats = container.stats(stream=False)
            networks = stats.get('networks', {})
            
            total_rx = sum(net.get('rx_bytes', 0) for net in networks.values())
            total_tx = sum(net.get('tx_bytes', 0) for net in networks.values())
            
            return {
                'rx_bytes': total_rx,
                'tx_bytes': total_tx,
                'rx_packets': sum(net.get('rx_packets', 0) for net in networks.values()),
                'tx_packets': sum(net.get('tx_packets', 0) for net in networks.values()),
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            return {'error': str(e)}
    
    def test_connectivity(self, source_container, targets):
        """Test connectivity to multiple targets"""
        results = []
        
        for target in targets:
            try:
                result = source_container.exec_run(
                    f"ping -c 3 -W 2 {target}",
                    stdout=True,
                    stderr=True
                )
                
                success = result.exit_code == 0
                output = result.output.decode()
                
                # Parse ping statistics
                avg_time = None
                if success and 'min/avg/max' in output:
                    for line in output.split('\n'):
                        if 'min/avg/max' in line:
                            avg_time = float(line.split('/')[1])
                            break
                
                results.append({
                    'target': target,
                    'success': success,
                    'avg_time_ms': avg_time,
                    'details': output.split('\n')[-2] if success else output
                })
                
            except Exception as e:
                results.append({
                    'target': target,
                    'success': False,
                    'error': str(e)
                })
        
        return results
    
    def monitor_networks(self, interval=30):
        """Continuous network monitoring"""
        print(f"🔍 Starting network monitoring (interval: {interval}s)")
        
        while self.monitoring:
            try:
                containers = self.client.containers.list()
                timestamp = datetime.now().strftime('%H:%M:%S')
                
                print(f"\n📊 Network Status Report - {timestamp}")
                print("-" * 60)
                
                for container in containers:
                    print(f"\n📦 Container: {container.name}")
                    
                    # Network configuration
                    networks = self.get_container_networks(container)
                    for net_info in networks:
                        if 'error' not in net_info:
                            print(f"   🌐 Network: {net_info['network']}")
                            print(f"   📍 IP: {net_info['ip_address']}")
                            print(f"   🚪 Gateway: {net_info['gateway']}")
                    
                    # Network statistics
                    stats = self.get_network_stats(container)
                    if 'error' not in stats:
                        rx_mb = stats['rx_bytes'] / (1024 * 1024)
                        tx_mb = stats['tx_bytes'] / (1024 * 1024)
                        print(f"   📈 Traffic: RX {rx_mb:.2f}MB, TX {tx_mb:.2f}MB")
                
                # Connectivity tests
                if containers:
                    test_container = containers[0]
                    targets = [c.name for c in containers[1:3]]  # Test first few
                    
                    if targets:
                        print(f"\n🔗 Connectivity Test from {test_container.name}:")
                        connectivity = self.test_connectivity(test_container, targets)
                        
                        for result in connectivity:
                            status = "✅" if result['success'] else "❌"
                            time_info = f" ({result['avg_time_ms']:.1f}ms)" if result.get('avg_time_ms') else ""
                            print(f"   {status} {result['target']}{time_info}")
                
                time.sleep(interval)
                
            except KeyboardInterrupt:
                print("\n👋 Monitoring stopped by user")
                self.monitoring = False
            except Exception as e:
                print(f"❌ Monitoring error: {e}")
                time.sleep(interval)

if __name__ == "__main__":
    monitor = NetworkMonitor()
    monitor.monitor_networks(30)
EOF

chmod +x network_monitor.py
```

#### Step 2: Network Troubleshooting Script

```bash
# Create comprehensive troubleshooting script
cat > network_troubleshoot.sh << 'EOF'
#!/bin/bash

CONTAINER_NAME=${1:-""}

if [[ -z "$CONTAINER_NAME" ]]; then
    echo "Usage: $0 <container-name>"
    echo "Available containers:"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
    exit 1
fi

echo "🔍 Network Troubleshooting for: $CONTAINER_NAME"
echo "================================================="

# Check if container exists and is running
if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container $CONTAINER_NAME is not running"
    exit 1
fi

echo "✅ Container is running"
echo ""

# Container network configuration
echo "🌐 Network Configuration:"
echo "------------------------"
docker inspect $CONTAINER_NAME --format='{{range $net, $conf := .NetworkSettings.Networks}}Network: {{$net}}
  IP Address: {{$conf.IPAddress}}
  Gateway: {{$conf.Gateway}}
  MAC Address: {{$conf.MacAddress}}
  Subnet: {{$conf.IPPrefixLen}}{{"\n"}}{{end}}'

# Port bindings
echo "🔌 Port Bindings:"
echo "----------------"
docker port $CONTAINER_NAME 2>/dev/null || echo "No port bindings configured"
echo ""

# Network interfaces inside container
echo "🔧 Network Interfaces:"
echo "---------------------"
docker exec $CONTAINER_NAME ip addr show 2>/dev/null || echo "Cannot access container network interfaces"
echo ""

# Routing table
echo "🗺️ Routing Table:"
echo "----------------"
docker exec $CONTAINER_NAME ip route show 2>/dev/null || echo "Cannot access container routing table"
echo ""

# DNS configuration
echo "🌍 DNS Configuration:"
echo "--------------------"
docker exec $CONTAINER_NAME cat /etc/resolv.conf 2>/dev/null || echo "Cannot access DNS configuration"
echo ""

# Test external connectivity
echo "🌐 External Connectivity Tests:"
echo "-------------------------------"
echo "Testing Google DNS (8.8.8.8):"
docker exec $CONTAINER_NAME ping -c 3 8.8.8.8 2>/dev/null || echo "❌ Cannot reach external network"

echo ""
echo "Testing DNS resolution:"
docker exec $CONTAINER_NAME nslookup google.com 2>/dev/null || echo "❌ DNS resolution failed"

# Test container-to-container connectivity
echo ""
echo "🔗 Container-to-Container Connectivity:"
echo "---------------------------------------"
OTHER_CONTAINERS=$(docker ps --format "{{.Names}}" | grep -v "^${CONTAINER_NAME}$" | head -3)

if [[ -n "$OTHER_CONTAINERS" ]]; then
    for target in $OTHER_CONTAINERS; do
        echo "Testing connection to $target:"
        docker exec $CONTAINER_NAME ping -c 2 $target 2>/dev/null && echo "✅ $target reachable" || echo "❌ $target unreachable"
    done
else
    echo "No other containers to test"
fi

# Network processes
echo ""
echo "🔗 Network Connections:"
echo "----------------------"
docker exec $CONTAINER_NAME netstat -tuln 2>/dev/null || docker exec $CONTAINER_NAME ss -tuln 2>/dev/null || echo "Cannot access network connections"

# Container processes
echo ""
echo "⚙️ Running Processes:"
echo "-------------------"
docker exec $CONTAINER_NAME ps aux 2>/dev/null || echo "Cannot access process list"

echo ""
echo "✅ Network troubleshooting complete!"
EOF

chmod +x network_troubleshoot.sh
```

#### Step 3: Performance Testing

```bash
# Create network performance test
cat > network_performance_test.sh << 'EOF'
#!/bin/bash

echo "🚀 Network Performance Test"
echo "=========================="

# Create test network
docker network create --driver bridge perf-test-network

# Create iperf3 server container
docker run -d --name iperf-server \
  --network perf-test-network \
  networkstatic/iperf3:latest -s

# Wait for server to start
sleep 5

# Create iperf3 client and run tests
echo "📊 Running bandwidth test..."
docker run --rm --name iperf-client \
  --network perf-test-network \
  networkstatic/iperf3:latest \
  -c iperf-server -t 10 -P 4

echo ""
echo "📡 Running latency test..."
docker run --rm --network perf-test-network alpine \
  ping -c 20 iperf-server

echo ""
echo "🔄 Running UDP performance test..."
docker run --rm --name iperf-client-udp \
  --network perf-test-network \
  networkstatic/iperf3:latest \
  -c iperf-server -u -b 1000M -t 10

# Cleanup
docker stop iperf-server
docker rm iperf-server
docker network rm perf-test-network

echo "✅ Performance test complete!"
EOF

chmod +x network_performance_test.sh
```

## ✅ Lab Verification

### Verification Steps

1. **Custom Network Verification:**
   ```bash
   # Verify custom networks exist
   docker network ls | grep -E "(custom-network|production-network)"
   
   # Test container communication
   docker exec web1 ping -c 3 web2
   ```

2. **Service Discovery Verification:**
   ```bash
   # Test DNS resolution
   docker exec client nslookup backend
   
   # Test load balancer
   curl http://localhost:8080/health
   ```

3. **Network Isolation Verification:**
   ```bash
   # Verify database isolation
   docker exec frontend-app ping -c 1 database 2>/dev/null && echo "FAIL" || echo "PASS"
   ```

4. **Monitoring Verification:**
   ```bash
   # Run monitoring script
   python3 network_monitor.py &
   MONITOR_PID=$!
   sleep 60
   kill $MONITOR_PID
   ```

### Expected Outcomes

- Custom networks should provide proper isolation and configuration
- Service discovery should work through DNS resolution
- Load balancing should distribute requests across backends
- Network isolation should prevent unauthorized access
- Monitoring should provide real-time network statistics

## 🧹 Cleanup

```bash
# Stop and remove all lab containers
docker stop $(docker ps -aq --filter "name=web") 2>/dev/null || true
docker stop $(docker ps -aq --filter "name=backend") 2>/dev/null || true
docker stop $(docker ps -aq --filter "name=frontend") 2>/dev/null || true
docker stop $(docker ps -aq --filter "name=database") 2>/dev/null || true
docker stop $(docker ps -aq --filter "name=client") 2>/dev/null || true
docker stop $(docker ps -aq --filter "name=load-balancer") 2>/dev/null || true
docker stop $(docker ps -aq --filter "name=secure-backend") 2>/dev/null || true

docker rm $(docker ps -aq --filter "name=web") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=backend") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=frontend") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=database") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=client") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=load-balancer") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=secure-backend") 2>/dev/null || true

# Remove lab networks
docker network rm lab-network custom-network production-network 2>/dev/null || true
docker network rm service-network frontend-tier backend-tier database-tier 2>/dev/null || true

# Remove lab images
docker rmi custom-lb secure-backend 2>/dev/null || true

# Remove lab files
rm -f load_balancer.py secure-backend.py network_monitor.py
rm -f Dockerfile.loadbalancer Dockerfile.secure
rm -f network-security.sh network_troubleshoot.sh network_performance_test.sh
rm -rf certs/

echo "🧹 Lab cleanup completed!"
```

## 📚 Additional Challenges

1. **Create a service mesh** using Consul Connect or Istio sidecar proxies
2. **Implement network policies** using Calico or Weave Net
3. **Set up cross-host networking** using Docker Swarm overlay networks
4. **Create a monitoring dashboard** for network metrics using Grafana
5. **Implement zero-downtime deployments** using blue-green networking patterns

## 🎯 Lab Summary

In this lab, you:
- ✅ Created and configured custom Docker networks
- ✅ Implemented service discovery and load balancing
- ✅ Set up network isolation and security
- ✅ Built monitoring and troubleshooting tools
- ✅ Tested network performance and connectivity

**🎉 Congratulations!** You've mastered advanced Docker networking concepts essential for production deployments.

---

**[⬅️ Back to Chapter 04](../README.md)** | **[Next: Checkpoint ➡️](../checkpoint.md)** 