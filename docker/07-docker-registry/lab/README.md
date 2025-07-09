# 🧪 Lab 07: Docker Registry - Private Registry Management

In this lab, you'll practice advanced Docker Registry concepts including private registry deployment, security implementation, content trust, monitoring, and enterprise-grade registry operations.

## 🎯 Lab Objectives

By completing this lab, you will:
- Deploy and configure secure private Docker registries
- Implement authentication and authorization systems
- Set up content trust and image signing
- Configure registry monitoring and alerting
- Implement automated registry maintenance
- Practice enterprise registry patterns

## 📋 Prerequisites

- Docker and Docker Compose installed
- Understanding of Docker images and containers
- Basic knowledge of networking and security concepts
- Text editor (VS Code, nano, vim)

## 🚀 Lab Exercises

### Exercise 1: Basic Private Registry Setup

**Goal:** Deploy a basic private Docker registry with authentication.

#### Step 1: Project Structure Setup

```bash
# Create project structure
mkdir -p registry-lab/{config,auth,certs,monitoring,scripts}
cd registry-lab

# Create basic files
touch docker-compose.yml
touch .env
```

#### Step 2: Generate SSL Certificates

```bash
# Create self-signed certificates for development
mkdir -p certs
openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout certs/domain.key \
  -x509 -days 365 \
  -out certs/domain.crt \
  -subj "/C=US/ST=CA/L=San Francisco/O=RegistryLab/CN=registry.local"

# Set proper permissions
chmod 600 certs/domain.key
chmod 644 certs/domain.crt

echo "✅ SSL certificates generated"
```

#### Step 3: Create Registry Configuration

```yaml
# Create config/registry.yml
cat > config/registry.yml << 'EOF'
version: 0.1
log:
  accesslog:
    disabled: false
  level: info
  formatter: text
  fields:
    service: registry
    environment: development

storage:
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true
  cache:
    blobdescriptor: inmemory

http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
    Access-Control-Allow-Origin: ['*']
    Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
    Access-Control-Allow-Headers: ['Authorization', 'Accept', 'Cache-Control']
  tls:
    certificate: /certs/domain.crt
    key: /certs/domain.key
    minimumtls: tls1.2

auth:
  htpasswd:
    realm: "Registry Realm"
    path: /auth/htpasswd

validation:
  disabled: false

health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3

notifications:
  events:
    includereferences: true
  endpoints:
    - name: webhook
      url: http://webhook-service:8080/registry
      timeout: 5s
      threshold: 5
      backoff: 1s
EOF
```

#### Step 4: Create Authentication

```bash
# Create user accounts
mkdir -p auth

# Create htpasswd file with users
docker run --rm \
  --entrypoint htpasswd \
  httpd:2 -Bbn admin adminpass123 > auth/htpasswd

docker run --rm \
  --entrypoint htpasswd \
  httpd:2 -Bbn developer devpass123 >> auth/htpasswd

docker run --rm \
  --entrypoint htpasswd \
  httpd:2 -Bbn readonly readpass123 >> auth/htpasswd

echo "✅ User accounts created: admin, developer, readonly"
```

#### Step 5: Basic Registry Compose

```yaml
# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  registry:
    image: registry:2
    container_name: private-registry
    ports:
      - "5000:5000"
    environment:
      REGISTRY_CONFIG_PATH: /etc/registry/config.yml
    volumes:
      - ./config/registry.yml:/etc/registry/config.yml:ro
      - ./auth:/auth:ro
      - ./certs:/certs:ro
      - registry-data:/var/lib/registry
    networks:
      - registry-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "--no-check-certificate", "https://localhost:5000/v2/"]
      interval: 30s
      timeout: 5s
      retries: 3

  registry-ui:
    image: joxit/docker-registry-ui:latest
    container_name: registry-ui
    ports:
      - "8080:80"
    environment:
      - SINGLE_REGISTRY=true
      - REGISTRY_TITLE=Private Docker Registry
      - DELETE_IMAGES=true
      - SHOW_CONTENT_DIGEST=true
      - NGINX_PROXY_PASS_URL=https://registry:5000
      - SHOW_CATALOG_NB_TAGS=true
      - CATALOG_MIN_BRANCHES=1
      - CATALOG_MAX_BRANCHES=1
      - TAGLIST_PAGE_SIZE=100
      - REGISTRY_SECURED=true
      - CATALOG_ELEMENTS_LIMIT=1000
    depends_on:
      - registry
    networks:
      - registry-network
    restart: unless-stopped

volumes:
  registry-data:
    driver: local

networks:
  registry-network:
    driver: bridge
EOF
```

