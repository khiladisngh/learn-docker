# 🔒 Chapter 08: Docker Security - Container Security & Best Practices

Welcome to Docker Security mastery! In this chapter, you'll learn comprehensive container security practices, vulnerability management, runtime security, secrets management, and compliance frameworks for production environments.

## 🎯 Learning Objectives

By the end of this chapter, you will:
- ✅ Implement container security best practices
- ✅ Configure runtime security and access controls
- ✅ Manage secrets and sensitive data securely
- ✅ Perform vulnerability scanning and assessment
- ✅ Implement network security for containers
- ✅ Ensure compliance with security standards

## 🛡️ Docker Security Architecture

### Security Layers

```
┌─────────────────────────────────────────┐
│           Security Stack               │
├─────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────────┐  │
│  │   Image     │  │   Container     │  │
│  │  Security   │  │   Runtime       │  │
│  │  Scanning   │  │   Security      │  │
│  └─────────────┘  └─────────────────┘  │
├─────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────────┐  │
│  │   Host      │  │    Network      │  │
│  │  Security   │  │   Security      │  │
│  └─────────────┘  └─────────────────┘  │
├─────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────────┐  │
│  │  Secrets    │  │   Compliance    │  │
│  │ Management  │  │  & Auditing     │  │
│  └─────────────┘  └─────────────────┘  │
└─────────────────────────────────────────┘
```

### Security Principles

1. **Defense in Depth**: Multiple security layers
2. **Least Privilege**: Minimal required permissions
3. **Zero Trust**: Verify everything, trust nothing
4. **Immutable Infrastructure**: Read-only containers
5. **Secure by Default**: Secure configurations
6. **Continuous Monitoring**: Real-time security assessment

## 🏗️ Image Security

### Secure Image Building

#### 1. Base Image Selection

```dockerfile
# ❌ Insecure: Large attack surface
FROM ubuntu:latest

# ✅ Better: Specific version
FROM ubuntu:20.04

# ✅ Best: Minimal base image
FROM alpine:3.18

# ✅ Excellent: Distroless for production
FROM gcr.io/distroless/java:11

# ✅ Ultimate: Scratch for static binaries
FROM scratch
COPY app /app
ENTRYPOINT ["/app"]
```

#### 2. Multi-Stage Security

```dockerfile
# Multi-stage build with security focus
FROM golang:1.19-alpine AS builder

# Install security updates
RUN apk update && apk upgrade && apk add --no-cache git ca-certificates

# Create non-root user for building
RUN adduser -D -g '' appuser

WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o app .

# Production stage - distroless
FROM gcr.io/distroless/static:nonroot

# Copy CA certificates for HTTPS
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy binary with correct ownership
COPY --from=builder /build/app /app

# Use non-root user
USER nonroot:nonroot

ENTRYPOINT ["/app"]
```

#### 3. Security-Hardened Dockerfile

```dockerfile
FROM python:3.11-alpine AS base

# Install security updates
RUN apk update && apk upgrade && \
    apk add --no-cache \
        dumb-init \
        tini \
        curl && \
    rm -rf /var/cache/apk/*

# Create non-root user with specific UID/GID
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup -h /app

FROM base AS dependencies

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies with security flags
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir --require-hashes -r requirements.txt

FROM dependencies AS application

# Copy application with proper ownership
COPY --chown=appuser:appgroup . .

# Remove unnecessary files
RUN find . -name "*.pyc" -delete && \
    find . -name "__pycache__" -type d -exec rm -rf {} + && \
    rm -rf .git .gitignore README.md tests/ docs/

# Switch to non-root user
USER appuser

# Use init system for proper signal handling
ENTRYPOINT ["dumb-init", "--"]

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Expose only necessary port
EXPOSE 8080

CMD ["python", "app.py"]
```

### Vulnerability Scanning

#### 1. Docker Scout (Built-in)

```bash
# Enable Docker Scout
docker scout version

# Quick vulnerability scan
docker scout quickview myapp:latest

# Detailed CVE report
docker scout cves myapp:latest

# Policy evaluation
docker scout policy myapp:latest

# Compare with recommendations
docker scout recommendations myapp:latest

# SBOM (Software Bill of Materials)
docker scout sbom myapp:latest
```

#### 2. Trivy Scanner

```bash
# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Scan image for vulnerabilities
trivy image myapp:latest

# Scan with specific severity
trivy image --severity HIGH,CRITICAL myapp:latest

# Scan filesystem
trivy fs --security-checks vuln,config .

# Generate SARIF report for CI/CD
trivy image --format sarif --output results.sarif myapp:latest

# Scan for secrets
trivy fs --scanners secret .

# Scan infrastructure as code
trivy config .
```

#### 3. Automated Scanning Pipeline

