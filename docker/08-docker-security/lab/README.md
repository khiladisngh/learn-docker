# 🔬 Chapter 08 Lab: Docker Security Implementation

## 🎯 Lab Objectives

In this hands-on lab, you'll implement comprehensive Docker security practices including:
- Building secure container images
- Implementing vulnerability scanning
- Configuring runtime security controls
- Setting up secrets management
- Monitoring security violations

**Estimated Time:** 2 hours  
**Difficulty:** Advanced  
**Prerequisites:** Completed Chapters 01-07

---

## 🚀 Lab Setup

### Initial Environment

Create the lab workspace:

```bash
# Create lab directory
mkdir -p docker-security-lab/{apps,security,monitoring}
cd docker-security-lab

# Download required files
curl -O https://example.com/vulnerable-app.zip
unzip vulnerable-app.zip
```

---

## 🛡️ Exercise 1: Secure Dockerfile Implementation

### Task 1.1: Analyze Vulnerable Dockerfile

**Vulnerable Example (`apps/vulnerable.dockerfile`):**
```dockerfile
FROM ubuntu:latest
RUN apt-get update && apt-get install -y python3 python3-pip
COPY requirements.txt .
RUN pip3 install -r requirements.txt
COPY app.py .
EXPOSE 8080
CMD ["python3", "app.py"]
```

**Your Task:** Identify security issues and create a secure version.

### Task 1.2: Create Secure Dockerfile

Create `apps/secure.dockerfile`:

```dockerfile
# Multi-stage secure build
FROM python:3.11-alpine AS builder

# Install security updates
RUN apk update && apk upgrade && apk add --no-cache dumb-init

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

FROM builder AS dependencies

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install dependencies with security checks
RUN pip install --no-cache-dir --require-hashes -r requirements.txt

FROM dependencies AS application

# Copy application with proper ownership
COPY --chown=appuser:appgroup app.py .

# Switch to non-root user
USER appuser

# Use init system for proper signal handling
ENTRYPOINT ["dumb-init", "--"]

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"

EXPOSE 8080
CMD ["python3", "app.py"]
```

### Task 1.3: Security Validation

Build and test both images:

```bash
# Build vulnerable image
docker build -f apps/vulnerable.dockerfile -t vulnerable-app .

# Build secure image
docker build -f apps/secure.dockerfile -t secure-app .

# Compare image sizes
docker images | grep -E "(vulnerable-app|secure-app)"

# Test security configurations
docker run --rm vulnerable-app id
docker run --rm secure-app id
```

**Questions:**
1. What security improvements did you implement?
2. How did the image size change?
3. What user does each container run as?

---

## 🔍 Exercise 2: Vulnerability Scanning Pipeline

### Task 2.1: Install Security Scanners

```bash
# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Verify installation
trivy version
docker scout version
```

### Task 2.2: Scan Images for Vulnerabilities

```bash
# Scan with Trivy
trivy image vulnerable-app:latest

# Scan with Docker Scout
docker scout cves vulnerable-app:latest

# Generate SARIF report
trivy image --format sarif --output results.sarif vulnerable-app:latest

# Compare secure vs vulnerable
trivy image --severity HIGH,CRITICAL vulnerable-app:latest > vulnerable-scan.txt
trivy image --severity HIGH,CRITICAL secure-app:latest > secure-scan.txt
```

### Task 2.3: Create Scanning Script

Create `security/scan-images.py`:

```python
#!/usr/bin/env python3
import subprocess
import json
import sys
import os

def scan_image_trivy(image_name):
    """Scan image with Trivy"""
    try:
        cmd = ['trivy', 'image', '--format', 'json', '--severity', 'HIGH,CRITICAL', image_name]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            return json.loads(result.stdout)
        else:
            return {'error': result.stderr}
    except Exception as e:
        return {'error': str(e)}

def scan_image_scout(image_name):
    """Scan image with Docker Scout"""
    try:
        cmd = ['docker', 'scout', 'cves', '--format', 'json', image_name]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            return json.loads(result.stdout)
        else:
            return {'error': result.stderr}
    except Exception as e:
        return {'error': str(e)}

def generate_report(image_name):
    """Generate comprehensive security report"""
    print(f"🔍 Scanning {image_name}...")
    
    trivy_results = scan_image_trivy(image_name)
    scout_results = scan_image_scout(image_name)
    
    report = {
        'image': image_name,
        'trivy_scan': trivy_results,
        'scout_scan': scout_results
    }
    
    # Save report
    with open(f'security-report-{image_name.replace(":", "-")}.json', 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"✅ Report saved for {image_name}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python scan-images.py <image_name>")
        sys.exit(1)
    
    image_name = sys.argv[1]
    generate_report(image_name)
```

Run the scanner:

```bash
python3 security/scan-images.py vulnerable-app:latest
python3 security/scan-images.py secure-app:latest
```

**Analysis Questions:**
1. How many vulnerabilities were found in each image?
2. What types of vulnerabilities are most common?
3. Which scanning tool provided more detailed information?