#### Step 6: Test Basic Registry

```bash
# Start the registry
docker-compose up -d

# Check services status
docker-compose ps

# Add registry.local to /etc/hosts (for testing)
echo "127.0.0.1 registry.local" | sudo tee -a /etc/hosts

# Test registry API
curl -k -u admin:adminpass123 https://registry.local:5000/v2/

# Push a test image
docker pull alpine:latest
docker tag alpine:latest registry.local:5000/test/alpine:latest

# Configure Docker to trust the certificate (development only)
sudo mkdir -p /etc/docker/certs.d/registry.local:5000
sudo cp certs/domain.crt /etc/docker/certs.d/registry.local:5000/ca.crt

# Login and push
docker login registry.local:5000 -u admin -p adminpass123
docker push registry.local:5000/test/alpine:latest

echo "🌐 Registry UI available at: http://localhost:8080"
```

### Exercise 2: Advanced Security Implementation

**Goal:** Implement token-based authentication and RBAC.

#### Step 1: Create Authentication Server

```python
# Create scripts/auth-server.py
cat > scripts/auth-server.py << 'EOF'
#!/usr/bin/env python3

from flask import Flask, request, jsonify
import jwt
import datetime
import os
import json
from functools import wraps

app = Flask(__name__)

# Configuration
SECRET_KEY = os.getenv('JWT_SECRET', 'registry-auth-secret-key')
ISSUER = os.getenv('TOKEN_ISSUER', 'registry-auth')
AUDIENCE = os.getenv('TOKEN_AUDIENCE', 'registry')

# RBAC Configuration
ROLES = {
    'admin': {
        'repositories': ['*'],
        'actions': ['push', 'pull', 'delete']
    },
    'developer': {
        'repositories': ['app/*', 'library/*'],
        'actions': ['push', 'pull']
    },
    'readonly': {
        'repositories': ['*'],
        'actions': ['pull']
    },
    'ci': {
        'repositories': ['app/production/*', 'app/staging/*'],
        'actions': ['push', 'pull']
    }
}

USERS = {
    'admin': {
        'password': 'adminpass123',
        'roles': ['admin']
    },
    'developer': {
        'password': 'devpass123', 
        'roles': ['developer']
    },
    'readonly': {
        'password': 'readpass123',
        'roles': ['readonly']
    },
    'ci-user': {
        'password': 'cipass123',
        'roles': ['ci']
    }
}

def verify_credentials(username, password):
    """Verify user credentials"""
    user = USERS.get(username)
    if user and user['password'] == password:
        return user
    return None

def check_permission(user_roles, repository, action):
    """Check if user has permission for action on repository"""
    for role_name in user_roles:
        role = ROLES.get(role_name, {})
        
        # Check if action is allowed
        if action not in role.get('actions', []):
            continue
        
        # Check repository access
        allowed_repos = role.get('repositories', [])
        for repo_pattern in allowed_repos:
            if match_repository(repository, repo_pattern):
                return True
    
    return False

def match_repository(repository, pattern):
    """Match repository against pattern (supports wildcards)"""
    if pattern == '*':
        return True
    
    if pattern.endswith('/*'):
        prefix = pattern[:-2]
        return repository.startswith(prefix + '/')
    
    return repository == pattern

def generate_token(username, scope, access_rights):
    """Generate JWT token for registry access"""
    now = datetime.datetime.utcnow()
    
    payload = {
        'iss': ISSUER,
        'aud': AUDIENCE,
        'sub': username,
        'iat': now,
        'exp': now + datetime.timedelta(hours=1),
        'access': [{
            'type': 'repository',
            'name': scope,
            'actions': access_rights
        }]
    }
    
    token = jwt.encode(payload, SECRET_KEY, algorithm='HS256')
    return token

@app.route('/auth', methods=['GET'])
def auth():
    """Docker registry authentication endpoint"""
    try:
        # Get parameters
        username = request.args.get('account', '')
        service = request.args.get('service', '')
        scope = request.args.get('scope', '')
        
        # Get credentials from Authorization header
        auth_header = request.headers.get('Authorization', '')
        if auth_header.startswith('Basic '):
            import base64
            try:
                encoded_credentials = auth_header[6:]
                decoded_credentials = base64.b64decode(encoded_credentials).decode('utf-8')
                username, password = decoded_credentials.split(':', 1)
            except Exception:
                return jsonify({'error': 'Invalid authorization header'}), 401
        else:
            return jsonify({'error': 'Basic authentication required'}), 401
        
        # Parse scope (e.g., "repository:myapp:push,pull")
        if scope:
            try:
                scope_parts = scope.split(':')
                scope_type = scope_parts[0]
                repo_name = scope_parts[1]
                actions = scope_parts[2].split(',') if len(scope_parts) > 2 else []
            except IndexError:
                return jsonify({'error': 'Invalid scope format'}), 400
        else:
            actions = []
            repo_name = ''
        
        # Verify credentials
        user = verify_credentials(username, password)
        if not user:
            return jsonify({'error': 'Invalid credentials'}), 401
        
        # Check permissions
        allowed_actions = []
        for action in actions:
            if check_permission(user['roles'], repo_name, action):
                allowed_actions.append(action)
        
        if actions and not allowed_actions:
            return jsonify({'error': 'Insufficient permissions'}), 403
        
        # Generate token
        token = generate_token(username, repo_name, allowed_actions)
        
        response = {
            'token': token,
            'access_token': token,
            'expires_in': 3600,
            'issued_at': datetime.datetime.utcnow().isoformat() + 'Z'
        }
        
        return jsonify(response)
        
    except Exception as e:
        app.logger.error(f"Auth error: {e}")
        return jsonify({'error': 'Authentication failed'}), 500

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'})

@app.route('/users/<username>/permissions')
def get_user_permissions(username):
    """Get user permissions (admin endpoint)"""
    user = USERS.get(username)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    permissions = {
        'username': username,
        'roles': user['roles'],
        'repositories': [],
        'actions': set()
    }
    
    for role_name in user['roles']:
        role = ROLES.get(role_name, {})
        permissions['repositories'].extend(role.get('repositories', []))
        permissions['actions'].update(role.get('actions', []))
    
    permissions['actions'] = list(permissions['actions'])
    permissions['repositories'] = list(set(permissions['repositories']))
    
    return jsonify(permissions)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=False)
EOF

# Create requirements
cat > scripts/requirements.txt << 'EOF'
Flask==2.3.2
PyJWT==2.8.0
EOF

# Create Dockerfile for auth server
cat > scripts/Dockerfile.auth << 'EOF'
FROM python:3.11-alpine

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY auth-server.py .

EXPOSE 5001

CMD ["python", "auth-server.py"]
EOF
```

