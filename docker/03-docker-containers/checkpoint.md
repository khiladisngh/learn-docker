# 🎯 Chapter 03 Checkpoint: Advanced Container Management

Test your understanding of advanced Docker container management concepts and practical skills.

## 📝 Knowledge Assessment

### Section A: Container Architecture (25 points)

**Question 1 (5 points):** What are the key differences between Docker containers and virtual machines in terms of resource usage and isolation?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Containers:** Share host OS kernel, lighter weight, process-level isolation using namespaces and cgroups
- **Virtual Machines:** Each VM includes full guest OS, heavier resource usage, hardware-level isolation
- **Resource Usage:** Containers use less memory/CPU overhead, faster startup times
- **Isolation:** VMs provide stronger isolation, containers provide sufficient isolation for most use cases
</details>

---

**Question 2 (5 points):** Explain the role of Linux namespaces and control groups (cgroups) in container isolation.

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Namespaces provide isolation:**
  - PID: Process ID isolation
  - NET: Network interface isolation
  - MNT: Mount point isolation
  - UTS: Hostname isolation
  - IPC: Inter-process communication isolation
  - USER: User and group ID isolation

- **Control Groups (cgroups) provide resource limits:**
  - CPU: Processing power limits
  - Memory: RAM usage limits
  - Block I/O: Disk operation limits
  - Network: Bandwidth limits
</details>

---

**Question 3 (5 points):** What are the different container lifecycle states and how do you transition between them?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **States:** Created → Running → Paused → Stopped → Removed
- **Transitions:**
  - `docker create` → Created
  - `docker start` → Running
  - `docker pause` → Paused
  - `docker unpause` → Running
  - `docker stop` → Stopped
  - `docker rm` → Removed
</details>

---

**Question 4 (5 points):** How do you configure memory limits and what happens when a container exceeds them?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Memory limit configuration
docker run --memory=512m myapp

# Additional memory options
docker run --memory=512m --memory-swap=1g --memory-swappiness=60 myapp

# OOM kill protection (use carefully)
docker run --memory=256m --oom-kill-disable myapp
```

**When exceeded:** Container gets killed by OOM (Out of Memory) killer with exit code 137
</details>

---

**Question 5 (5 points):** What are the different Docker networking modes and when would you use each?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Bridge (default):** Isolated network with port mapping, good for single-host applications
- **Host:** Shares host network stack, best performance but less isolation
- **None:** No network access, for completely isolated applications
- **Container:** Shares network with another container, useful for sidecar patterns
- **Custom networks:** User-defined networks for better container communication
</details>

---

### Section B: Resource Management (25 points)

**Question 6 (5 points):** Write Docker commands to run a container with the following resource constraints:
- Maximum 2 CPU cores
- 1GB memory limit
- CPU pinned to cores 0 and 1
- Block I/O read limit of 10MB/s

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
docker run -d \
  --cpus="2" \
  --memory=1g \
  --cpuset-cpus="0,1" \
  --device-read-bps /dev/sda:10mb \
  myapp:latest
```
</details>

---

**Question 7 (5 points):** How do you monitor real-time resource usage of containers and what key metrics should you track?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Real-time monitoring
docker stats
docker stats mycontainer --no-stream

# Key metrics to track:
# - CPU percentage
# - Memory usage and percentage
# - Network I/O (RX/TX)
# - Block I/O (read/write)
# - PIDs (process count)
```
</details>

---

**Question 8 (5 points):** What's the difference between `--cpu-shares` and `--cpus` options?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **`--cpus`:** Hard limit on CPU cores (e.g., `--cpus="1.5"` = max 1.5 cores)
- **`--cpu-shares`:** Relative weight for CPU scheduling (default 1024, higher = more priority)
- **Usage:** `--cpus` for absolute limits, `--cpu-shares` for relative prioritization
</details>

---

**Question 9 (5 points):** How do you implement CPU pinning and when is it beneficial?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# CPU pinning to specific cores
docker run --cpuset-cpus="0,1,2" myapp
docker run --cpuset-cpus="0-3" myapp

# Memory node pinning (NUMA)
docker run --cpuset-mems="0" myapp

# Benefits: Reduces context switching, better cache locality, predictable performance
```
</details>

---

