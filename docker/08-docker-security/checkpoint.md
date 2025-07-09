# 🎯 Chapter 08 Checkpoint: Docker Security Mastery

## 📝 Knowledge Assessment

**Total Points: 100**  
**Passing Score: 75**  
**Time Limit: 45 minutes**

---

### Section A: Image Security & Vulnerability Management (25 points)

#### Question 1 (5 points)
**Which base image approach provides the best security?**

a) `FROM ubuntu:latest`  
b) `FROM node:16`  
c) `FROM alpine:3.18`  
d) `FROM gcr.io/distroless/nodejs:16`  

<details>
<summary>💡 Click to reveal answer</summary>

**Answer: d) FROM gcr.io/distroless/nodejs:16**

**Explanation:** Distroless images provide the best security because they:
- Contain only the application and runtime dependencies
- No shell, package manager, or unnecessary tools
- Minimal attack surface
- Reduced vulnerability exposure
- Cannot be exploited through common attack vectors

**Security ranking:**
1. **Distroless** - Most secure, minimal attack surface
2. **Alpine** - Small, security-focused, regular updates
3. **Official Images** - Well-maintained but larger
4. **Latest tags** - Least secure, unpredictable updates
</details>

#### Question 2 (10 points)
**Write a secure Dockerfile that implements security best practices:**

Requirements:
- Multi-stage build
- Non-root user
- Minimal base image
- No secrets in layers
- Health check included

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

```dockerfile
# Multi-stage build for security
FROM node:18-alpine AS builder

# Install security updates
RUN apk update && apk upgrade && apk add --no-cache dumb-init

WORKDIR /build

# Copy package files first for better caching
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

COPY . .
RUN npm run build

# Production stage - minimal distroless
FROM gcr.io/distroless/nodejs:18

# Copy init system from builder
COPY --from=builder /usr/bin/dumb-init /usr/bin/dumb-init

# Create app directory with proper ownership
WORKDIR /app

# Copy only production dependencies and built app
COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/dist ./dist
COPY --from=builder /build/package*.json ./

# Use non-root user (distroless provides 'nonroot' user)
USER nonroot:nonroot

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/nodejs/bin/node", "-e", "require('http').get('http://localhost:3000/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1))"]

ENTRYPOINT ["dumb-init", "--"]
CMD ["/nodejs/bin/node", "dist/server.js"]
```

**Security Features:**
- Multi-stage build reduces final image size
- Distroless base minimizes attack surface
- Non-root user prevents privilege escalation
- No secrets embedded in image layers
- Health check for container monitoring
- Init system for proper signal handling
</details>

#### Question 3 (10 points)
**Explain vulnerability scanning with Trivy and Docker Scout:**

Compare the tools and show how to integrate them into CI/CD.

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**Tool Comparison:**

| Feature | Trivy | Docker Scout |
|---------|-------|--------------|
| **Installation** | External tool | Built into Docker |
| **Scope** | Images, filesystems, repos | Docker images |
| **Output** | JSON, SARIF, table | JSON, text |
| **CI/CD** | Excellent | Good |
| **SBOM** | Yes | Yes |
| **Secrets** | Yes | Limited |

**Trivy Integration:**
```bash
# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh

# Scan image
trivy image --severity HIGH,CRITICAL myapp:latest

# Generate SARIF for GitHub
trivy image --format sarif --output results.sarif myapp:latest

# CI/CD Pipeline
trivy image --exit-code 1 --severity CRITICAL myapp:latest
```

**Docker Scout Integration:**
```bash
# Enable Docker Scout
docker scout version

# Scan image
docker scout cves myapp:latest

# Policy evaluation
docker scout policy myapp:latest

# CI/CD integration
docker scout cves --exit-code --only-severity critical,high myapp:latest
```

**GitHub Actions Example:**
```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'myapp:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload Trivy scan results
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'trivy-results.sarif'
```
</details>

---

### Section B: Runtime Security & Access Controls (25 points)

#### Question 4 (15 points)
**Design a runtime security configuration:**

Create a secure container deployment that includes:
- Linux capabilities restrictions
- AppArmor/SELinux profiles
- User namespaces
- Resource limits
- Security monitoring

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**1. Secure Container Run Command:**
```bash
docker run -d \
  --name secure-app \
  --user 1001:1001 \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --security-opt no-new-privileges:true \
  --security-opt apparmor=docker-nginx \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=50m \
  --memory=512m \
  --cpus="0.5" \
  --pids-limit=100 \
  myapp:latest
```