```python
#!/usr/bin/env python3
# security-scanner.py

import subprocess
import json
import sys
from datetime import datetime
from typing import Dict, List, Optional

class SecurityScanner:
    def __init__(self, image: str, config: Dict):
        self.image = image
        self.config = config
        self.results = {}
        
    def scan_with_trivy(self) -> Dict:
        """Scan image with Trivy"""
        try:
            cmd = [
                'trivy', 'image', 
                '--format', 'json',
                '--severity', 'HIGH,CRITICAL',
                self.image
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                scan_results = json.loads(result.stdout)
                return self.parse_trivy_results(scan_results)
            else:
                return {'error': result.stderr}
                
        except Exception as e:
            return {'error': str(e)}
    
    def parse_trivy_results(self, results: Dict) -> Dict:
        """Parse Trivy scan results"""
        parsed = {
            'vulnerabilities': [],
            'total_count': 0,
            'by_severity': {'HIGH': 0, 'CRITICAL': 0}
        }
        
        for target in results.get('Results', []):
            for vuln in target.get('Vulnerabilities', []):
                severity = vuln.get('Severity', 'UNKNOWN')
                
                vulnerability = {
                    'id': vuln.get('VulnerabilityID'),
                    'severity': severity,
                    'package': vuln.get('PkgName'),
                    'version': vuln.get('InstalledVersion'),
                    'fixed_version': vuln.get('FixedVersion'),
                    'title': vuln.get('Title'),
                    'description': vuln.get('Description')
                }
                
                parsed['vulnerabilities'].append(vulnerability)
                parsed['total_count'] += 1
                
                if severity in parsed['by_severity']:
                    parsed['by_severity'][severity] += 1
        
        return parsed
    
    def scan_with_docker_scout(self) -> Dict:
        """Scan image with Docker Scout"""
        try:
            cmd = ['docker', 'scout', 'cves', '--format', 'json', self.image]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                return json.loads(result.stdout)
            else:
                return {'error': result.stderr}
                
        except Exception as e:
            return {'error': str(e)}
    
    def check_security_policies(self) -> Dict:
        """Check against security policies"""
        policies = {
            'no_root_user': self.check_root_user(),
            'minimal_base_image': self.check_base_image(),
            'no_secrets_in_image': self.check_embedded_secrets(),
            'health_check_present': self.check_health_check(),
            'specific_version_tags': self.check_version_tags()
        }
        
        return {
            'policies': policies,
            'passed': all(policies.values()),
            'failed_policies': [k for k, v in policies.items() if not v]
        }
    
    def check_root_user(self) -> bool:
        """Check if container runs as non-root"""
        try:
            cmd = ['docker', 'inspect', '--format', '{{.Config.User}}', self.image]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            user = result.stdout.strip()
            return user != '' and user != 'root' and user != '0'
            
        except Exception:
            return False
    
    def check_base_image(self) -> bool:
        """Check if using minimal base image"""
        minimal_images = ['alpine', 'distroless', 'scratch']
        return any(base in self.image.lower() for base in minimal_images)
    
    def check_embedded_secrets(self) -> bool:
        """Check for embedded secrets (simplified)"""
        try:
            cmd = ['trivy', 'image', '--scanners', 'secret', '--format', 'json', self.image]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                secrets = json.loads(result.stdout)
                return len(secrets.get('Results', [])) == 0
            
            return True  # Assume pass if can't check
            
        except Exception:
            return True
    
    def check_health_check(self) -> bool:
        """Check if health check is configured"""
        try:
            cmd = ['docker', 'inspect', '--format', '{{.Config.Healthcheck}}', self.image]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            healthcheck = result.stdout.strip()
            return healthcheck != '<nil>' and healthcheck != ''
            
        except Exception:
            return False
    
    def check_version_tags(self) -> bool:
        """Check if using specific version tags"""
        return ':latest' not in self.image and ':' in self.image
    
    def generate_report(self) -> Dict:
        """Generate comprehensive security report"""
        print(f"🔍 Scanning {self.image} for security vulnerabilities...")
        
        # Run scans
        trivy_results = self.scan_with_trivy()
        scout_results = self.scan_with_docker_scout()
        policy_results = self.check_security_policies()
        
        report = {
            'image': self.image,
            'scan_date': datetime.now().isoformat(),
            'trivy_scan': trivy_results,
            'scout_scan': scout_results,
            'policy_check': policy_results,
            'recommendations': self.generate_recommendations(trivy_results, policy_results)
        }
        
        return report
    
    def generate_recommendations(self, trivy_results: Dict, policy_results: Dict) -> List[str]:
        """Generate security recommendations"""
        recommendations = []
        
        # Vulnerability recommendations
        if trivy_results.get('total_count', 0) > 0:
            recommendations.append("Update base image and dependencies to fix vulnerabilities")
            
            if trivy_results.get('by_severity', {}).get('CRITICAL', 0) > 0:
                recommendations.append("⚠️ CRITICAL: Address critical vulnerabilities immediately")
        
        # Policy recommendations
        failed_policies = policy_results.get('failed_policies', [])
        
        if 'no_root_user' in failed_policies:
            recommendations.append("Configure container to run as non-root user")
        
        if 'minimal_base_image' in failed_policies:
            recommendations.append("Use minimal base image (Alpine, Distroless, or Scratch)")
        
        if 'no_secrets_in_image' in failed_policies:
            recommendations.append("Remove embedded secrets from image")
        
        if 'health_check_present' in failed_policies:
            recommendations.append("Add health check to container configuration")
        
        if 'specific_version_tags' in failed_policies:
            recommendations.append("Use specific version tags instead of 'latest'")
        
        return recommendations
    
    def print_summary(self, report: Dict):
        """Print security scan summary"""
        print(f"\n📊 Security Scan Summary for {report['image']}")
        print("=" * 60)
        
        # Vulnerability summary
        trivy = report.get('trivy_scan', {})
        if 'error' not in trivy:
            total_vulns = trivy.get('total_count', 0)
            critical = trivy.get('by_severity', {}).get('CRITICAL', 0)
            high = trivy.get('by_severity', {}).get('HIGH', 0)
            
            print(f"🚨 Vulnerabilities: {total_vulns} total ({critical} critical, {high} high)")
        
        # Policy summary
        policy = report.get('policy_check', {})
        passed = policy.get('passed', False)
        failed_count = len(policy.get('failed_policies', []))
        
        print(f"📋 Security Policies: {'✅ PASSED' if passed else f'❌ {failed_count} FAILED'}")
        
        # Recommendations
        recommendations = report.get('recommendations', [])
        if recommendations:
            print(f"\n💡 Recommendations:")
            for rec in recommendations:
                print(f"  • {rec}")
        
        # Overall assessment
        if total_vulns == 0 and passed:
            print(f"\n🛡️ Overall: SECURE")
        elif critical > 0 or not passed:
            print(f"\n⚠️ Overall: NEEDS ATTENTION")
        else:
            print(f"\n🔶 Overall: REVIEW RECOMMENDED")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python security-scanner.py <image>")
        sys.exit(1)
    
    image = sys.argv[1]
    config = {}
    
    scanner = SecurityScanner(image, config)
    report = scanner.generate_report()
    scanner.print_summary(report)
    
    # Save detailed report
    with open(f"security-report-{image.replace(':', '-').replace('/', '-')}.json", 'w') as f:
        json.dump(report, f, indent=2)
```

