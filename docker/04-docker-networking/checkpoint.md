# 🎯 Chapter 04 Checkpoint: Advanced Docker Networking

Test your understanding of Docker networking concepts, custom networks, service discovery, and network security.

## 📝 Knowledge Assessment

### Section A: Network Architecture (25 points)

**Question 1 (5 points):** Explain the difference between Docker's default bridge network and custom bridge networks.

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Default Bridge Network:**
  - All containers use docker0 bridge (172.17.0.0/16)
  - No automatic service discovery (containers communicate by IP only)
  - Limited network isolation
  - Cannot customize network settings

- **Custom Bridge Networks:**
  - User-defined subnets and IP ranges
  - Automatic DNS-based service discovery
  - Better network isolation
  - Customizable network settings (MTU, bridge name, etc.)
  - Container-to-container communication by name
</details>

---

**Question 2 (5 points):** What are the main Docker network drivers and when would you use each?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Bridge:** Single-host networking with isolation (default, most common)
- **Host:** Container shares host network stack (high performance, less isolation)
- **None:** No networking (completely isolated containers)
- **Overlay:** Multi-host networking for distributed applications
- **Macvlan:** Direct access to physical network (appears as physical device)
- **IPvlan:** Layer 3 routing with better performance than macvlan
</details>

---

**Question 3 (5 points):** How does Docker implement network isolation and what Linux technologies are used?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Network Namespaces:** Isolate network interfaces, routing tables, firewall rules
- **Virtual Ethernet (veth) pairs:** Connect container namespace to bridge
- **Linux Bridge:** Virtual switch for container communication
- **iptables:** Firewall rules for traffic filtering and NAT
- **IPVS/netfilter:** Load balancing and traffic management
</details>

---

**Question 4 (5 points):** Write Docker commands to create a custom network with specific subnet and gateway configuration.

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
docker network create \
  --driver bridge \
  --subnet=192.168.10.0/24 \
  --gateway=192.168.10.1 \
  --ip-range=192.168.10.0/28 \
  --opt com.docker.network.bridge.name=custom-br0 \
  --opt com.docker.network.bridge.enable_icc=true \
  --opt com.docker.network.driver.mtu=1500 \
  custom-network
```
</details>

---

**Question 5 (5 points):** What is the purpose of the `--internal` flag when creating Docker networks?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Internal networks** have no access to external networks
- Containers can only communicate with other containers on the same internal network
- No NAT or routing to external interfaces
- Used for database or backend tiers that should be completely isolated
- Provides additional security by preventing external access
</details>

---

### Section B: Service Discovery & Load Balancing (25 points)

**Question 6 (5 points):** How does Docker's built-in service discovery work in custom networks?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Embedded DNS Server:** Docker runs DNS server at 127.0.0.11
- **Container Names:** Containers can resolve each other by name
- **Network Aliases:** Multiple containers can share the same alias
- **Round-Robin DNS:** Multiple containers with same alias return multiple IPs
- **Automatic Updates:** DNS records updated when containers start/stop
</details>

---

**Question 7 (5 points):** What are network aliases and how do they enable load balancing?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Create containers with same network alias
docker run -d --name web1 --network mynet --network-alias webserver nginx
docker run -d --name web2 --network mynet --network-alias webserver nginx
docker run -d --name web3 --network mynet --network-alias webserver nginx

# DNS lookup returns multiple IPs (round-robin)
nslookup webserver  # Returns IPs of web1, web2, web3
```
- Multiple containers can share the same network alias
- DNS queries return all IP addresses
- Client applications get different IPs on each lookup (round-robin)
</details>

---

**Question 8 (10 points):** Design a load balancing solution for a web application with multiple backend services. Include network topology and configuration.

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Network topology
docker network create frontend-net
docker network create backend-net

# Backend services
for i in {1..3}; do
  docker run -d --name backend-$i \
    --network backend-net \
    --network-alias backend \
    -e SERVICE_ID=$i \
    myapp:backend
done

# Load balancer (HAProxy/NGINX)
docker run -d --name load-balancer \
  --network frontend-net \
  --network backend-net \
  -p 80:80 \
  -v $(pwd)/lb-config:/etc/haproxy:ro \
  haproxy:latest

# Frontend application
docker run -d --name frontend \
  --network frontend-net \
  -p 443:443 \
  myapp:frontend