**2. AppArmor Profile:**
```bash
# /etc/apparmor.d/docker-nginx
profile docker-nginx flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  # Allow necessary capabilities
  capability setuid,
  capability setgid,
  capability net_bind_service,

  # Deny dangerous capabilities
  deny capability sys_admin,
  deny capability sys_module,

  # File access controls
  /etc/nginx/** r,
  /var/log/nginx/** w,
  /usr/share/nginx/html/** r,

  # Deny sensitive paths
  deny /proc/sys/** w,
  deny /sys/** w,
  deny /etc/passwd w,
  deny /etc/shadow rw,
}
```

**3. Docker Compose with Security:**
```yaml
version: '3.8'
services:
  app:
    image: myapp:latest
    user: "1001:1001"
    read_only: true
    security_opt:
      - no-new-privileges:true
      - apparmor:docker-nginx
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

networks:
  app-network:
    driver: bridge
    internal: true
```

**4. Monitoring Integration:**
```yaml
# Falco rule for monitoring
- rule: Unexpected Privileged Container
  desc: Detect containers running with unexpected privileges
  condition: >
    container and
    (container.privileged=true or
     container.capabilities intersects (sys_admin, sys_module))
  output: >
    Privileged container detected 
    (container=%container.name capabilities=%container.capabilities)
  priority: HIGH
```

**Key Security Features:**
- Non-root user execution
- Minimal Linux capabilities
- AppArmor profile enforcement
- Read-only root filesystem
- Resource limits to prevent DoS
- Network isolation
- Runtime monitoring with Falco
</details>

#### Question 5 (10 points)
**What are the differences between these isolation mechanisms?**

1. **User Namespaces**
2. **Linux Capabilities**
3. **AppArmor/SELinux**
4. **Seccomp**

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**1. User Namespaces:**
- **Purpose**: UID/GID isolation and remapping
- **Mechanism**: Maps container root (UID 0) to unprivileged host user
- **Protection**: Prevents privilege escalation to host
- **Example**: Container root = host user 165536
- **Usage**: `dockerd --userns-remap=default`

**2. Linux Capabilities:**
- **Purpose**: Fine-grained privilege control
- **Mechanism**: Breaks root privileges into discrete capabilities
- **Protection**: Limits what privileged processes can do
- **Example**: `NET_BIND_SERVICE` allows binding to ports < 1024
- **Usage**: `--cap-drop=ALL --cap-add=NET_BIND_SERVICE`

**3. AppArmor/SELinux:**
- **Purpose**: Mandatory Access Control (MAC)
- **Mechanism**: Policy-based access control
- **Protection**: Defines what resources processes can access
- **Example**: Allow read to `/etc/nginx/*`, deny write to `/etc/passwd`
- **Usage**: `--security-opt apparmor=profile-name`

**4. Seccomp:**
- **Purpose**: System call filtering
- **Mechanism**: Whitelist/blacklist system calls
- **Protection**: Prevents dangerous system calls
- **Example**: Block `ptrace`, `mount`, `reboot`
- **Usage**: `--security-opt seccomp=profile.json`

**Layered Security Approach:**
```bash
docker run \
  --userns-remap=default \           # User namespaces
  --cap-drop=ALL \                   # Remove all capabilities
  --cap-add=NET_BIND_SERVICE \       # Add only needed capability
  --security-opt apparmor=profile \  # MAC policy
  --security-opt seccomp=profile.json \ # Syscall filtering
  myapp:latest
```

**When to Use Each:**
- **User Namespaces**: Always in production
- **Capabilities**: When containers need specific privileges
- **AppArmor/SELinux**: For strict access control policies
- **Seccomp**: To block dangerous system calls
</details>

---

### Section C: Secrets Management & Network Security (25 points)

#### Question 6 (15 points)
**Implement a comprehensive secrets management solution:**

Design a system that:
- Integrates with external secret stores (Vault, AWS Secrets Manager)
- Provides runtime secret injection
- Implements secret rotation
- Ensures secrets are never logged or exposed

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**1. External Secrets Integration (Vault Example):**