#### Step 2: Update Registry for Token Auth

```yaml
# Create docker-compose.secure.yml
cat > docker-compose.secure.yml << 'EOF'
version: '3.8'

services:
  registry:
    image: registry:2
    container_name: secure-registry
    ports:
      - "5000:5000"
    environment:
      REGISTRY_AUTH: token
      REGISTRY_AUTH_TOKEN_REALM: https://auth-server:5001/auth
      REGISTRY_AUTH_TOKEN_SERVICE: registry
      REGISTRY_AUTH_TOKEN_ISSUER: registry-auth
      REGISTRY_AUTH_TOKEN_ROOTCERTBUNDLE: /certs/domain.crt
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /var/lib/registry
      REGISTRY_STORAGE_DELETE_ENABLED: "true"
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/domain.crt
      REGISTRY_HTTP_TLS_KEY: /certs/domain.key
    volumes:
      - ./certs:/certs:ro
      - registry-data:/var/lib/registry
    depends_on:
      - auth-server
    networks:
      - registry-network
    restart: unless-stopped

  auth-server:
    build:
      context: ./scripts
      dockerfile: Dockerfile.auth
    container_name: auth-server
    ports:
      - "5001:5001"
    environment:
      - JWT_SECRET=your-super-secret-jwt-key
      - TOKEN_ISSUER=registry-auth
      - TOKEN_AUDIENCE=registry
    networks:
      - registry-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5001/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  registry-ui:
    image: joxit/docker-registry-ui:latest
    container_name: secure-registry-ui
    ports:
      - "8080:80"
    environment:
      - SINGLE_REGISTRY=true
      - REGISTRY_TITLE=Secure Docker Registry
      - DELETE_IMAGES=true
      - SHOW_CONTENT_DIGEST=true
      - NGINX_PROXY_PASS_URL=https://registry:5000
      - REGISTRY_SECURED=true
      - CATALOG_ELEMENTS_LIMIT=1000
    depends_on:
      - registry
    networks:
      - registry-network
    restart: unless-stopped

volumes:
  registry-data:
    driver: local

networks:
  registry-network:
    driver: bridge
EOF
```