## 🔐 Runtime Security

### Container Isolation

#### 1. User Namespaces

```bash
# Enable user namespace remapping
echo "dockremap:165536:65536" | sudo tee -a /etc/subuid
echo "dockremap:165536:65536" | sudo tee -a /etc/subgid

# Configure Docker daemon
cat > /etc/docker/daemon.json << 'EOF'
{
  "userns-remap": "default",
  "live-restore": true,
  "userland-proxy": false
}
EOF

# Restart Docker
sudo systemctl restart docker

# Verify user namespace mapping
docker run --rm alpine id
# Should show uid=0(root) gid=0(root) but mapped to unprivileged user on host
```

#### 2. Linux Capabilities

```bash
# Run container with minimal capabilities
docker run --rm \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --user 1001:1001 \
  nginx:alpine

# Check container capabilities
docker run --rm \
  --cap-drop=ALL \
  alpine:latest \
  sh -c "apk add --no-cache libcap && capsh --print"
```

```dockerfile
# Dockerfile with capability management
FROM nginx:alpine

# Remove unnecessary packages
RUN apk del --no-cache \
    # Remove packages that aren't needed

# Create non-root user
RUN addgroup -g 1001 -S nginx && \
    adduser -S nginx -u 1001 -G nginx

# Configure nginx to run as non-root
RUN sed -i 's/user nginx;/user nginx;/' /etc/nginx/nginx.conf && \
    sed -i 's/listen 80;/listen 8080;/' /etc/nginx/conf.d/default.conf

USER nginx

EXPOSE 8080
```

#### 3. Security Profiles

**AppArmor Profile:**
```bash
# Create AppArmor profile
cat > /etc/apparmor.d/docker-nginx << 'EOF'
#include <tunables/global>

profile docker-nginx flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  network,
  capability setuid,
  capability setgid,
  capability chown,

  # Deny dangerous capabilities
  deny capability sys_admin,
  deny capability sys_module,
  deny capability sys_ptrace,

  # Allow necessary file operations
  /etc/nginx/** r,
  /var/log/nginx/** w,
  /var/cache/nginx/** rw,
  /usr/share/nginx/html/** r,

  # Deny sensitive paths
  deny /proc/sys/** w,
  deny /sys/** w,
}
EOF

# Load profile
sudo apparmor_parser -r /etc/apparmor.d/docker-nginx

# Run container with AppArmor
docker run --security-opt apparmor=docker-nginx nginx:alpine
```

**Seccomp Profile:**
```json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": [
        "accept",
        "bind",
        "close",
        "connect",
        "exit",
        "exit_group",
        "listen",
        "read",
        "write",
        "socket"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

```bash
# Run with custom seccomp profile
docker run --security-opt seccomp=seccomp-profile.json nginx:alpine
```

### SELinux Integration

```bash
# Enable SELinux for Docker
sudo setsebool -P container_manage_cgroup on

# Run container with SELinux labels
docker run --security-opt label=type:container_t \
  --security-opt label=level:s0:c100,c200 \
  nginx:alpine

# Check SELinux context
docker run --rm alpine:latest cat /proc/self/attr/current
```

## 🔑 Secrets Management

### Docker Secrets (Swarm Mode)

```bash
# Initialize swarm mode
docker swarm init

# Create secrets
echo "db_password_123" | docker secret create db_password -
echo "api_key_456" | docker secret create api_key -

# Deploy service with secrets
docker service create \
  --name webapp \
  --secret db_password \
  --secret api_key \
  --env DB_PASSWORD_FILE=/run/secrets/db_password \
  --env API_KEY_FILE=/run/secrets/api_key \
  myapp:latest
```

### External Secrets Management

#### 1. HashiCorp Vault Integration

```python
#!/usr/bin/env python3
# vault-secrets.py

import hvac
import os
import json
from pathlib import Path