```python
#!/usr/bin/env python3
# vault-secrets-manager.py

import hvac
import os
import json
import time
from pathlib import Path

class VaultSecretsManager:
    def __init__(self, vault_url: str, auth_method: str = 'kubernetes'):
        self.client = hvac.Client(url=vault_url)
        self.auth_method = auth_method
        self.authenticate()
    
    def authenticate(self):
        """Authenticate with Vault using Kubernetes service account"""
        if self.auth_method == 'kubernetes':
            token_path = '/var/run/secrets/kubernetes.io/serviceaccount/token'
            if Path(token_path).exists():
                token = Path(token_path).read_text()
                role = os.getenv('VAULT_ROLE', 'myapp')
                
                response = self.client.auth.kubernetes.login(
                    role=role,
                    jwt=token
                )
                self.client.token = response['auth']['client_token']
    
    def get_secret(self, path: str, version: int = None) -> dict:
        """Retrieve secret from Vault KV v2"""
        try:
            if version:
                response = self.client.secrets.kv.v2.read_secret_version(
                    path=path, version=version
                )
            else:
                response = self.client.secrets.kv.v2.read_secret_version(path=path)
            
            return response['data']['data']
        except Exception as e:
            raise ValueError(f"Failed to retrieve secret {path}: {e}")
    
    def write_secret_files(self, secrets_config: dict, secrets_dir: str = '/run/secrets'):
        """Write secrets to files with secure permissions"""
        Path(secrets_dir).mkdir(parents=True, exist_ok=True, mode=0o700)
        
        for secret_name, config in secrets_config.items():
            secret_data = self.get_secret(config['vault_path'])
            
            for key, filename in config['keys'].items():
                if key in secret_data:
                    secret_file = Path(secrets_dir) / filename
                    secret_file.write_text(secret_data[key])
                    secret_file.chmod(0o600)
                    print(f"✅ Secret {filename} written securely")
    
    def rotate_secrets(self, secrets_config: dict, rotation_interval: int = 3600):
        """Continuously rotate secrets"""
        while True:
            try:
                self.write_secret_files(secrets_config)
                time.sleep(rotation_interval)
            except Exception as e:
                print(f"❌ Secret rotation failed: {e}")
                time.sleep(60)

# Container initialization script
if __name__ == "__main__":
    vault_url = os.getenv('VAULT_ADDR', 'https://vault.example.com')
    
    secrets_config = {
        'database': {
            'vault_path': 'myapp/database',
            'keys': {
                'username': 'db_username',
                'password': 'db_password'
            }
        },
        'external_apis': {
            'vault_path': 'myapp/apis',
            'keys': {
                'stripe_key': 'stripe_secret',
                'sendgrid_key': 'sendgrid_api_key'
            }
        }
    }
    
    vault_manager = VaultSecretsManager(vault_url)
    vault_manager.write_secret_files(secrets_config)
```

**2. Kubernetes Secret Integration:**

```yaml
# External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "myapp"

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secrets
    creationPolicy: Owner
  data:
  - secretKey: db-password
    remoteRef:
      key: myapp/database
      property: password
  - secretKey: api-key
    remoteRef:
      key: myapp/apis
      property: stripe_key
```

**3. Container with Secrets:**

```dockerfile
FROM python:3.11-alpine

# Install secret management script
COPY vault-secrets-manager.py /usr/local/bin/
RUN chmod +x /usr/local/bin/vault-secrets-manager.py

# Create secrets directory
RUN mkdir -p /run/secrets && chmod 700 /run/secrets

# Application setup
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Create non-root user
RUN adduser -D -s /bin/sh appuser
USER appuser

# Init script that fetches secrets before starting app
COPY init.sh /init.sh
ENTRYPOINT ["/init.sh"]
CMD ["python", "app.py"]
```

**4. Security Best Practices:**

```bash
#!/bin/bash
# init.sh - Secure secret initialization

# Fetch secrets from Vault
python3 /usr/local/bin/vault-secrets-manager.py

# Ensure secrets directory permissions
chmod 700 /run/secrets
chmod 600 /run/secrets/*

# Clear environment variables that might contain secrets
unset VAULT_TOKEN
unset TEMP_PASSWORD

# Start application with secrets available as files
exec "$@"
```

**Key Security Features:**
- External secret store integration
- Kubernetes service account authentication
- File-based secret injection (not environment variables)
- Automatic secret rotation
- Secure file permissions (600)
- No secrets in environment or logs
- Secret cleanup before app start
</details>