**Question 10 (5 points):** Explain memory reservation vs memory limit in Docker.

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Memory Limit (`--memory`):** Hard limit, container killed if exceeded
- **Memory Reservation (`--memory-reservation`):** Soft limit, suggestion for scheduler
- **Usage:** Reservation for flexible allocation, limit for protection
```bash
docker run --memory=1g --memory-reservation=512m myapp
```
</details>

---

### Section C: Health Checks & Monitoring (25 points)

**Question 11 (5 points):** Write a Dockerfile with a comprehensive health check for a web application.

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```dockerfile
FROM node:16-alpine

# Install curl for health checks
RUN apk add --no-cache curl

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .

# Comprehensive health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000
CMD ["node", "server.js"]
```
</details>

---

**Question 12 (5 points):** How do you check the health status of a container and view health check logs?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Check health status
docker inspect mycontainer --format='{{.State.Health.Status}}'

# View health check details
docker inspect mycontainer --format='{{json .State.Health}}' | jq .

# View health check logs
docker inspect mycontainer --format='{{range .State.Health.Log}}{{.Output}}{{end}}'

# Monitor health in ps output
docker ps --format "table {{.Names}}\t{{.Status}}"
```
</details>

---

**Question 13 (5 points):** What are the different health check states and what do they mean?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **starting:** Health checks haven't started yet (within start-period)
- **healthy:** All health checks are passing
- **unhealthy:** Health checks are failing (exceeded retries)
- **none:** No health check configured

**Transition:** starting → healthy/unhealthy → healthy/unhealthy (ongoing)
</details>

---

**Question 14 (10 points):** Write a Python script that monitors container health and sends alerts for unhealthy containers.

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```python
import docker
import time
from datetime import datetime

class HealthMonitor:
    def __init__(self):
        self.client = docker.from_env()
        self.unhealthy_containers = set()
    
    def check_health(self, container):
        health = container.attrs['State'].get('Health', {})
        return health.get('Status', 'none')
    
    def send_alert(self, container_name, status):
        print(f"🚨 ALERT: {container_name} is {status} at {datetime.now()}")
        # Add email/webhook notification here
    
    def monitor(self):
        for container in self.client.containers.list():
            status = self.check_health(container)
            
            if status == 'unhealthy':
                if container.name not in self.unhealthy_containers:
                    self.send_alert(container.name, status)
                    self.unhealthy_containers.add(container.name)
            else:
                self.unhealthy_containers.discard(container.name)

monitor = HealthMonitor()
while True:
    monitor.monitor()
    time.sleep(30)
```
</details>

---

### Section D: Troubleshooting & Debugging (25 points)

**Question 15 (5 points):** A container exits immediately with code 127. What does this indicate and how do you debug it?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Exit code 127:** Command not found
- **Debug steps:**
```bash
# Check logs
docker logs mycontainer

# Inspect configuration
docker inspect mycontainer --format='{{.Config.Cmd}}'

# Test interactively
docker run -it --rm --entrypoint="" myimage sh

# Common causes: Typo in command, missing executable, wrong PATH
```
</details>

---

**Question 16 (5 points):** How do you debug a container that's consuming too much memory?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Check memory usage
docker stats mycontainer

# Inspect memory limit
docker inspect mycontainer --format='{{.HostConfig.Memory}}'

# Check for memory leaks
docker exec mycontainer ps aux --sort=-%mem

# Monitor memory over time
docker stats mycontainer --format "table {{.MemUsage}}\t{{.MemPerc}}"

# Check system memory events
dmesg | grep -i "killed process"
```
</details>

---

**Question 17 (5 points):** What's the difference between `docker exec` and `docker attach`, and when would you use each?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **`docker exec`:** Run new command in existing container
  - Use for: Debugging, running additional processes
  - Example: `docker exec -it mycontainer bash`

- **`docker attach`:** Attach to main process (PID 1)
  - Use for: Interactive applications, viewing main process output
  - Example: `docker attach mycontainer`
  - **Warning:** Exiting may stop the container
</details>

---

**Question 18 (5 points):** How do you debug networking issues between containers?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Check container networks
docker network ls
docker inspect mycontainer --format='{{.NetworkSettings.Networks}}'

# Test connectivity
docker exec container1 ping container2
docker exec container1 nslookup container2

# Check port bindings
docker port mycontainer

# Inspect network configuration
docker network inspect bridge