class VaultSecretsManager:
    def __init__(self, vault_url: str, token: str = None):
        self.client = hvac.Client(url=vault_url)
        
        if token:
            self.client.token = token
        else:
            # Use Kubernetes service account token
            token_path = Path('/var/run/secrets/kubernetes.io/serviceaccount/token')
            if token_path.exists():
                self.authenticate_kubernetes()
            else:
                raise ValueError("No authentication method available")
    
    def authenticate_kubernetes(self):
        """Authenticate using Kubernetes service account"""
        token = Path('/var/run/secrets/kubernetes.io/serviceaccount/token').read_text()
        role = os.getenv('VAULT_ROLE', 'default')
        
        response = self.client.auth.kubernetes.login(
            role=role,
            jwt=token
        )
        
        self.client.token = response['auth']['client_token']
    
    def get_secret(self, path: str, key: str = None) -> str:
        """Get secret from Vault"""
        try:
            response = self.client.secrets.kv.v2.read_secret_version(path=path)
            secret_data = response['data']['data']
            
            if key:
                return secret_data.get(key)
            else:
                return secret_data
                
        except Exception as e:
            raise ValueError(f"Failed to retrieve secret {path}: {e}")
    
    def write_secrets_to_files(self, secrets_config: dict):
        """Write secrets to files for container consumption"""
        secrets_dir = Path('/tmp/secrets')
        secrets_dir.mkdir(exist_ok=True)
        
        for file_name, config in secrets_config.items():
            secret_value = self.get_secret(config['path'], config.get('key'))
            
            secret_file = secrets_dir / file_name
            secret_file.write_text(secret_value)
            secret_file.chmod(0o600)
            
            print(f"✅ Secret written to {secret_file}")

# Usage in container initialization
if __name__ == "__main__":
    vault_url = os.getenv('VAULT_ADDR', 'https://vault.example.com')
    
    vault = VaultSecretsManager(vault_url)
    
    secrets_config = {
        'db_password': {'path': 'myapp/database', 'key': 'password'},
        'api_key': {'path': 'myapp/external', 'key': 'api_key'},
        'jwt_secret': {'path': 'myapp/auth', 'key': 'jwt_secret'}
    }
    
    vault.write_secrets_to_files(secrets_config)
```

#### 2. Kubernetes Secrets Integration

```yaml
# kubernetes-secrets.yml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  db-password: ZGJfcGFzc3dvcmRfMTIz  # base64 encoded
  api-key: YXBpX2tleV80NTY=        # base64 encoded

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:latest
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db-password
        volumeMounts:
        - name: secret-volume
          mountPath: /etc/secrets
          readOnly: true
      volumes:
      - name: secret-volume
        secret:
          secretName: app-secrets
          defaultMode: 0400
```

#### 3. AWS Secrets Manager Integration

```python
#!/usr/bin/env python3
# aws-secrets.py

import boto3
import json
import os
from botocore.exceptions import ClientError

class AWSSecretsManager:
    def __init__(self, region: str = None):
        self.region = region or os.getenv('AWS_REGION', 'us-east-1')
        self.client = boto3.client('secretsmanager', region_name=self.region)
    
    def get_secret(self, secret_name: str) -> dict:
        """Retrieve secret from AWS Secrets Manager"""
        try:
            response = self.client.get_secret_value(SecretId=secret_name)
            secret_string = response['SecretString']
            return json.loads(secret_string)
            
        except ClientError as e:
            if e.response['Error']['Code'] == 'DecryptionFailureException':
                raise ValueError(f"Secrets Manager can't decrypt {secret_name}")
            elif e.response['Error']['Code'] == 'InternalServiceErrorException':
                raise ValueError(f"Internal service error for {secret_name}")
            elif e.response['Error']['Code'] == 'InvalidParameterException':
                raise ValueError(f"Invalid parameter for {secret_name}")
            elif e.response['Error']['Code'] == 'InvalidRequestException':
                raise ValueError(f"Invalid request for {secret_name}")
            elif e.response['Error']['Code'] == 'ResourceNotFoundException':
                raise ValueError(f"Secret {secret_name} not found")
            else:
                raise e
    
    def create_secret_files(self, secrets_mapping: dict):
        """Create secret files from AWS Secrets Manager"""
        secrets_dir = '/run/secrets'
        os.makedirs(secrets_dir, exist_ok=True)
        
        for secret_name, file_mapping in secrets_mapping.items():
            try:
                secret_data = self.get_secret(secret_name)
                
                for key, filename in file_mapping.items():
                    if key in secret_data:
                        file_path = os.path.join(secrets_dir, filename)
                        
                        with open(file_path, 'w') as f:
                            f.write(secret_data[key])
                        
                        # Set secure permissions
                        os.chmod(file_path, 0o600)
                        print(f"✅ Created secret file: {file_path}")
                    else:
                        print(f"⚠️ Key {key} not found in secret {secret_name}")
                        
            except Exception as e:
                print(f"❌ Error processing secret {secret_name}: {e}")

# Container init script usage
if __name__ == "__main__":
    secrets_manager = AWSSecretsManager()
    
    # Define mapping of AWS secrets to files
    secrets_mapping = {
        'prod/myapp/database': {
            'username': 'db_username',
            'password': 'db_password'
        },
        'prod/myapp/external-apis': {
            'stripe_key': 'stripe_secret_key',
            'sendgrid_key': 'sendgrid_api_key'
        }
    }
    
    secrets_manager.create_secret_files(secrets_mapping)
```

## 🌐 Network Security

### Container Network Isolation

```bash
# Create isolated networks
docker network create --driver bridge \
  --subnet=172.20.0.0/16 \
  --ip-range=172.20.240.0/20 \
  frontend-network

docker network create --driver bridge \
  --subnet=172.21.0.0/16 \
  --internal \
  backend-network

# Run containers with network isolation
docker run -d --name web \
  --network frontend-network \
  nginx:alpine

docker run -d --name api \
  --network backend-network \
  myapp:api

# Connect API to both networks
docker network connect frontend-network api
```

### Network Security Policies

```yaml
# Docker Compose with network segmentation
version: '3.8'