#### Question 7 (10 points)
**Configure network security for containers:**

Design network security including segmentation, firewalls, and encrypted communication.

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**1. Network Segmentation with Docker Compose:**

```yaml
version: '3.8'

services:
  # Public-facing web server
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    networks:
      - frontend
      - dmz
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl

  # Application server
  app:
    image: myapp:latest
    networks:
      - frontend
      - backend
    depends_on:
      - database
      - redis

  # Database (backend only)
  database:
    image: postgres:13
    networks:
      - backend
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    secrets:
      - db_password

  # Cache (backend only)
  redis:
    image: redis:alpine
    networks:
      - backend
    command: redis-server --requirepass "${REDIS_PASSWORD}"

networks:
  # DMZ - external access
  dmz:
    driver: bridge
    ipam:
      config:
        - subnet: 172.18.0.0/16

  # Frontend - web tier
  frontend:
    driver: bridge
    internal: false
    ipam:
      config:
        - subnet: 172.19.0.0/16

  # Backend - data tier (no external access)
  backend:
    driver: bridge
    internal: true
    ipam:
      config:
        - subnet: 172.20.0.0/16

secrets:
  db_password:
    external: true
```

**2. Host Firewall Configuration:**

```bash
#!/bin/bash
# docker-firewall.sh

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP/HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Docker-specific rules
# Allow Docker bridge traffic
iptables -A INPUT -i docker0 -j ACCEPT
iptables -A FORWARD -i docker0 -o docker0 -j ACCEPT

# Allow forwarding from Docker containers to outside
iptables -A FORWARD -i docker0 ! -o docker0 -j ACCEPT
iptables -A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Block direct access to Docker daemon
iptables -A INPUT -p tcp --dport 2375 -j DROP
iptables -A INPUT -p tcp --dport 2376 -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -p tcp --dport 2376 -j DROP

# Network segmentation - Block cross-network access
iptables -A FORWARD -s 172.19.0.0/16 -d 172.20.0.0/16 -j DROP
iptables -A FORWARD -s 172.20.0.0/16 -d 172.19.0.0/16 -j DROP

# Save rules
iptables-save > /etc/iptables/rules.v4
```

**3. TLS/mTLS Configuration:**

```yaml
# nginx.conf with TLS
server {
    listen 443 ssl http2;
    server_name app.example.com;

    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;
    ssl_client_certificate /etc/nginx/ssl/ca.crt;
    ssl_verify_client on;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;

    location / {
        proxy_pass http://app:8080;
        proxy_ssl_certificate /etc/nginx/ssl/client.crt;
        proxy_ssl_certificate_key /etc/nginx/ssl/client.key;
        proxy_ssl_protocols TLSv1.2 TLSv1.3;
        proxy_ssl_verify on;
        proxy_ssl_trusted_certificate /etc/nginx/ssl/ca.crt;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**4. Service Mesh Security (Istio Example):**

```yaml
# Service mesh with mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT

---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: app-policy
spec:
  selector:
    matchLabels:
      app: myapp
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/frontend"]
  - to:
    - operation:
        methods: ["GET", "POST"]
```

**Network Security Features:**
- **Network Segmentation**: DMZ, frontend, backend isolation
- **Firewall Rules**: Host-level traffic control
- **TLS/mTLS**: Encrypted communication between services
- **Service Mesh**: Advanced traffic management and security
- **Internal Networks**: Backend services not externally accessible
- **Certificate Management**: Proper PKI for service authentication
</details>

---

### Section D: Compliance & Monitoring (25 points)

#### Question 8 (15 points)
**Implement a security monitoring and compliance system:**

Create a solution that monitors runtime security violations and ensures CIS compliance.

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**1. Falco Runtime Security Monitoring:**

```yaml
# falco-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-config
data:
  falco.yaml: |
    rules_file:
      - /etc/falco/falco_rules.yaml
      - /etc/falco/custom_rules.yaml
    
    json_output: true
    json_include_output_property: true
    
    http_output:
      enabled: true
      url: "http://webhook-service:8080/alerts"

  custom_rules.yaml: |
    - rule: Unauthorized Container Access
      desc: Detect access to containers not in whitelist
      condition: >
        container and not container.image.repository in 
        (myapp, nginx, postgres, redis)
      output: >
        Unauthorized container detected 
        (container=%container.name image=%container.image.repository)
      priority: HIGH

    - rule: Privileged Container
      desc: Detect privileged container creation
      condition: >
        container and container.privileged=true
      output: >
        Privileged container created 
        (container=%container.name user=%user.name)
      priority: CRITICAL

    - rule: Sensitive File Access
      desc: Monitor access to sensitive files
      condition: >
        open_read and container and
        fd.name in (/etc/passwd, /etc/shadow, /etc/hosts)
      output: >
        Sensitive file accessed 
        (file=%fd.name container=%container.name user=%user.name)
      priority: WARNING

    - rule: Network Anomaly
      desc: Detect unexpected network connections
      condition: >
        inbound_outbound and container and
        not fd.sport in (80, 443, 8080, 3000, 5432, 6379) and
        not fd.dport in (80, 443, 8080, 3000, 5432, 6379)
      output: >
        Unexpected network connection 
        (connection=%fd.name container=%container.name)
      priority: MEDIUM