# Check iptables rules (if needed)
sudo iptables -L -n
```
</details>

---

**Question 19 (5 points):** Write commands to collect comprehensive debugging information for a problematic container.

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
#!/bin/bash
CONTAINER=$1

echo "=== Container Information ==="
docker inspect $CONTAINER

echo "=== Container Logs ==="
docker logs $CONTAINER --timestamps

echo "=== Resource Usage ==="
docker stats $CONTAINER --no-stream

echo "=== Running Processes ==="
docker exec $CONTAINER ps aux

echo "=== Network Configuration ==="
docker exec $CONTAINER ip addr show
docker exec $CONTAINER netstat -tuln

echo "=== Filesystem ==="
docker exec $CONTAINER df -h
docker diff $CONTAINER

echo "=== Environment ==="
docker exec $CONTAINER env
```
</details>

---

## 🛠️ Practical Exercises

### Exercise 1: Resource Management (20 points)

Create and test containers with specific resource constraints:

1. **Memory Test (5 points):** Run a container that tries to allocate 200MB of memory with a 100MB limit. What happens?

2. **CPU Test (5 points):** Run a CPU-intensive container limited to 0.5 CPU cores and verify the limit is enforced.

3. **I/O Test (5 points):** Create a container with block I/O limits and test the restrictions.

4. **Monitoring (5 points):** Write a script that alerts when any container exceeds 80% memory usage.

### Exercise 2: Health Check Implementation (20 points)

1. **Basic Health Check (5 points):** Create a web application with `/health` endpoint that returns 200 for healthy, 503 for unhealthy.

2. **Advanced Health Check (10 points):** Implement a health check that validates:
   - Application responds within 3 seconds
   - Database connection is working
   - Disk usage is below 90%
   - Memory usage is below 85%

3. **Health Check Monitoring (5 points):** Create a script that restarts unhealthy containers automatically.

### Exercise 3: Container Patterns (15 points)

1. **Multi-Process Container (8 points):** Create a container running nginx, a Python web app, and a background worker using supervisord.

2. **Sidecar Pattern (7 points):** Implement a main application container with a logging sidecar that processes and forwards logs.

### Exercise 4: Troubleshooting Scenarios (15 points)

Debug and fix the following scenarios:

1. **Container Won't Start (5 points):** Container exits immediately with "command not found" error.

2. **High Resource Usage (5 points):** Container is using 100% CPU and growing memory usage.

3. **Network Issues (5 points):** Container cannot connect to another container by name.

## 🎯 Scoring Rubric

| Score Range | Level | Description |
|-------------|-------|-------------|
| 90-100 | Expert | Comprehensive understanding, perfect execution |
| 80-89 | Advanced | Strong grasp with minor gaps |
| 70-79 | Intermediate | Good understanding, some practice needed |
| 60-69 | Beginner | Basic concepts understood, significant practice required |
| Below 60 | Needs Review | Review chapter material and retry |

## ✅ Self-Assessment Checklist

Before proceeding to Chapter 4, ensure you can:

- [ ] Configure container resource limits (CPU, memory, I/O)
- [ ] Implement and troubleshoot health checks
- [ ] Monitor container performance and resource usage
- [ ] Debug common container issues effectively
- [ ] Use advanced container patterns (multi-process, sidecar)
- [ ] Understand container networking basics
- [ ] Implement container security best practices
- [ ] Create production-ready container configurations

## 🚀 Preparation for Next Chapter

Chapter 4 (Docker Networking) builds on these concepts:
- Understanding of container communication
- Basic networking troubleshooting skills
- Knowledge of container isolation
- Experience with multi-container setups

## 📚 Additional Resources

- [Docker Resource Constraints Documentation](https://docs.docker.com/config/containers/resource_constraints/)
- [Container Health Checks Best Practices](https://docs.docker.com/engine/reference/builder/#healthcheck)
- [Docker Logging Drivers](https://docs.docker.com/config/containers/logging/)
- [Container Security Best Practices](https://docs.docker.com/engine/security/)

---

**🎉 Checkpoint Complete!** 

**Score: ___/100**

If you scored 80+, you're ready for [Chapter 04: Docker Networking](../04-docker-networking/README.md).
If you scored below 80, review the chapter materials and retry the assessment.

---

**[⬅️ Back to Chapter 03](../README.md)** | **[Next: Docker Networking ➡️](../04-docker-networking/README.md)** 