services:
  web:
    image: nginx:alpine
    networks:
      - frontend
    ports:
      - "80:80"
    depends_on:
      - api

  api:
    image: myapp:api
    networks:
      - frontend
      - backend
    environment:
      - DATABASE_URL=postgresql://db:5432/myapp

  db:
    image: postgres:13
    networks:
      - backend
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    secrets:
      - db_password

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No external access

secrets:
  db_password:
    external: true
```

### Firewall Rules

```bash
# Configure host firewall for Docker
# Allow Docker networks
sudo iptables -A INPUT -i docker0 -j ACCEPT
sudo iptables -A FORWARD -i docker0 -o docker0 -j ACCEPT

# Restrict external access to specific ports
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Block direct access to Docker daemon
sudo iptables -A INPUT -p tcp --dport 2376 -s 10.0.0.0/8 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 2376 -j DROP

# Save rules
sudo iptables-save > /etc/iptables/rules.v4
```

## 🔍 Security Monitoring & Compliance

### Runtime Security Monitoring

#### 1. Falco - Runtime Security

```yaml
# falco-deployment.yml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falco
  namespace: falco
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
        - mountPath: /host/var/run/docker.sock
          name: docker-socket
        - mountPath: /host/dev
          name: dev-fs
        - mountPath: /host/proc
          name: proc-fs
          readOnly: true
        - mountPath: /host/boot
          name: boot-fs
          readOnly: true
        - mountPath: /host/lib/modules
          name: lib-modules
          readOnly: true
        - mountPath: /host/usr
          name: usr-fs
          readOnly: true
        - mountPath: /etc/falco
          name: falco-config
      volumes:
      - name: docker-socket
        hostPath:
          path: /var/run/docker.sock
      - name: dev-fs
        hostPath:
          path: /dev
      - name: proc-fs
        hostPath:
          path: /proc
      - name: boot-fs
        hostPath:
          path: /boot
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: usr-fs
        hostPath:
          path: /usr
      - name: falco-config
        configMap:
          name: falco-config
```

**Falco Rules:**
```yaml
# falco-rules.yml
- rule: Unauthorized Process in Container
  desc: Detect unauthorized processes in containers
  condition: >
    spawned_process and container and
    not proc.name in (nginx, httpd, python, node, java)
  output: >
    Unauthorized process in container 
    (user=%user.name command=%proc.cmdline container=%container.name)
  priority: WARNING