---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falco
spec:
  selector:
    matchLabels:
      app: falco
  template:
    metadata:
      labels:
        app: falco
    spec:
      serviceAccount: falco
      hostNetwork: true
      hostPID: true
      containers:
      - name: falco
        image: falcosecurity/falco:latest
        securityContext:
          privileged: true
        volumeMounts:
        - name: docker-socket
          mountPath: /host/var/run/docker.sock
        - name: falco-config
          mountPath: /etc/falco
        env:
        - name: FALCO_BPF_PROBE
          value: ""
      volumes:
      - name: docker-socket
        hostPath:
          path: /var/run/docker.sock
      - name: falco-config
        configMap:
          name: falco-config
```

**2. CIS Compliance Checker:**

```python
#!/usr/bin/env python3
# cis-compliance-monitor.py

import docker
import json
import time
import requests
from datetime import datetime
from typing import Dict, List

class CISComplianceMonitor:
    def __init__(self):
        self.client = docker.from_env()
        self.compliance_rules = self._load_cis_rules()
    
    def _load_cis_rules(self) -> Dict:
        return {
            'container_user': {
                'id': '4.1',
                'description': 'Ensure container runs as non-root user',
                'severity': 'HIGH'
            },
            'privileged_containers': {
                'id': '4.5',
                'description': 'Ensure privileged containers are not used',
                'severity': 'CRITICAL'
            },
            'sensitive_mounts': {
                'id': '4.6',
                'description': 'Ensure sensitive directories not mounted',
                'severity': 'HIGH'
            },
            'capabilities': {
                'id': '4.8',
                'description': 'Ensure unnecessary capabilities are dropped',
                'severity': 'MEDIUM'
            }
        }
    
    def check_container_compliance(self, container) -> List[Dict]:
        violations = []
        
        try:
            attrs = container.attrs
            config = attrs.get('Config', {})
            host_config = attrs.get('HostConfig', {})
            
            # Check user configuration
            user = config.get('User', '')
            if not user or user in ['root', '0']:
                violations.append({
                    'rule_id': '4.1',
                    'container': container.name,
                    'violation': 'Running as root user',
                    'severity': 'HIGH',
                    'recommendation': 'Configure non-root user in Dockerfile'
                })
            
            # Check privileged mode
            if host_config.get('Privileged', False):
                violations.append({
                    'rule_id': '4.5',
                    'container': container.name,
                    'violation': 'Container running in privileged mode',
                    'severity': 'CRITICAL',
                    'recommendation': 'Remove --privileged flag'
                })
            
            # Check sensitive mounts
            sensitive_paths = ['/etc', '/proc', '/sys', '/var/run/docker.sock']
            mounts = attrs.get('Mounts', [])
            
            for mount in mounts:
                source = mount.get('Source', '')
                for sensitive_path in sensitive_paths:
                    if source.startswith(sensitive_path):
                        violations.append({
                            'rule_id': '4.6',
                            'container': container.name,
                            'violation': f'Sensitive path mounted: {source}',
                            'severity': 'HIGH',
                            'recommendation': 'Avoid mounting sensitive host paths'
                        })
            
            # Check capabilities
            cap_add = host_config.get('CapAdd', []) or []
            dangerous_caps = ['SYS_ADMIN', 'SYS_MODULE', 'DAC_READ_SEARCH']
            
            for cap in cap_add:
                if cap in dangerous_caps:
                    violations.append({
                        'rule_id': '4.8',
                        'container': container.name,
                        'violation': f'Dangerous capability added: {cap}',
                        'severity': 'MEDIUM',
                        'recommendation': 'Use minimal required capabilities'
                    })
                    
        except Exception as e:
            violations.append({
                'rule_id': 'ERROR',
                'container': container.name,
                'violation': f'Compliance check failed: {e}',
                'severity': 'WARNING',
                'recommendation': 'Review container configuration'
            })
        
        return violations
    
    def run_compliance_scan(self) -> Dict:
        all_violations = []
        containers = self.client.containers.list()
        
        for container in containers:
            violations = self.check_container_compliance(container)
            all_violations.extend(violations)
        
        # Generate compliance report
        report = {
            'timestamp': datetime.now().isoformat(),
            'total_containers': len(containers),
            'total_violations': len(all_violations),
            'violations_by_severity': {
                'CRITICAL': len([v for v in all_violations if v.get('severity') == 'CRITICAL']),
                'HIGH': len([v for v in all_violations if v.get('severity') == 'HIGH']),
                'MEDIUM': len([v for v in all_violations if v.get('severity') == 'MEDIUM']),
                'WARNING': len([v for v in all_violations if v.get('severity') == 'WARNING'])
            },
            'violations': all_violations,
            'compliance_score': self._calculate_compliance_score(all_violations, containers)
        }
        
        return report
    
    def _calculate_compliance_score(self, violations: List[Dict], containers: List) -> float:
        total_checks = len(containers) * len(self.compliance_rules)
        failed_checks = len(violations)
        return ((total_checks - failed_checks) / total_checks) * 100 if total_checks > 0 else 100
    
    def send_compliance_alert(self, report: Dict):
        webhook_url = "https://your-webhook-url.com/compliance"
        
        if report['violations_by_severity']['CRITICAL'] > 0:
            alert_payload = {
                'type': 'compliance_violation',
                'severity': 'CRITICAL',
                'message': f"Critical compliance violations detected: {report['violations_by_severity']['CRITICAL']}",
                'compliance_score': report['compliance_score'],
                'violations': [v for v in report['violations'] if v.get('severity') == 'CRITICAL']
            }
            
            try:
                requests.post(webhook_url, json=alert_payload, timeout=10)
            except Exception as e:
                print(f"Failed to send compliance alert: {e}")
    
    def continuous_monitoring(self, interval: int = 300):
        while True:
            try:
                report = self.run_compliance_scan()
                
                print(f"Compliance Report - Score: {report['compliance_score']:.1f}%")
                print(f"Violations: {report['total_violations']} total")
                
                # Send alerts for critical violations
                self.send_compliance_alert(report)
                
                # Save report
                with open(f"compliance-report-{datetime.now().strftime('%Y%m%d_%H%M%S')}.json", 'w') as f:
                    json.dump(report, f, indent=2)
                
                time.sleep(interval)
                
            except KeyboardInterrupt:
                print("Compliance monitoring stopped")
                break
            except Exception as e:
                print(f"Compliance monitoring error: {e}")
                time.sleep(60)