#### Step 3: Test Secure Registry

```bash
# Stop basic registry
docker-compose down

# Start secure registry
docker-compose -f docker-compose.secure.yml up -d --build

# Test authentication server
curl http://localhost:5001/health

# Test user permissions
curl http://localhost:5001/users/admin/permissions
curl http://localhost:5001/users/developer/permissions

# Test registry access
docker login registry.local:5000 -u developer -p devpass123

# Try to push to allowed repository
docker tag alpine:latest registry.local:5000/app/test:latest
docker push registry.local:5000/app/test:latest

# Try to push to restricted repository (should fail)
docker tag alpine:latest registry.local:5000/system/core:latest
# This should fail with insufficient permissions
docker push registry.local:5000/system/core:latest || echo "❌ Permission denied as expected"
```

### Exercise 3: Content Trust and Image Signing

**Goal:** Implement Docker Content Trust with Notary.

#### Step 1: Enable Content Trust

```bash
# Create signing keys directory
mkdir -p signing-keys

# Enable Docker Content Trust
export DOCKER_CONTENT_TRUST=1
export DOCKER_CONTENT_TRUST_SERVER=https://notary.local:4443

# Generate root key
docker trust key generate root
mv root.pub signing-keys/
mv ~/.docker/trust/private/root_keys/* signing-keys/

# Generate repository key
docker trust key generate repository
mv repository.pub signing-keys/
```

#### Step 2: Cosign Alternative (Modern Approach)

```bash
# Install Cosign
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
chmod +x cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign

# Generate key pair
cosign generate-key-pair
mv cosign.key signing-keys/
mv cosign.pub signing-keys/

# Sign image with Cosign
docker pull alpine:latest
docker tag alpine:latest registry.local:5000/signed/alpine:latest
docker push registry.local:5000/signed/alpine:latest

# Sign the pushed image
COSIGN_PASSWORD="" cosign sign --key signing-keys/cosign.key registry.local:5000/signed/alpine:latest

# Verify signature
cosign verify --key signing-keys/cosign.pub registry.local:5000/signed/alpine:latest

echo "✅ Image signed and verified with Cosign"
```

### Exercise 4: Registry Monitoring and Alerting

**Goal:** Set up comprehensive monitoring for the registry.

#### Step 1: Monitoring Stack

```yaml
# Create docker-compose.monitoring.yml
cat > docker-compose.monitoring.yml << 'EOF'
version: '3.8'

services:
  registry:
    image: registry:2
    ports:
      - "5000:5000"
    environment:
      REGISTRY_HTTP_DEBUG_ADDR: :5001
      REGISTRY_HTTP_DEBUG_PROMETHEUS_ENABLED: "true"
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /var/lib/registry
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/domain.crt
      REGISTRY_HTTP_TLS_KEY: /certs/domain.key
    volumes:
      - ./certs:/certs:ro
      - registry-data:/var/lib/registry
    networks:
      - registry-network
      - monitoring
    restart: unless-stopped

  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./monitoring/rules:/etc/prometheus/rules:ro
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - monitoring
    restart: unless-stopped

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana-data:/var/lib/grafana
      - ./monitoring/grafana:/etc/grafana/provisioning:ro
    networks:
      - monitoring
    restart: unless-stopped

  alertmanager:
    image: prom/alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager-data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=http://localhost:9093'
    networks:
      - monitoring
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter
    ports:
      - "9100:9100"
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    networks:
      - monitoring
    restart: unless-stopped

volumes:
  registry-data:
  prometheus-data:
  grafana-data:
  alertmanager-data:

networks:
  registry-network:
  monitoring:
EOF
```

#### Step 2: Monitoring Configuration