```

**Architecture:**
- Frontend network: External access
- Backend network: Internal services
- Load balancer: Bridges both networks
- Service discovery: DNS-based backend resolution
</details>

---

**Question 9 (5 points):** What are the limitations of Docker's built-in load balancing and when would you use external load balancers?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
**Built-in Limitations:**
- Simple round-robin only (no weighted, least connections, etc.)
- No health checking
- No session persistence
- No advanced routing rules
- DNS-based (client-side load balancing)

**External Load Balancers Needed For:**
- Health checks and automatic failover
- Advanced algorithms (weighted, least connections)
- SSL termination
- Session persistence/sticky sessions
- Traffic shaping and rate limiting
- Advanced monitoring and metrics
</details>

---

### Section C: Network Security (25 points)

**Question 10 (5 points):** How do you implement network isolation for a multi-tier application?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Create isolated networks
docker network create frontend-tier
docker network create backend-tier  
docker network create --internal database-tier

# Frontend (public access)
docker run -d --name web \
  --network frontend-tier \
  --network backend-tier \
  -p 80:80 myapp:web

# Backend (no external access)
docker run -d --name api \
  --network backend-tier \
  --network database-tier \
  myapp:api

# Database (completely isolated)
docker run -d --name db \
  --network database-tier \
  postgres:13
```

**Isolation achieved:**
- Frontend can't access database directly
- Database has no external connectivity
- Backend accessible only from frontend
</details>

---

**Question 11 (5 points):** What security considerations should you implement for container networking?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Network Segmentation:** Separate networks for different tiers
- **Principle of Least Privilege:** Only necessary connections allowed
- **Internal Networks:** Use `--internal` for backend services
- **TLS/SSL:** Encrypt inter-container communication
- **Firewall Rules:** Custom iptables rules for additional security
- **Non-root Users:** Run containers as non-root
- **Secret Management:** Secure handling of certificates and keys
- **Regular Updates:** Keep base images and dependencies updated
</details>

---

**Question 12 (5 points):** How do you configure TLS encryption between containers?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Generate certificates
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Server container with TLS
docker run -d --name secure-api \
  --network secure-net \
  -v $(pwd)/cert.pem:/app/cert.pem:ro \
  -v $(pwd)/key.pem:/app/key.pem:ro \
  -e TLS_CERT=/app/cert.pem \
  -e TLS_KEY=/app/key.pem \
  myapp:secure-api

# Client container with CA cert
docker run -d --name secure-client \
  --network secure-net \
  -v $(pwd)/cert.pem:/app/ca.pem:ro \
  -e API_URL=https://secure-api:8443 \
  -e CA_CERT=/app/ca.pem \
  myapp:secure-client
```
</details>

---

**Question 13 (10 points):** Design and implement firewall rules for a containerized application with the following requirements:
- Web tier: Accessible from internet (ports 80, 443)
- API tier: Accessible only from web tier
- Database tier: Accessible only from API tier
- Block all other traffic

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
#!/bin/bash
# Container firewall configuration

# Network definitions
FRONTEND_NET="10.0.1.0/24"    # Web tier
BACKEND_NET="10.0.2.0/24"     # API tier  
DATABASE_NET="10.0.3.0/24"    # Database tier

# Create custom chain
iptables -N CONTAINER-FIREWALL

# Default deny
iptables -A CONTAINER-FIREWALL -j DROP

# Allow established connections
iptables -I CONTAINER-FIREWALL -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow loopback
iptables -I CONTAINER-FIREWALL -i lo -j ACCEPT

# Web tier rules
# Allow HTTP/HTTPS from anywhere to frontend
iptables -I CONTAINER-FIREWALL -d $FRONTEND_NET -p tcp --dport 80 -j ACCEPT
iptables -I CONTAINER-FIREWALL -d $FRONTEND_NET -p tcp --dport 443 -j ACCEPT

# Allow frontend to backend communication
iptables -I CONTAINER-FIREWALL -s $FRONTEND_NET -d $BACKEND_NET -j ACCEPT

# Allow backend to database communication  
iptables -I CONTAINER-FIREWALL -s $BACKEND_NET -d $DATABASE_NET -p tcp --dport 5432 -j ACCEPT

# Apply to Docker
iptables -I DOCKER-USER -j CONTAINER-FIREWALL

echo "Firewall rules applied successfully"
```
</details>

---

### Section D: Troubleshooting & Monitoring (25 points)