if __name__ == "__main__":
    monitor = CISComplianceMonitor()
    monitor.continuous_monitoring()
```

**3. Integrated Security Dashboard:**

```python
#!/usr/bin/env python3
# security-dashboard.py

from flask import Flask, render_template, jsonify
import json
import os
from datetime import datetime, timedelta

app = Flask(__name__)

class SecurityDashboard:
    def __init__(self):
        self.reports_dir = './security-reports'
        
    def get_latest_reports(self) -> Dict:
        # Load latest compliance and security reports
        compliance_report = self._load_latest_report('compliance-report-*.json')
        security_report = self._load_latest_report('security-scan-*.json')
        
        return {
            'compliance': compliance_report,
            'security': security_report,
            'last_updated': datetime.now().isoformat()
        }
    
    def _load_latest_report(self, pattern: str) -> Dict:
        import glob
        
        files = glob.glob(os.path.join(self.reports_dir, pattern))
        if files:
            latest_file = max(files, key=os.path.getctime)
            with open(latest_file, 'r') as f:
                return json.load(f)
        return {}

dashboard = SecurityDashboard()

@app.route('/')
def index():
    return render_template('dashboard.html')

@app.route('/api/security-status')
def security_status():
    reports = dashboard.get_latest_reports()
    
    compliance_score = reports.get('compliance', {}).get('compliance_score', 0)
    security_violations = reports.get('security', {}).get('total_violations', 0)
    
    status = {
        'overall_status': 'SECURE' if compliance_score > 90 and security_violations == 0 else 'AT_RISK',
        'compliance_score': compliance_score,
        'security_violations': security_violations,
        'last_scan': reports.get('last_updated'),
        'recommendations': []
    }
    
    if compliance_score < 75:
        status['recommendations'].append('Address critical compliance violations')
    if security_violations > 0:
        status['recommendations'].append('Review and remediate security violations')
    
    return jsonify(status)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