```yaml
# Create monitoring/prometheus.yml
mkdir -p monitoring/grafana/{dashboards,datasources}
cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'registry'
    static_configs:
      - targets: ['registry:5001']
    metrics_path: /metrics

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
EOF

# Create alert rules
mkdir -p monitoring/rules
cat > monitoring/rules/registry.yml << 'EOF'
groups:
  - name: registry.rules
    rules:
      - alert: RegistryDown
        expr: up{job="registry"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Registry instance is down"
          description: "Registry {{ $labels.instance }} has been down for more than 1 minute"

      - alert: RegistryHighErrorRate
        expr: rate(registry_http_requests_total{code=~"5.."}[5m]) > 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High error rate in registry"
          description: "Registry has error rate of {{ $value }} errors per second"

      - alert: RegistryStorageSpace
        expr: (registry_filesystem_free_bytes / registry_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Registry running out of storage space"
          description: "Registry storage is {{ $value }}% full"
EOF

# Create AlertManager config
cat > monitoring/alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alertmanager@example.org'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://webhook-service:8080/alerts'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF
```

#### Step 3: Registry Monitor Script

```python
# Create scripts/registry-monitor.py
cat > scripts/registry-monitor.py << 'EOF'
#!/usr/bin/env python3

import requests
import time
import json
import logging
from datetime import datetime
from typing import List, Dict

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class RegistryHealthMonitor:
    def __init__(self, registry_url: str, auth: tuple = None):
        self.registry_url = registry_url.rstrip('/')
        self.auth = auth
        
    def check_health(self) -> Dict:
        """Check registry health"""
        health_data = {
            'timestamp': datetime.now().isoformat(),
            'status': 'unknown',
            'checks': {}
        }
        
        try:
            # Basic connectivity
            response = requests.get(f"{self.registry_url}/v2/", 
                                  auth=self.auth, timeout=10, verify=False)
            health_data['checks']['connectivity'] = response.status_code == 200
            
            # Catalog endpoint
            response = requests.get(f"{self.registry_url}/v2/_catalog", 
                                  auth=self.auth, timeout=10, verify=False)
            health_data['checks']['catalog'] = response.status_code == 200
            
            if response.status_code == 200:
                repos = response.json().get('repositories', [])
                health_data['repository_count'] = len(repos)
            
            # Overall status
            if all(health_data['checks'].values()):
                health_data['status'] = 'healthy'
            else:
                health_data['status'] = 'unhealthy'
                
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            health_data['status'] = 'error'
            health_data['error'] = str(e)
        
        return health_data
    
    def get_repository_stats(self) -> Dict:
        """Get repository statistics"""
        try:
            response = requests.get(f"{self.registry_url}/v2/_catalog", 
                                  auth=self.auth, timeout=10, verify=False)
            
            if response.status_code != 200:
                return {'error': 'Cannot access catalog'}
            
            repos = response.json().get('repositories', [])
            stats = {
                'total_repositories': len(repos),
                'repositories': {}
            }
            
            for repo in repos[:10]:  # Limit to first 10 for demo
                try:
                    tag_response = requests.get(f"{self.registry_url}/v2/{repo}/tags/list",
                                              auth=self.auth, timeout=5, verify=False)
                    if tag_response.status_code == 200:
                        tags = tag_response.json().get('tags', [])
                        stats['repositories'][repo] = {
                            'tag_count': len(tags),
                            'tags': tags[:5]  # Show first 5 tags
                        }
                except Exception as e:
                    stats['repositories'][repo] = {'error': str(e)}
            
            return stats
            
        except Exception as e:
            return {'error': str(e)}
    
    def monitor_continuously(self, interval: int = 60):
        """Monitor registry continuously"""
        logger.info(f"Starting continuous monitoring (interval: {interval}s)")
        
        while True:
            try:
                health = self.check_health()
                stats = self.get_repository_stats()
                
                logger.info(f"Registry Status: {health['status']}")
                logger.info(f"Repository Count: {stats.get('total_repositories', 'unknown')}")
                
                if health['status'] != 'healthy':
                    logger.warning(f"Registry unhealthy: {health}")
                
                time.sleep(interval)
                
            except KeyboardInterrupt:
                logger.info("Monitoring stopped by user")
                break
            except Exception as e:
                logger.error(f"Monitoring error: {e}")
                time.sleep(30)

if __name__ == "__main__":
    monitor = RegistryHealthMonitor(
        "https://registry.local:5000",
        auth=("admin", "adminpass123")
    )
    monitor.monitor_continuously()
EOF

chmod +x scripts/registry-monitor.py
```