---

## 🔐 Exercise 3: Runtime Security Configuration

### Task 3.1: Container Security Profiles

Create `security/apparmor-profile`:

```
#include <tunables/global>

profile docker-secure-app flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  # Allow necessary capabilities
  capability setuid,
  capability setgid,

  # Deny dangerous capabilities
  deny capability sys_admin,
  deny capability sys_module,

  # File access controls
  /app/** r,
  /tmp/** rw,
  /usr/local/lib/python3.11/** r,

  # Deny sensitive paths
  deny /etc/passwd w,
  deny /etc/shadow rw,
  deny /proc/sys/** w,
  deny /sys/** w,
}
```

### Task 3.2: Secure Container Deployment

Create `security/secure-compose.yml`:

```yaml
version: '3.8'

services:
  secure-app:
    build:
      context: ../apps
      dockerfile: secure.dockerfile
    user: "1001:1001"
    read_only: true
    security_opt:
      - no-new-privileges:true
      - apparmor:docker-secure-app
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
          cpus: '0.25'
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=50m
    networks:
      - app-network
    secrets:
      - app_secret
    environment:
      - SECRET_FILE=/run/secrets/app_secret

networks:
  app-network:
    driver: bridge
    internal: true

secrets:
  app_secret:
    file: ./secrets/app_secret.txt
```

### Task 3.3: Test Security Controls

```bash
# Load AppArmor profile (Linux only)
sudo apparmor_parser -r security/apparmor-profile

# Create secrets directory
mkdir -p security/secrets
echo "supersecret123" > security/secrets/app_secret.txt

# Deploy with security controls
cd security
docker-compose up -d

# Test security restrictions
docker exec secure-app-secure-app-1 whoami
docker exec secure-app-secure-app-1 cat /etc/passwd
```

**Security Tests:**
1. Can the container access sensitive host files?
2. What user is the container running as?
3. Are the security restrictions working properly?

---

## 🔑 Exercise 4: Secrets Management

### Task 4.1: External Secrets with Docker Swarm

```bash
# Initialize swarm mode
docker swarm init

# Create secrets
echo "database_password_123" | docker secret create db_password -
echo "api_key_456" | docker secret create api_key -

# Deploy with secrets
docker service create \
  --name secure-webapp \
  --secret db_password \
  --secret api_key \
  --env DB_PASSWORD_FILE=/run/secrets/db_password \
  --env API_KEY_FILE=/run/secrets/api_key \
  secure-app:latest
```

### Task 4.2: Kubernetes Secrets (if available)

Create `security/k8s-secrets.yml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  db-password: ZGF0YWJhc2VfcGFzc3dvcmRfMTIz  # base64: database_password_123
  api-key: YXBpX2tleV80NTY=                # base64: api_key_456

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      securityContext:
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
      containers:
      - name: app
        image: secure-app:latest
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: secret-volume
          mountPath: /run/secrets
          readOnly: true
        - name: tmp-volume
          mountPath: /tmp
      volumes:
      - name: secret-volume
        secret:
          secretName: app-secrets
          defaultMode: 0400
      - name: tmp-volume
        emptyDir: {}
```

**Questions:**
1. How are secrets accessed by the application?
2. What are the file permissions on secret files?
3. Are secrets visible in environment variables?

---

## 📊 Exercise 5: Security Monitoring

### Task 5.1: Custom Security Monitor

Create `monitoring/security-monitor.py`:

```python
#!/usr/bin/env python3
import docker
import time
import json
from datetime import datetime

class SecurityMonitor:
    def __init__(self):
        self.client = docker.from_env()
        self.violations = []
    
    def check_container_security(self, container):
        violations = []
        
        try:
            attrs = container.attrs
            config = attrs.get('Config', {})
            host_config = attrs.get('HostConfig', {})
            
            # Check if running as root
            user = config.get('User', '')
            if not user or user in ['root', '0']:
                violations.append({
                    'container': container.name,
                    'violation': 'Running as root user',
                    'severity': 'HIGH',
                    'timestamp': datetime.now().isoformat()
                })
            
            # Check for privileged mode
            if host_config.get('Privileged', False):
                violations.append({
                    'container': container.name,
                    'violation': 'Container running in privileged mode',
                    'severity': 'CRITICAL',
                    'timestamp': datetime.now().isoformat()
                })
            
            # Check for sensitive mounts
            mounts = attrs.get('Mounts', [])
            sensitive_paths = ['/etc', '/proc', '/sys', '/var/run/docker.sock']
            
            for mount in mounts:
                source = mount.get('Source', '')
                for sensitive_path in sensitive_paths:
                    if source.startswith(sensitive_path):
                        violations.append({
                            'container': container.name,
                            'violation': f'Sensitive path mounted: {source}',
                            'severity': 'HIGH',
                            'timestamp': datetime.now().isoformat()
                        })
        
        except Exception as e:
            violations.append({
                'container': container.name,
                'violation': f'Monitor error: {e}',
                'severity': 'WARNING',
                'timestamp': datetime.now().isoformat()
            })
        
        return violations
    
    def scan_all_containers(self):
        all_violations = []
        containers = self.client.containers.list()
        
        for container in containers:
            violations = self.check_container_security(container)
            all_violations.extend(violations)
        
        return all_violations
    
    def monitor_continuously(self, interval=30):
        print("🔍 Starting security monitoring...")
        
        while True:
            try:
                violations = self.scan_all_containers()
                
                if violations:
                    print(f"⚠️ Found {len(violations)} security violations:")
                    for v in violations:
                        print(f"  - {v['container']}: {v['violation']} ({v['severity']})")
                    
                    # Save violations
                    with open(f"violations-{datetime.now().strftime('%Y%m%d_%H%M%S')}.json", 'w') as f:
                        json.dump(violations, f, indent=2)
                else:
                    print("✅ No security violations detected")
                
                time.sleep(interval)
                
            except KeyboardInterrupt:
                print("Monitoring stopped")
                break
            except Exception as e:
                print(f"Monitor error: {e}")
                time.sleep(10)

if __name__ == "__main__":
    monitor = SecurityMonitor()
    monitor.monitor_continuously()
```