**Security Monitoring Features:**
- **Runtime Monitoring**: Falco detects anomalous behavior
- **Compliance Checking**: Automated CIS benchmark verification
- **Continuous Scanning**: Regular security assessments
- **Alert Integration**: Webhook notifications for violations
- **Compliance Scoring**: Quantitative security metrics
- **Dashboard**: Real-time security status visualization
</details>

#### Question 9 (10 points)
**Explain the key principles of container security compliance:**

Cover CIS benchmarks, regulatory requirements, and audit procedures.

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**Container Security Compliance Principles:**

**1. CIS Docker Benchmark Categories:**

**Host Configuration:**
- Separate partition for Docker (`/var/lib/docker`)
- Docker daemon configuration hardening
- File permissions and ownership
- Audit configuration

**Docker Daemon Configuration:**
- Disable legacy registry (v1)
- Enable content trust
- Restrict network traffic between containers
- Configure logging driver
- Disable userland proxy

**Docker Daemon Configuration Files:**
- Secure daemon socket file
- Set ownership and permissions on Docker files
- Verify Docker registry certificates

**Container Images and Build:**
- Create user for container
- Use trusted base images
- Don't install unnecessary packages
- Scan images for vulnerabilities
- Sign and verify images

**Container Runtime:**
- AppArmor/SELinux profiles
- Capabilities restrictions
- Resource limits
- Read-only root filesystem
- Sensitive host paths not mounted

**2. Regulatory Compliance Mapping:**

| Regulation | Requirements | Docker Implementation |
|------------|--------------|----------------------|
| **SOC 2** | Access controls, monitoring | RBAC, audit logging, user namespaces |
| **PCI DSS** | Network segmentation, encryption | Network policies, TLS, secrets management |
| **HIPAA** | Data protection, audit trails | Encryption at rest/transit, logging |
| **GDPR** | Data privacy, breach notification | Data anonymization, monitoring alerts |
| **FedRAMP** | Government security standards | FIPS compliance, hardened configurations |

**3. Audit Procedures:**

```bash
#!/bin/bash
# security-audit.sh

# CIS Benchmark automated checks
echo "Running CIS Docker Benchmark..."
docker run --rm --net host --pid host --userns host --cap-add audit_control \
  -v /etc:/etc:ro \
  -v /var/lib:/var/lib:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  docker/docker-bench-security

# Custom compliance checks
echo "Running custom compliance checks..."
python3 cis-compliance-monitor.py --audit-mode

# Vulnerability assessment
echo "Scanning for vulnerabilities..."
trivy image --severity HIGH,CRITICAL $(docker images --format "{{.Repository}}:{{.Tag}}")

# Configuration assessment
echo "Checking container configurations..."
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | \
  while read name image status; do
    if [ "$name" != "NAMES" ]; then
      echo "Auditing container: $name"
      docker inspect $name | jq '.[] | {
        "User": .Config.User,
        "Privileged": .HostConfig.Privileged,
        "Capabilities": .HostConfig.CapAdd,
        "SecurityOpt": .HostConfig.SecurityOpt,
        "Mounts": [.Mounts[] | select(.Source | startswith("/etc") or startswith("/proc"))]
      }'
    fi
  done
```

**4. Compliance Documentation Template:**