#### Step 4: Start Monitoring

```bash
# Start monitoring stack
docker-compose -f docker-compose.monitoring.yml up -d

# Wait for services to start
sleep 30

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Grafana (admin/admin)
echo "📊 Grafana: http://localhost:3000"
echo "📈 Prometheus: http://localhost:9090"
echo "🚨 AlertManager: http://localhost:9093"

# Run registry monitor
python3 scripts/registry-monitor.py &
MONITOR_PID=$!

# Generate some traffic
for i in {1..5}; do
    docker pull alpine:latest
    docker tag alpine:latest registry.local:5000/test/alpine:v$i
    docker push registry.local:5000/test/alpine:v$i
    sleep 10
done

# Stop monitor
kill $MONITOR_PID
```

### Exercise 5: Registry Maintenance and Cleanup

**Goal:** Implement automated registry maintenance.

#### Step 1: Create Cleanup Script

```python
# Create scripts/registry-cleanup.py
cat > scripts/registry-cleanup.py << 'EOF'
#!/usr/bin/env python3

import requests
import argparse
import subprocess
from datetime import datetime, timedelta
import json

class RegistryCleanup:
    def __init__(self, registry_url: str, auth: tuple = None):
        self.registry_url = registry_url.rstrip('/')
        self.auth = auth
        
    def get_repositories(self):
        """Get all repositories"""
        response = requests.get(f"{self.registry_url}/v2/_catalog", 
                              auth=self.auth, verify=False)
        response.raise_for_status()
        return response.json().get('repositories', [])
    
    def get_tags(self, repository: str):
        """Get tags for repository"""
        response = requests.get(f"{self.registry_url}/v2/{repository}/tags/list",
                              auth=self.auth, verify=False)
        response.raise_for_status()
        return response.json().get('tags', [])
    
    def get_manifest_digest(self, repository: str, tag: str):
        """Get manifest digest for tag"""
        headers = {
            'Accept': 'application/vnd.docker.distribution.manifest.v2+json'
        }
        response = requests.get(f"{self.registry_url}/v2/{repository}/manifests/{tag}",
                              headers=headers, auth=self.auth, verify=False)
        response.raise_for_status()
        return response.headers.get('Docker-Content-Digest')
    
    def delete_manifest(self, repository: str, digest: str):
        """Delete manifest by digest"""
        response = requests.delete(f"{self.registry_url}/v2/{repository}/manifests/{digest}",
                                 auth=self.auth, verify=False)
        return response.status_code == 202
    
    def cleanup_old_tags(self, repository: str, keep_count: int = 5, dry_run: bool = True):
        """Clean up old tags, keeping the newest ones"""
        tags = self.get_tags(repository)
        
        if len(tags) <= keep_count:
            print(f"Repository {repository}: Only {len(tags)} tags, keeping all")
            return []
        
        # Sort tags (simple alphabetical, in production you'd use creation date)
        tags_sorted = sorted(tags, reverse=True)
        tags_to_keep = tags_sorted[:keep_count]
        tags_to_delete = tags_sorted[keep_count:]
        
        deleted_tags = []
        
        for tag in tags_to_delete:
            try:
                digest = self.get_manifest_digest(repository, tag)
                if digest:
                    if not dry_run:
                        if self.delete_manifest(repository, digest):
                            deleted_tags.append(tag)
                            print(f"✅ Deleted {repository}:{tag}")
                        else:
                            print(f"❌ Failed to delete {repository}:{tag}")
                    else:
                        deleted_tags.append(tag)
                        print(f"[DRY RUN] Would delete {repository}:{tag}")
                        
            except Exception as e:
                print(f"Error deleting {repository}:{tag}: {e}")
        
        return deleted_tags
    
    def cleanup_all_repositories(self, keep_count: int = 5, dry_run: bool = True):
        """Clean up all repositories"""
        repositories = self.get_repositories()
        
        print(f"🧹 Cleaning up {len(repositories)} repositories")
        print(f"Keeping {keep_count} newest tags per repository")
        print(f"Mode: {'DRY RUN' if dry_run else 'LIVE'}")
        
        total_deleted = 0
        
        for repo in repositories:
            print(f"\n📦 Processing {repo}")
            deleted = self.cleanup_old_tags(repo, keep_count, dry_run)
            total_deleted += len(deleted)
        
        print(f"\n📊 Summary: {total_deleted} tags processed")
        
        return total_deleted

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Registry cleanup tool')
    parser.add_argument('--registry-url', default='https://registry.local:5000')
    parser.add_argument('--username', default='admin')
    parser.add_argument('--password', default='adminpass123')
    parser.add_argument('--keep-count', type=int, default=3)
    parser.add_argument('--dry-run', action='store_true', default=True)
    parser.add_argument('--live', action='store_true', help='Actually perform deletions')
    
    args = parser.parse_args()
    
    if args.live:
        args.dry_run = False
    
    cleanup = RegistryCleanup(args.registry_url, (args.username, args.password))
    cleanup.cleanup_all_repositories(args.keep_count, args.dry_run)
EOF

chmod +x scripts/registry-cleanup.py
```