**Question 14 (5 points):** What steps would you take to troubleshoot container connectivity issues?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
1. **Check container status:** `docker ps`, `docker logs`
2. **Verify network configuration:** `docker network inspect`, `docker inspect container`
3. **Test basic connectivity:** `docker exec container ping target`
4. **Check DNS resolution:** `docker exec container nslookup target`
5. **Verify port bindings:** `docker port container`
6. **Check network interfaces:** `docker exec container ip addr show`
7. **Test routing:** `docker exec container ip route show`
8. **Check firewall rules:** `iptables -L`, security groups
9. **Verify service configuration:** Application logs, configuration files
10. **Network monitoring:** Traffic analysis, packet capture
</details>

---

**Question 15 (5 points):** How do you monitor Docker network performance and traffic?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Container network statistics
docker stats --format "table {{.Container}}\t{{.NetIO}}"

# Network interface monitoring
docker exec container cat /proc/net/dev

# Real-time traffic monitoring
docker exec container netstat -i

# Packet capture
docker exec container tcpdump -i eth0

# iperf3 bandwidth testing
docker run --rm --name iperf-client \
  --network test-net \
  networkstatic/iperf3 -c server-container

# Custom monitoring scripts
# Network stats from Docker API
# Prometheus/Grafana for metrics
# ELK stack for log analysis
```
</details>

---

**Question 16 (5 points):** A container cannot reach external services but can communicate with other containers. What could be the issue and how would you debug it?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
**Possible Issues:**
- DNS resolution problems
- NAT/masquerading configuration
- Firewall blocking external traffic
- Proxy configuration
- Network routing issues

**Debugging Steps:**
```bash
# Test external IP (bypasses DNS)
docker exec container ping 8.8.8.8

# Test DNS resolution
docker exec container nslookup google.com

# Check DNS configuration
docker exec container cat /etc/resolv.conf

# Check routing table
docker exec container ip route show

# Test with different DNS
docker exec container nslookup google.com 8.8.8.8

# Check host connectivity
ping 8.8.8.8  # From host

# Verify iptables NAT rules
iptables -t nat -L

# Check Docker daemon configuration
# /etc/docker/daemon.json for DNS settings
```
</details>

---

**Question 17 (10 points):** Write a comprehensive network monitoring script that:
- Lists all networks and their containers
- Tests connectivity between containers
- Monitors network traffic
- Generates a health report

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```python
#!/usr/bin/env python3
import docker
import subprocess
import time
import json
from datetime import datetime