```yaml
# compliance-policy.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-policy
data:
  policy.yaml: |
    security_policy:
      version: "1.0"
      effective_date: "2024-01-01"
      
      standards:
        - name: "CIS Docker Benchmark v1.4.0"
          compliance_level: "Level 1"
          mandatory_controls:
            - "4.1: Container user"
            - "4.5: Privileged containers"
            - "4.6: Sensitive mounts"
            - "5.1: AppArmor profiles"
        
        - name: "SOC 2 Type II"
          controls:
            - "CC6.1: Logical access controls"
            - "CC6.7: Data transmission controls"
            - "CC7.2: System monitoring"
      
      container_requirements:
        base_images:
          - "Must use approved base images from corporate registry"
          - "Images must be scanned and pass vulnerability assessment"
          - "No 'latest' tags in production"
        
        runtime_security:
          - "Containers must run as non-root user"
          - "No privileged containers without approval"
          - "AppArmor/SELinux profiles required"
          - "Resource limits must be configured"
        
        data_protection:
          - "Secrets must use external secret management"
          - "No secrets in environment variables"
          - "Encryption required for data at rest and in transit"
      
      monitoring_requirements:
        - "Runtime security monitoring with Falco"
        - "Compliance scanning every 24 hours"
        - "Vulnerability scanning on every build"
        - "Audit logging for all container operations"
      
      incident_response:
        - "Critical vulnerabilities: 24 hours to remediate"
        - "High severity violations: 72 hours to remediate"
        - "All incidents logged and tracked"
```

**Key Compliance Principles:**
1. **Continuous Monitoring**: Automated compliance checking
2. **Risk-Based Approach**: Priority based on threat assessment
3. **Documentation**: Comprehensive policy and procedure documentation
4. **Audit Trails**: Complete logging of security events
5. **Regular Assessment**: Periodic compliance reviews
6. **Remediation Tracking**: Systematic violation resolution
7. **Training**: Security awareness for development teams
8. **Vendor Management**: Third-party component security validation

**Compliance Validation Process:**
1. **Policy Definition**: Establish security requirements
2. **Implementation**: Deploy security controls
3. **Monitoring**: Continuous compliance checking
4. **Assessment**: Regular audit and review
5. **Remediation**: Address identified gaps
6. **Reporting**: Compliance status documentation
</details>

---

## 🏆 Performance Assessment

### Scoring Rubric

| Score Range | Grade | Performance Level |
|-------------|-------|-------------------|
| 90-100 | A+ | Expert Level - Security Architect |
| 80-89 | A | Advanced - Security Engineer |
| 75-79 | B+ | Proficient - Secure Operations |
| 65-74 | B | Competent - Basic Security |
| 55-64 | C | Developing - Security Aware |
| Below 55 | F | Needs Review |

### Assessment Breakdown

**Section A: Image Security (25 points)**
- Secure Dockerfile practices
- Vulnerability scanning integration
- Base image selection and optimization

**Section B: Runtime Security (25 points)**
- Container isolation mechanisms
- Access control implementation
- Security profile configuration

**Section C: Secrets & Network Security (25 points)**
- External secrets management
- Network segmentation and encryption
- Service-to-service authentication

**Section D: Compliance & Monitoring (25 points)**
- Security monitoring systems
- Compliance framework implementation
- Audit and reporting procedures

## 🎯 Remediation Plan

### If you scored below 75:

#### Review These Topics:
1. **Container security fundamentals and threat model**
2. **Secure image building and vulnerability management**
3. **Runtime security controls and isolation**
4. **Secrets management best practices**
5. **Network security and compliance frameworks**

#### Recommended Actions:
1. **Practice secure Dockerfile** creation and optimization
2. **Set up vulnerability scanning** in CI/CD pipelines
3. **Experiment with security tools** (Falco, Trivy, etc.)
4. **Study compliance frameworks** (CIS, SOC 2, etc.)
5. **Implement monitoring solutions** for security events

#### Additional Resources:
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [OWASP Container Security](https://owasp.org/www-project-container-security/)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)
- Practice with the lab exercises

## ✅ Next Steps

### If you passed (75+):
- Proceed to **[Chapter 09: Docker Best Practices](../09-docker-best-practices/README.md)**
- Consider advanced security certifications
- Implement security solutions in your organization

### If you need to improve:
- Review the failed sections
- Complete additional security exercises
- Retake the checkpoint when ready

---

**🎉 Congratulations on completing the Docker Security checkpoint!**

Container security is critical for production deployments. These skills enable you to build and operate secure containerized applications that meet enterprise security standards.

---

**[⬅️ Back to Chapter 08](../README.md)** | **[Next: Chapter 09 ➡️](../09-docker-best-practices/README.md)** 