#### Step 2: Test Cleanup

```bash
# Create multiple tags for testing
for i in {1..10}; do
    docker tag alpine:latest registry.local:5000/test/cleanup:v$i
    docker push registry.local:5000/test/cleanup:v$i
done

# Run cleanup (dry run)
python3 scripts/registry-cleanup.py --dry-run

# Run cleanup (live)
python3 scripts/registry-cleanup.py --live --keep-count 3

# Verify cleanup
curl -k -u admin:adminpass123 https://registry.local:5000/v2/test/cleanup/tags/list
```

## ✅ Lab Verification

### Verification Steps

1. **Basic Registry Verification:**
   ```bash
   # Test registry API
   curl -k -u admin:adminpass123 https://registry.local:5000/v2/
   
   # Test image push/pull
   docker push registry.local:5000/test/verification:latest
   docker pull registry.local:5000/test/verification:latest
   ```

2. **Security Verification:**
   ```bash
   # Test RBAC
   docker login registry.local:5000 -u developer -p devpass123
   docker push registry.local:5000/app/allowed:latest  # Should work
   # docker push registry.local:5000/system/denied:latest  # Should fail
   ```

3. **Monitoring Verification:**
   ```bash
   # Check Prometheus metrics
   curl http://localhost:9090/api/v1/query?query=up
   
   # Check registry metrics
   curl http://localhost:9090/api/v1/query?query=registry_http_requests_total
   ```

4. **Cleanup Verification:**
   ```bash
   # Verify cleanup worked
   python3 scripts/registry-cleanup.py --dry-run
   ```

### Expected Outcomes

- Private registry should be accessible with proper authentication
- RBAC should enforce repository-level permissions
- Monitoring should show registry health and metrics
- Content trust should verify image signatures
- Cleanup should remove old tags while preserving recent ones

## 🧹 Cleanup

```bash
# Stop all services
docker-compose down
docker-compose -f docker-compose.secure.yml down
docker-compose -f docker-compose.monitoring.yml down

# Remove volumes
docker volume prune -f

# Remove test images
docker images | grep registry.local | awk '{print $1":"$2}' | xargs docker rmi -f

# Remove hosts entry
sudo sed -i '/registry.local/d' /etc/hosts

# Clean up lab files
rm -rf certs auth config monitoring scripts signing-keys
rm -f docker-compose*.yml .env

echo "🧹 Lab cleanup completed!"
```

## 📚 Additional Challenges

1. **Implement registry replication** across multiple regions
2. **Add vulnerability scanning** integration with Trivy or Clair
3. **Create automated backup** procedures for registry data
4. **Implement rate limiting** to prevent abuse
5. **Add webhook notifications** for push/pull events

## 🎯 Lab Summary

In this lab, you:
- ✅ Deployed secure private Docker registries with TLS and authentication
- ✅ Implemented RBAC with token-based authentication
- ✅ Set up content trust and image signing with Cosign
- ✅ Configured comprehensive monitoring with Prometheus and Grafana
- ✅ Created automated maintenance and cleanup procedures
- ✅ Practiced enterprise registry patterns

**🎉 Congratulations!** You've mastered Docker Registry management for production environments.

---

**[⬅️ Back to Chapter 07](../README.md)** | **[Next: Checkpoint ➡️](../checkpoint.md)** 