### Task 5.2: Run Security Monitoring

```bash
# Start the security monitor
python3 monitoring/security-monitor.py &

# Deploy test containers with different security configurations
docker run -d --name test-secure --user 1001:1001 alpine:latest sleep 3600
docker run -d --name test-insecure --privileged alpine:latest sleep 3600
docker run -d --name test-root alpine:latest sleep 3600

# Check monitoring output
sleep 60
fg  # Bring monitor to foreground and stop with Ctrl+C
```

**Analysis:**
1. Which containers triggered security violations?
2. What types of violations were detected?
3. How would you remediate each violation?

---

## 🎯 Lab Assessment

### Completion Checklist

- [ ] **Secure Dockerfile**: Created hardened container image
- [ ] **Vulnerability Scanning**: Implemented automated scanning
- [ ] **Runtime Security**: Configured security controls
- [ ] **Secrets Management**: Implemented external secrets
- [ ] **Security Monitoring**: Set up violation detection

### Performance Metrics

Measure your security improvements:

```bash
# Image size comparison
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Vulnerability count comparison
trivy image --severity HIGH,CRITICAL vulnerable-app:latest | grep "Total:"
trivy image --severity HIGH,CRITICAL secure-app:latest | grep "Total:"

# Security configuration verification
docker inspect secure-app:latest | jq '.[] | {User: .Config.User, Privileged: .HostConfig.Privileged}'
```

### Security Score Calculation

Calculate your security improvement:

**Formula:** `Security Score = (Baseline Vulnerabilities - Current Vulnerabilities) / Baseline Vulnerabilities × 100`

**Example:**
- Vulnerable image: 25 HIGH/CRITICAL vulnerabilities
- Secure image: 3 HIGH/CRITICAL vulnerabilities
- **Security Score:** (25 - 3) / 25 × 100 = 88% improvement

---

## 🔧 Troubleshooting

### Common Issues

**1. AppArmor Profile Loading:**
```bash
# Check if AppArmor is enabled
sudo systemctl status apparmor

# Load profile manually
sudo apparmor_parser -r /path/to/profile
```

**2. Scanner Installation:**
```bash
# Alternative Trivy installation
wget https://github.com/aquasecurity/trivy/releases/download/v0.45.0/trivy_0.45.0_Linux-64bit.tar.gz
tar zxvf trivy_0.45.0_Linux-64bit.tar.gz
sudo mv trivy /usr/local/bin/
```

**3. Docker Scout Issues:**
```bash
# Enable Docker Scout
docker scout version
# If not available, update Docker Desktop
```

---

## 🏆 Advanced Challenges

### Challenge 1: Zero-Trust Container
Build a container that implements complete zero-trust principles:
- Distroless base image
- No shell access
- Minimal capabilities
- External secret injection
- Runtime attestation

### Challenge 2: Compliance Automation
Create an automated compliance checker that:
- Scans all running containers
- Generates CIS compliance report
- Sends alerts for violations
- Tracks remediation progress

### Challenge 3: Security Pipeline
Implement a complete security pipeline:
- Pre-commit hooks for Dockerfile linting
- CI/CD vulnerability scanning gates
- Runtime security monitoring
- Automated incident response

---

## 📚 Key Takeaways

✅ **Image Security**: Use minimal base images and scan for vulnerabilities  
✅ **Runtime Security**: Implement access controls and monitoring  
✅ **Secrets Management**: Never embed secrets in images  
✅ **Compliance**: Follow security frameworks and standards  
✅ **Monitoring**: Continuous security assessment is essential  

---

**🎉 Congratulations!** You've successfully implemented comprehensive Docker security practices. These skills are essential for production container deployments.

**[⬅️ Back to Chapter 08](../README.md)** | **[Next: Checkpoint ➡️](../checkpoint.md)** 