class NetworkMonitor:
    def __init__(self):
        self.client = docker.from_env()
    
    def get_network_topology(self):
        """Get all networks and their containers"""
        topology = {}
        for network in self.client.networks.list():
            if network.name in ['bridge', 'host', 'none']:
                continue
            
            containers = []
            for container_id, info in network.attrs.get('Containers', {}).items():
                try:
                    container = self.client.containers.get(container_id)
                    containers.append({
                        'name': container.name,
                        'ip': info['IPv4Address'].split('/')[0],
                        'status': container.status
                    })
                except:
                    pass
            
            topology[network.name] = {
                'driver': network.attrs['Driver'],
                'subnet': network.attrs['IPAM']['Config'][0]['Subnet'] if network.attrs['IPAM']['Config'] else 'N/A',
                'containers': containers
            }
        
        return topology
    
    def test_connectivity(self):
        """Test connectivity between containers"""
        results = []
        containers = self.client.containers.list()
        
        for i, source in enumerate(containers):
            for target in containers[i+1:]:
                try:
                    result = source.exec_run(f"ping -c 3 {target.name}", timeout=10)
                    success = result.exit_code == 0
                    results.append({
                        'source': source.name,
                        'target': target.name,
                        'success': success,
                        'timestamp': datetime.now().isoformat()
                    })
                except:
                    results.append({
                        'source': source.name,
                        'target': target.name,
                        'success': False,
                        'error': 'Connection failed'
                    })
        
        return results
    
    def get_traffic_stats(self):
        """Get network traffic statistics"""
        stats = []
        for container in self.client.containers.list():
            try:
                container_stats = container.stats(stream=False)
                networks = container_stats.get('networks', {})
                
                total_rx = sum(net.get('rx_bytes', 0) for net in networks.values())
                total_tx = sum(net.get('tx_bytes', 0) for net in networks.values())
                
                stats.append({
                    'container': container.name,
                    'rx_bytes': total_rx,
                    'tx_bytes': total_tx,
                    'rx_mb': round(total_rx / (1024*1024), 2),
                    'tx_mb': round(total_tx / (1024*1024), 2)
                })
            except:
                pass
        
        return stats
    
    def generate_health_report(self):
        """Generate comprehensive health report"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'topology': self.get_network_topology(),
            'connectivity': self.test_connectivity(),
            'traffic_stats': self.get_traffic_stats()
        }
        
        # Calculate health score
        connectivity_tests = report['connectivity']
        if connectivity_tests:
            success_rate = sum(1 for test in connectivity_tests if test['success']) / len(connectivity_tests)
            report['health_score'] = round(success_rate * 100, 1)
        else:
            report['health_score'] = 100.0
        
        return report

if __name__ == "__main__":
    monitor = NetworkMonitor()
    report = monitor.generate_health_report()
    
    # Print summary
    print("🌐 Network Health Report")
    print("=" * 40)
    print(f"Health Score: {report['health_score']}%")
    print(f"Networks: {len(report['topology'])}")
    print(f"Connectivity Tests: {len(report['connectivity'])}")
    
    # Save detailed report
    with open(f"network-health-{int(time.time())}.json", 'w') as f:
        json.dump(report, f, indent=2)
    
    print("✅ Detailed report saved to file")
```
</details>

---

## 🛠️ Practical Exercises

### Exercise 1: Multi-Tier Network Design (20 points)

Design and implement a secure three-tier network architecture:

1. **Frontend Tier (5 points):** Web servers accessible from internet
2. **Backend Tier (5 points):** API servers accessible only from frontend
3. **Database Tier (5 points):** Database accessible only from backend
4. **Security Rules (5 points):** Implement firewall rules to enforce isolation

### Exercise 2: Service Discovery Implementation (20 points)

1. **DNS-based Discovery (5 points):** Configure automatic service discovery using network aliases
2. **Health Checking (5 points):** Implement health checks for service availability
3. **Load Balancing (5 points):** Create custom load balancer with multiple algorithms
4. **Failover Testing (5 points):** Test automatic failover when services become unavailable

### Exercise 3: Network Monitoring System (20 points)

1. **Real-time Monitoring (10 points):** Create monitoring dashboard for network metrics
2. **Performance Testing (5 points):** Implement bandwidth and latency testing
3. **Alert System (5 points):** Configure alerts for network issues

### Exercise 4: Troubleshooting Scenarios (20 points)

Diagnose and fix these networking issues:

1. **DNS Resolution Failure (5 points):** Container cannot resolve service names
2. **External Connectivity Loss (5 points):** Container cannot reach external services
3. **Intermittent Connectivity (5 points):** Sporadic connection failures between containers
4. **Performance Degradation (5 points):** Slow network performance between services

## 🎯 Scoring Rubric

| Score Range | Level | Description |
|-------------|-------|-------------|
| 90-100 | Expert | Advanced networking mastery, production-ready solutions |
| 80-89 | Advanced | Strong networking skills with minor gaps |
| 70-79 | Intermediate | Good understanding, needs practice |
| 60-69 | Beginner | Basic concepts understood, significant practice needed |
| Below 60 | Needs Review | Review chapter material and retry |

## ✅ Self-Assessment Checklist

Before proceeding to Chapter 5, ensure you can:

- [ ] Create and configure custom Docker networks
- [ ] Implement service discovery using DNS and network aliases
- [ ] Design multi-tier network architectures with proper isolation
- [ ] Configure load balancing for containerized applications
- [ ] Implement network security best practices
- [ ] Troubleshoot complex networking issues
- [ ] Monitor network performance and traffic
- [ ] Set up TLS encryption between containers

## 🚀 Preparation for Next Chapter

Chapter 5 (Docker Storage) builds on these concepts:
- Understanding of container isolation
- Network-attached storage concepts
- Multi-container application architecture
- Production deployment patterns

## 📚 Additional Resources

- [Docker Network Documentation](https://docs.docker.com/network/)
- [Container Network Interface (CNI)](https://github.com/containernetworking/cni)
- [Docker Networking Best Practices](https://docs.docker.com/network/best-practices/)
- [Network Security for Containers](https://docs.docker.com/engine/security/)

---

**🎉 Checkpoint Complete!** 

**Score: ___/100**

If you scored 80+, you're ready for [Chapter 05: Docker Storage](../05-docker-storage/README.md).
If you scored below 80, review the chapter materials and retry the assessment.

---

**[⬅️ Back to Chapter 04](../README.md)** | **[Next: Docker Storage ➡️](../05-docker-storage/README.md)** 