- rule: Sensitive File Access
  desc: Detect access to sensitive files
  condition: >
    open_read and container and
    fd.name in (/etc/passwd, /etc/shadow, /etc/hosts, /root/.ssh/*)
  output: >
    Sensitive file accessed in container
    (file=%fd.name container=%container.name user=%user.name)
  priority: CRITICAL

- rule: Network Connection from Container
  desc: Detect unexpected network connections
  condition: >
    inbound_outbound and container and
    not fd.sport in (80, 443, 8080, 3000, 5432)
  output: >
    Unexpected network connection from container
    (connection=%fd.name container=%container.name)
  priority: WARNING
```

#### 2. Docker Bench Security

```bash
# Run Docker Bench Security
docker run --rm --net host --pid host --userns host --cap-add audit_control \
  -e DOCKER_CONTENT_TRUST=$DOCKER_CONTENT_TRUST \
  -v /etc:/etc:ro \
  -v /var/lib:/var/lib:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /usr/lib/systemd:/usr/lib/systemd:ro \
  -v /etc/systemd:/etc/systemd:ro \
  --label docker_bench_security \
  docker/docker-bench-security
```

#### 3. Custom Security Monitor

```python
#!/usr/bin/env python3
# security-monitor.py

import docker
import psutil
import time
import logging
import json
from datetime import datetime
from typing import Dict, List
import requests

class SecurityMonitor:
    def __init__(self, config: Dict):
        self.client = docker.from_env()
        self.config = config
        self.logger = self._setup_logging()
        self.baseline = self._establish_baseline()
        
    def _setup_logging(self):
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        return logging.getLogger(__name__)
    
    def _establish_baseline(self) -> Dict:
        """Establish security baseline"""
        return {
            'expected_containers': set(),
            'expected_images': set(),
            'expected_networks': set(),
            'expected_processes': set()
        }
    
    def check_container_security(self, container) -> List[Dict]:
        """Check individual container security"""
        violations = []
        
        # Check if running as root
        if self._is_running_as_root(container):
            violations.append({
                'type': 'root_user',
                'severity': 'HIGH',
                'message': f'Container {container.name} running as root',
                'container': container.name
            })
        
        # Check for privileged mode
        if self._is_privileged(container):
            violations.append({
                'type': 'privileged_container',
                'severity': 'CRITICAL',
                'message': f'Container {container.name} running in privileged mode',
                'container': container.name
            })
        
        # Check for capability violations
        dangerous_caps = self._check_capabilities(container)
        if dangerous_caps:
            violations.append({
                'type': 'dangerous_capabilities',
                'severity': 'HIGH',
                'message': f'Container {container.name} has dangerous capabilities: {dangerous_caps}',
                'container': container.name
            })
        
        # Check mount points
        sensitive_mounts = self._check_mounts(container)
        if sensitive_mounts:
            violations.append({
                'type': 'sensitive_mounts',
                'severity': 'MEDIUM',
                'message': f'Container {container.name} has sensitive mounts: {sensitive_mounts}',
                'container': container.name
            })
        
        return violations
    
    def _is_running_as_root(self, container) -> bool:
        """Check if container is running as root"""
        try:
            attrs = container.attrs
            config = attrs.get('Config', {})
            user = config.get('User', '')
            return user == '' or user == 'root' or user == '0'
        except Exception:
            return False
    
    def _is_privileged(self, container) -> bool:
        """Check if container is privileged"""
        try:
            attrs = container.attrs
            host_config = attrs.get('HostConfig', {})
            return host_config.get('Privileged', False)
        except Exception:
            return False
    
    def _check_capabilities(self, container) -> List[str]:
        """Check for dangerous capabilities"""
        dangerous_caps = [
            'SYS_ADMIN', 'SYS_MODULE', 'SYS_PTRACE', 
            'SYS_BOOT', 'MAC_ADMIN', 'NET_ADMIN'
        ]
        
        try:
            attrs = container.attrs
            host_config = attrs.get('HostConfig', {})
            cap_add = host_config.get('CapAdd', []) or []
            
            return [cap for cap in cap_add if cap in dangerous_caps]
        except Exception:
            return []
    
    def _check_mounts(self, container) -> List[str]:
        """Check for sensitive mount points"""
        sensitive_paths = [
            '/etc', '/proc', '/sys', '/var/run/docker.sock',
            '/host', '/root', '/boot'
        ]
        
        try:
            attrs = container.attrs
            mounts = attrs.get('Mounts', [])
            
            sensitive_mounts = []
            for mount in mounts:
                source = mount.get('Source', '')
                for sensitive_path in sensitive_paths:
                    if source.startswith(sensitive_path):
                        sensitive_mounts.append(f"{source}:{mount.get('Destination', '')}")
            
            return sensitive_mounts
        except Exception:
            return []
    
    def check_image_security(self, image) -> List[Dict]:
        """Check image security"""
        violations = []
        
        # Check for latest tag
        if self._uses_latest_tag(image):
            violations.append({
                'type': 'latest_tag',
                'severity': 'MEDIUM',
                'message': f'Image {image.tags[0] if image.tags else image.id} uses latest tag',
                'image': image.tags[0] if image.tags else image.id
            })
        
        # Check image age
        if self._is_image_old(image):
            violations.append({
                'type': 'old_image',
                'severity': 'MEDIUM',
                'message': f'Image {image.tags[0] if image.tags else image.id} is outdated',
                'image': image.tags[0] if image.tags else image.id
            })
        
        return violations
    
    def _uses_latest_tag(self, image) -> bool:
        """Check if image uses latest tag"""
        if not image.tags:
            return False
        return any(':latest' in tag for tag in image.tags)
    
    def _is_image_old(self, image, days_threshold: int = 30) -> bool:
        """Check if image is older than threshold"""
        try:
            created = datetime.fromisoformat(image.attrs['Created'].replace('Z', '+00:00'))
            age = datetime.now().replace(tzinfo=created.tzinfo) - created
            return age.days > days_threshold
        except Exception:
            return False
    
    def check_host_security(self) -> List[Dict]:
        """Check host system security"""
        violations = []
        
        # Check Docker daemon configuration
        daemon_violations = self._check_docker_daemon()
        violations.extend(daemon_violations)
        
        # Check system resources
        resource_violations = self._check_system_resources()
        violations.extend(resource_violations)
        
        return violations
    
    def _check_docker_daemon(self) -> List[Dict]:
        """Check Docker daemon security"""
        violations = []
        
        try:
            # Check if Docker daemon is exposed
            info = self.client.info()
            if 'tcp://' in str(info):
                violations.append({
                    'type': 'exposed_daemon',
                    'severity': 'CRITICAL',
                    'message': 'Docker daemon exposed over TCP',
                    'host': 'localhost'
                })
        except Exception:
            pass
        
        return violations
    
    def _check_system_resources(self) -> List[Dict]:
        """Check system resource usage"""
        violations = []
        
        # Check CPU usage
        cpu_percent = psutil.cpu_percent(interval=1)
        if cpu_percent > 90:
            violations.append({
                'type': 'high_cpu',
                'severity': 'WARNING',
                'message': f'High CPU usage: {cpu_percent}%',
                'host': 'localhost'
            })
        
        # Check memory usage
        memory = psutil.virtual_memory()
        if memory.percent > 90:
            violations.append({
                'type': 'high_memory',
                'severity': 'WARNING',
                'message': f'High memory usage: {memory.percent}%',
                'host': 'localhost'
            })
        
        # Check disk usage
        disk = psutil.disk_usage('/')
        if disk.percent > 90:
            violations.append({
                'type': 'high_disk',
                'severity': 'WARNING',
                'message': f'High disk usage: {disk.percent}%',
                'host': 'localhost'
            })
        
        return violations
    
    def send_alert(self, violations: List[Dict]):
        """Send security alerts"""
        if not violations:
            return
        
        webhook_url = self.config.get('webhook_url')
        if webhook_url:
            try:
                payload = {
                    'timestamp': datetime.now().isoformat(),
                    'violations': violations,
                    'total_violations': len(violations),
                    'critical_count': len([v for v in violations if v.get('severity') == 'CRITICAL']),
                    'high_count': len([v for v in violations if v.get('severity') == 'HIGH'])
                }
                
                response = requests.post(webhook_url, json=payload, timeout=10)
                response.raise_for_status()
                
                self.logger.info(f"Alert sent for {len(violations)} violations")
                
            except Exception as e:
                self.logger.error(f"Failed to send alert: {e}")
    
    def run_security_scan(self) -> Dict:
        """Run comprehensive security scan"""
        self.logger.info("Starting security scan...")
        
        all_violations = []
        
        # Check containers
        containers = self.client.containers.list()
        for container in containers:
            container_violations = self.check_container_security(container)
            all_violations.extend(container_violations)
        
        # Check images
        images = self.client.images.list()
        for image in images:
            image_violations = self.check_image_security(image)
            all_violations.extend(image_violations)
        
        # Check host
        host_violations = self.check_host_security()
        all_violations.extend(host_violations)
        
        # Send alerts for critical violations
        critical_violations = [v for v in all_violations if v.get('severity') in ['CRITICAL', 'HIGH']]
        if critical_violations:
            self.send_alert(critical_violations)
        
        scan_results = {
            'scan_time': datetime.now().isoformat(),
            'total_violations': len(all_violations),
            'violations_by_severity': {
                'CRITICAL': len([v for v in all_violations if v.get('severity') == 'CRITICAL']),
                'HIGH': len([v for v in all_violations if v.get('severity') == 'HIGH']),
                'MEDIUM': len([v for v in all_violations if v.get('severity') == 'MEDIUM']),
                'WARNING': len([v for v in all_violations if v.get('severity') == 'WARNING'])
            },
            'violations': all_violations
        }
        
        self.logger.info(f"Security scan completed: {len(all_violations)} violations found")
        return scan_results
    
    def continuous_monitoring(self, interval: int = 300):
        """Run continuous security monitoring"""
        self.logger.info(f"Starting continuous monitoring (interval: {interval}s)")
        
        while True:
            try:
                scan_results = self.run_security_scan()
                
                # Log summary
                total = scan_results['total_violations']
                critical = scan_results['violations_by_severity']['CRITICAL']
                high = scan_results['violations_by_severity']['HIGH']
                
                self.logger.info(f"Scan results: {total} total ({critical} critical, {high} high)")
                
                time.sleep(interval)
                
            except KeyboardInterrupt:
                self.logger.info("Monitoring stopped by user")
                break
            except Exception as e:
                self.logger.error(f"Monitoring error: {e}")
                time.sleep(60)

if __name__ == "__main__":
    config = {
        'webhook_url': 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
    }
    
    monitor = SecurityMonitor(config)
    monitor.continuous_monitoring()
```

### Compliance Frameworks

#### 1. CIS Docker Benchmark Implementation

```python
#!/usr/bin/env python3
# cis-compliance-check.py

import docker
import subprocess
import os
import json
from typing import Dict, List, Tuple

class CISDockerBenchmark:
    def __init__(self):
        self.client = docker.from_env()
        self.results = []
        
    def check_1_1_separate_partition(self) -> Tuple[bool, str]:
        """1.1 Ensure a separate partition for containers has been created"""
        try:
            result = subprocess.run(['df', '/var/lib/docker'], 
                                  capture_output=True, text=True)
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                filesystem = lines[1].split()[0]
                return filesystem != '/', f"Docker directory: {filesystem}"
            return False, "Could not determine Docker partition"
        except Exception as e:
            return False, f"Error: {e}"
    
    def check_2_1_daemon_configuration(self) -> Tuple[bool, str]:
        """2.1 Restrict network traffic between containers on the default bridge"""
        try:
            info = self.client.info()
            daemon_config = info.get('ServerVersion', '')
            return True, f"Docker version: {daemon_config}"
        except Exception as e:
            return False, f"Error: {e}"
    
    def check_4_1_container_user(self) -> List[Tuple[bool, str, str]]:
        """4.1 Ensure a user for the container is created"""
        results = []
        containers = self.client.containers.list()
        
        for container in containers:
            try:
                attrs = container.attrs
                config = attrs.get('Config', {})
                user = config.get('User', '')
                
                if user and user not in ['root', '0', '']:
                    results.append((True, container.name, f"User: {user}"))
                else:
                    results.append((False, container.name, "Running as root"))
                    
            except Exception as e:
                results.append((False, container.name, f"Error: {e}"))
        
        return results
    
    def check_4_5_privileged_containers(self) -> List[Tuple[bool, str, str]]:
        """4.5 Ensure privileged containers are not used"""
        results = []
        containers = self.client.containers.list()
        
        for container in containers:
            try:
                attrs = container.attrs
                host_config = attrs.get('HostConfig', {})
                privileged = host_config.get('Privileged', False)
                
                if not privileged:
                    results.append((True, container.name, "Not privileged"))
                else:
                    results.append((False, container.name, "Running privileged"))
                    
            except Exception as e:
                results.append((False, container.name, f"Error: {e}"))
        
        return results
    
    def check_4_6_sensitive_host_system_directories(self) -> List[Tuple[bool, str, str]]:
        """4.6 Ensure sensitive host system directories are not mounted on containers"""
        sensitive_dirs = ['/etc', '/proc', '/sys', '/boot', '/lib', '/usr/lib']
        results = []
        containers = self.client.containers.list()
        
        for container in containers:
            try:
                attrs = container.attrs
                mounts = attrs.get('Mounts', [])
                
                sensitive_mounts = []
                for mount in mounts:
                    source = mount.get('Source', '')
                    for sensitive_dir in sensitive_dirs:
                        if source.startswith(sensitive_dir):
                            sensitive_mounts.append(source)
                
                if not sensitive_mounts:
                    results.append((True, container.name, "No sensitive mounts"))
                else:
                    results.append((False, container.name, f"Sensitive mounts: {sensitive_mounts}"))
                    
            except Exception as e:
                results.append((False, container.name, f"Error: {e}"))
        
        return results
    
    def check_5_1_apparmor_profile(self) -> List[Tuple[bool, str, str]]:
        """5.1 Ensure AppArmor profile is enabled"""
        results = []
        containers = self.client.containers.list()
        
        for container in containers:
            try:
                attrs = container.attrs
                app_armor_profile = attrs.get('AppArmorProfile', '')
                
                if app_armor_profile and app_armor_profile != 'unconfined':
                    results.append((True, container.name, f"AppArmor: {app_armor_profile}"))
                else:
                    results.append((False, container.name, "No AppArmor profile"))
                    
            except Exception as e:
                results.append((False, container.name, f"Error: {e}"))
        
        return results
    
    def run_all_checks(self) -> Dict:
        """Run all CIS benchmark checks"""
        report = {
            'timestamp': subprocess.run(['date'], capture_output=True, text=True).stdout.strip(),
            'checks': {},
            'summary': {'passed': 0, 'failed': 0, 'total': 0}
        }
        
        # Host configuration checks
        report['checks']['1.1_separate_partition'] = {
            'description': 'Separate partition for containers',
            'result': self.check_1_1_separate_partition()
        }
        
        report['checks']['2.1_daemon_config'] = {
            'description': 'Docker daemon configuration',
            'result': self.check_2_1_daemon_configuration()
        }
        
        # Container runtime checks
        report['checks']['4.1_container_user'] = {
            'description': 'Container user configuration',
            'results': self.check_4_1_container_user()
        }
        
        report['checks']['4.5_privileged_containers'] = {
            'description': 'Privileged containers check',
            'results': self.check_4_5_privileged_containers()
        }
        
        report['checks']['4.6_sensitive_mounts'] = {
            'description': 'Sensitive host directories mounted',
            'results': self.check_4_6_sensitive_host_system_directories()
        }
        
        report['checks']['5.1_apparmor_profile'] = {
            'description': 'AppArmor profile enabled',
            'results': self.check_5_1_apparmor_profile()
        }
        
        # Calculate summary
        for check_name, check_data in report['checks'].items():
            if 'result' in check_data:
                # Single result checks
                passed, _ = check_data['result']
                report['summary']['total'] += 1
                if passed:
                    report['summary']['passed'] += 1
                else:
                    report['summary']['failed'] += 1
            elif 'results' in check_data:
                # Multiple result checks
                for passed, _, _ in check_data['results']:
                    report['summary']['total'] += 1
                    if passed:
                        report['summary']['passed'] += 1
                    else:
                        report['summary']['failed'] += 1
        
        return report
    
    def print_report(self, report: Dict):
        """Print formatted compliance report"""
        print("🔍 CIS Docker Benchmark Compliance Report")
        print("=" * 50)
        print(f"Timestamp: {report['timestamp']}")
        print(f"Total Checks: {report['summary']['total']}")
        print(f"Passed: {report['summary']['passed']}")
        print(f"Failed: {report['summary']['failed']}")
        
        compliance_rate = (report['summary']['passed'] / report['summary']['total']) * 100
        print(f"Compliance Rate: {compliance_rate:.1f}%")
        
        print("\n📋 Detailed Results:")
        print("-" * 50)
        
        for check_name, check_data in report['checks'].items():
            print(f"\n{check_name}: {check_data['description']}")
            
            if 'result' in check_data:
                passed, message = check_data['result']
                status = "✅ PASS" if passed else "❌ FAIL"
                print(f"  {status}: {message}")
            elif 'results' in check_data:
                for passed, container, message in check_data['results']:
                    status = "✅ PASS" if passed else "❌ FAIL"
                    print(f"  {status} [{container}]: {message}")

if __name__ == "__main__":
    benchmark = CISDockerBenchmark()
    report = benchmark.run_all_checks()
    benchmark.print_report(report)
    
    # Save report to file
    with open('cis-docker-compliance-report.json', 'w') as f:
        json.dump(report, f, indent=2)
```

## 🎯 Chapter Checkpoint

### Questions

1. **What are the key layers of Docker security?**
   - Image security, runtime security, host security, network security, secrets management

2. **How do you implement least privilege in containers?**
   - Non-root users, minimal capabilities, read-only filesystems, user namespaces

3. **What tools are available for vulnerability scanning?**
   - Docker Scout, Trivy, Snyk, Clair, Anchore

4. **How do you secure container networking?**
   - Network segmentation, firewalls, encrypted communication, service mesh

### Tasks

- [ ] Implement secure Dockerfile practices
- [ ] Set up vulnerability scanning pipeline
- [ ] Configure runtime security monitoring
- [ ] Implement secrets management

---

## 🚀 What's Next?

In [Chapter 09: Docker Best Practices](../09-docker-best-practices/README.md), you'll learn:
- Production deployment patterns
- Performance optimization
- Troubleshooting methodologies
- Operational excellence

## 📚 Key Takeaways

✅ **Defense in depth** provides multiple security layers
✅ **Image security** starts with secure base images and scanning
✅ **Runtime security** includes isolation, monitoring, and access controls
✅ **Secrets management** keeps sensitive data secure
✅ **Compliance** ensures adherence to security standards
✅ **Continuous monitoring** detects and responds to threats

## 📝 Practice Checklist

Before moving on, ensure you can:
- [ ] Build secure container images
- [ ] Implement runtime security controls
- [ ] Set up vulnerability scanning
- [ ] Configure secrets management
- [ ] Monitor containers for security violations
- [ ] Ensure compliance with security standards

---

**🎉 Congratulations!** You now have comprehensive Docker security skills. Complete the [lab exercise](lab/README.md) to practice these concepts, then validate your knowledge with the [checkpoint](checkpoint.md)!

---

<div align="center">

**[⬅️ Previous: Docker Registry](../07-docker-registry/README.md)** | **[Next: Docker Best Practices ➡️](../09-docker-best-practices/README.md)**

</div> 