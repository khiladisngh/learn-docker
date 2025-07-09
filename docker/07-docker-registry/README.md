# 🏪 Chapter 07: Docker Registry - Image Distribution & Management

Welcome to advanced Docker Registry management! In this chapter, you'll master private registry setup, image distribution strategies, security implementation, and enterprise-grade registry operations.

## 🎯 Learning Objectives

By the end of this chapter, you will:
- ✅ Deploy and manage private Docker registries
- ✅ Implement registry security and authentication
- ✅ Optimize image distribution and caching
- ✅ Configure content trust and image signing
- ✅ Monitor and maintain registry infrastructure
- ✅ Implement enterprise registry patterns

## 🏗️ Docker Registry Architecture

### Registry Components

```
┌─────────────────────────────────────────┐
│            Docker Registry             │
├─────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────────┐  │
│  │   Registry  │  │   Storage       │  │
│  │   Server    │  │   Backend       │  │
│  │             │  │   (FS/S3/GCS)   │  │
│  └─────────────┘  └─────────────────┘  │
├─────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────────┐  │
│  │    Auth     │  │    Notary       │  │
│  │   Service   │  │   (Signing)     │  │
│  └─────────────┘  └─────────────────┘  │
├─────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────────┐  │
│  │   Reverse   │  │   Monitoring    │  │
│  │    Proxy    │  │   & Logging     │  │
│  └─────────────┘  └─────────────────┘  │
└─────────────────────────────────────────┘
```

### Registry Types

| Type | Use Case | Complexity | Features |
|------|----------|------------|----------|
| **Docker Hub** | Public/private repos | Low | Hosted, webhooks, teams |
| **Local Registry** | Development/testing | Medium | Self-hosted, basic auth |
| **Enterprise Registry** | Production/corporate | High | HA, RBAC, scanning, mirrors |
| **Cloud Registry** | Scalable deployment | Medium | Managed, integrated, global |

## 🚀 Private Registry Deployment

### Basic Registry Setup

```bash
# Simple registry deployment
docker run -d \
  -p 5000:5000 \
  --name registry \
  --restart=always \
  -v registry-data:/var/lib/registry \
  registry:2
```

### Production Registry Configuration

```yaml
# registry-config.yml
version: 0.1
log:
  accesslog:
    disabled: false
  level: info
  formatter: text
  fields:
    service: registry
    environment: production

storage:
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true
  redirect:
    disable: false
  cache:
    blobdescriptor: inmemory

http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
    Access-Control-Allow-Origin: ['*']
    Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
    Access-Control-Allow-Headers: ['Authorization', 'Accept', 'Cache-Control']
  host: https://registry.example.com
  secret: asecretforlocaldevelopment
  tls:
    certificate: /certs/domain.crt
    key: /certs/domain.key
    minimumtls: tls1.2

auth:
  htpasswd:
    realm: basic-realm
    path: /auth/htpasswd

validation:
  manifests:
    urls:
      allow:
        - ^https?://([^/]+\.)*example\.com/
      deny:
        - ^https?://www\.example\.com/

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
      disabled: false
      url: https://webhook.example.com/registry
      headers:
        Authorization: [Bearer <token>]
      timeout: 5s
      threshold: 10
      backoff: 1s
      ignoredmediatypes:
        - application/octet-stream
```

### Docker Compose Registry Stack

```yaml
# docker-compose.registry.yml
version: '3.8'

services:
  registry:
    image: registry:2
    ports:
      - "5000:5000"
    environment:
      REGISTRY_CONFIG_PATH: /etc/registry/config.yml
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /var/lib/registry
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/domain.crt
      REGISTRY_HTTP_TLS_KEY: /certs/domain.key
    volumes:
      - ./config/registry.yml:/etc/registry/config.yml
      - ./auth:/auth
      - ./certs:/certs
      - registry-data:/var/lib/registry
    networks:
      - registry
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:5000/v2/"]
      interval: 30s
      timeout: 5s
      retries: 3

  registry-ui:
    image: joxit/docker-registry-ui:latest
    ports:
      - "8080:80"
    environment:
      - SINGLE_REGISTRY=true
      - REGISTRY_TITLE=Docker Registry UI
      - DELETE_IMAGES=true
      - SHOW_CONTENT_DIGEST=true
      - NGINX_PROXY_PASS_URL=http://registry:5000
      - SHOW_CATALOG_NB_TAGS=true
      - CATALOG_MIN_BRANCHES=1
      - CATALOG_MAX_BRANCHES=1
      - TAGLIST_PAGE_SIZE=100
      - REGISTRY_SECURED=false
      - CATALOG_ELEMENTS_LIMIT=1000
    depends_on:
      - registry
    networks:
      - registry
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/registry.conf:/etc/nginx/conf.d/registry.conf
      - ./certs:/etc/nginx/certs
    depends_on:
      - registry
      - registry-ui
    networks:
      - registry
    restart: unless-stopped

networks:
  registry:
    driver: bridge

volumes:
  registry-data:
    driver: local
```

## 🔐 Registry Security & Authentication

### TLS/SSL Configuration

```bash
# Generate self-signed certificates for development
mkdir -p certs
openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout certs/domain.key \
  -x509 -days 365 \
  -out certs/domain.crt \
  -subj "/C=US/ST=CA/L=San Francisco/O=MyOrg/CN=registry.example.com"

# For production, use Let's Encrypt
certbot certonly --standalone \
  -d registry.example.com \
  --email admin@example.com \
  --agree-tos --no-eff-email
```

### Authentication Methods

#### 1. Basic Authentication (htpasswd)

```bash
# Create htpasswd file
mkdir -p auth
docker run --rm \
  --entrypoint htpasswd \
  httpd:2 -Bbn username password > auth/htpasswd

# Add more users
docker run --rm \
  --entrypoint htpasswd \
  httpd:2 -Bbn admin secretpassword >> auth/htpasswd
```

#### 2. Token-Based Authentication

```python
#!/usr/bin/env python3
# auth-server.py

from flask import Flask, request, jsonify
import jwt
import datetime
import os

app = Flask(__name__)

# Configuration
SECRET_KEY = os.getenv('JWT_SECRET', 'your-secret-key')
ISSUER = os.getenv('TOKEN_ISSUER', 'registry-auth')
AUDIENCE = os.getenv('TOKEN_AUDIENCE', 'registry')

# User database (in production, use proper database)
USERS = {
    'admin': {
        'password': 'admin123',
        'access': ['push', 'pull']
    },
    'developer': {
        'password': 'dev123',
        'access': ['pull']
    },
    'ci': {
        'password': 'ci123',
        'access': ['push', 'pull']
    }
}

def verify_credentials(username, password):
    """Verify user credentials"""
    user = USERS.get(username)
    if user and user['password'] == password:
        return user
    return None

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
    # Get parameters
    username = request.args.get('account', '')
    password = request.authorization.password if request.authorization else ''
    service = request.args.get('service', '')
    scope = request.args.get('scope', '')
    
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
        if action in user['access']:
            allowed_actions.append(action)
    
    if not allowed_actions and actions:
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

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=False)
```

#### 3. OAuth2/OIDC Integration

```yaml
# oauth-registry.yml
services:
  registry:
    image: registry:2
    environment:
      REGISTRY_AUTH: token
      REGISTRY_AUTH_TOKEN_REALM: https://auth.example.com/auth
      REGISTRY_AUTH_TOKEN_SERVICE: registry
      REGISTRY_AUTH_TOKEN_ISSUER: auth-service
      REGISTRY_AUTH_TOKEN_ROOTCERTBUNDLE: /certs/auth.crt
    volumes:
      - ./certs:/certs
      - registry-data:/var/lib/registry

  auth-server:
    build: ./auth-server
    ports:
      - "5001:5001"
    environment:
      - JWT_SECRET=your-super-secret-key
      - TOKEN_ISSUER=auth-service
      - OIDC_PROVIDER=https://your-oidc-provider.com
```

### RBAC (Role-Based Access Control)

```python
#!/usr/bin/env python3
# rbac-auth.py

class RegistryRBAC:
    def __init__(self):
        self.roles = {
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
                'repositories': ['app/production/*'],
                'actions': ['push', 'pull']
            }
        }
        
        self.users = {
            'admin': ['admin'],
            'alice': ['developer'],
            'bob': ['developer'],
            'readonly-user': ['readonly'],
            'ci-service': ['ci']
        }
    
    def check_permission(self, username, repository, action):
        """Check if user has permission for action on repository"""
        user_roles = self.users.get(username, [])
        
        for role_name in user_roles:
            role = self.roles.get(role_name, {})
            
            # Check if action is allowed
            if action not in role.get('actions', []):
                continue
            
            # Check repository access
            allowed_repos = role.get('repositories', [])
            for repo_pattern in allowed_repos:
                if self._match_repository(repository, repo_pattern):
                    return True
        
        return False
    
    def _match_repository(self, repository, pattern):
        """Match repository against pattern (supports wildcards)"""
        if pattern == '*':
            return True
        
        if pattern.endswith('/*'):
            prefix = pattern[:-2]
            return repository.startswith(prefix + '/')
        
        return repository == pattern
    
    def get_user_permissions(self, username):
        """Get all permissions for a user"""
        user_roles = self.users.get(username, [])
        permissions = {
            'repositories': set(),
            'actions': set()
        }
        
        for role_name in user_roles:
            role = self.roles.get(role_name, {})
            permissions['repositories'].update(role.get('repositories', []))
            permissions['actions'].update(role.get('actions', []))
        
        return {
            'repositories': list(permissions['repositories']),
            'actions': list(permissions['actions'])
        }

# Usage example
rbac = RegistryRBAC()

# Check permissions
print(rbac.check_permission('alice', 'app/frontend', 'push'))  # True
print(rbac.check_permission('alice', 'system/core', 'push'))   # False
print(rbac.check_permission('readonly-user', 'app/frontend', 'pull'))  # True
print(rbac.check_permission('readonly-user', 'app/frontend', 'push'))  # False

# Get user permissions
print(rbac.get_user_permissions('alice'))
```

## 📦 Image Distribution Strategies

### Registry Mirroring

```yaml
# registry-mirror.yml
version: '3.8'

services:
  # Primary registry
  registry-primary:
    image: registry:2
    ports:
      - "5000:5000"
    environment:
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /var/lib/registry
      REGISTRY_PROXY_REMOTEURL: https://registry-1.docker.io
    volumes:
      - registry-primary:/var/lib/registry
    networks:
      - registry-network

  # Mirror registry
  registry-mirror:
    image: registry:2
    ports:
      - "5001:5000"
    environment:
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /var/lib/registry
      REGISTRY_PROXY_REMOTEURL: http://registry-primary:5000
    volumes:
      - registry-mirror:/var/lib/registry
    depends_on:
      - registry-primary
    networks:
      - registry-network

  # Pull-through cache
  registry-cache:
    image: registry:2
    ports:
      - "5002:5000"
    environment:
      REGISTRY_PROXY_REMOTEURL: https://registry-1.docker.io
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /var/lib/registry
    volumes:
      - registry-cache:/var/lib/registry
    networks:
      - registry-network

networks:
  registry-network:
    driver: bridge

volumes:
  registry-primary:
  registry-mirror:
  registry-cache:
```

### Multi-Region Distribution

```python
#!/usr/bin/env python3
# multi-region-sync.py

import docker
import time
import logging
from concurrent.futures import ThreadPoolExecutor
import requests

class RegistrySync:
    def __init__(self, source_registry, target_registries):
        self.source_registry = source_registry
        self.target_registries = target_registries
        self.docker_client = docker.from_env()
        
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(__name__)
    
    def get_repositories(self, registry_url):
        """Get list of repositories from registry"""
        try:
            response = requests.get(f"{registry_url}/v2/_catalog")
            response.raise_for_status()
            return response.json().get('repositories', [])
        except Exception as e:
            self.logger.error(f"Failed to get repositories from {registry_url}: {e}")
            return []
    
    def get_tags(self, registry_url, repository):
        """Get list of tags for a repository"""
        try:
            response = requests.get(f"{registry_url}/v2/{repository}/tags/list")
            response.raise_for_status()
            return response.json().get('tags', [])
        except Exception as e:
            self.logger.error(f"Failed to get tags for {repository}: {e}")
            return []
    
    def sync_image(self, source_image, target_registry):
        """Sync single image to target registry"""
        try:
            # Pull from source
            self.logger.info(f"Pulling {source_image}")
            image = self.docker_client.images.pull(source_image)
            
            # Tag for target registry
            target_image = source_image.replace(self.source_registry, target_registry)
            image.tag(target_image)
            
            # Push to target
            self.logger.info(f"Pushing {target_image}")
            self.docker_client.images.push(target_image)
            
            # Cleanup local images
            self.docker_client.images.remove(source_image, force=True)
            self.docker_client.images.remove(target_image, force=True)
            
            self.logger.info(f"Successfully synced {source_image} to {target_registry}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to sync {source_image} to {target_registry}: {e}")
            return False
    
    def sync_repository(self, repository, target_registry):
        """Sync all tags of a repository to target registry"""
        tags = self.get_tags(self.source_registry, repository)
        
        success_count = 0
        for tag in tags:
            source_image = f"{self.source_registry}/{repository}:{tag}"
            if self.sync_image(source_image, target_registry):
                success_count += 1
        
        self.logger.info(f"Synced {success_count}/{len(tags)} tags for {repository} to {target_registry}")
        return success_count
    
    def sync_all_repositories(self):
        """Sync all repositories to all target registries"""
        repositories = self.get_repositories(self.source_registry)
        self.logger.info(f"Found {len(repositories)} repositories to sync")
        
        with ThreadPoolExecutor(max_workers=4) as executor:
            for target_registry in self.target_registries:
                self.logger.info(f"Starting sync to {target_registry}")
                
                futures = []
                for repository in repositories:
                    future = executor.submit(self.sync_repository, repository, target_registry)
                    futures.append(future)
                
                # Wait for all syncs to complete
                for future in futures:
                    future.result()
                
                self.logger.info(f"Completed sync to {target_registry}")
    
    def monitor_and_sync(self, interval=3600):
        """Continuously monitor and sync registries"""
        self.logger.info(f"Starting continuous sync with {interval}s interval")
        
        while True:
            try:
                self.sync_all_repositories()
                self.logger.info(f"Sync completed. Sleeping for {interval} seconds...")
                time.sleep(interval)
            except KeyboardInterrupt:
                self.logger.info("Sync stopped by user")
                break
            except Exception as e:
                self.logger.error(f"Sync failed: {e}")
                time.sleep(60)  # Wait before retrying

if __name__ == "__main__":
    # Configuration
    SOURCE_REGISTRY = "registry.us-east-1.example.com"
    TARGET_REGISTRIES = [
        "registry.us-west-2.example.com",
        "registry.eu-west-1.example.com",
        "registry.ap-southeast-1.example.com"
    ]
    
    # Create syncer
    syncer = RegistrySync(SOURCE_REGISTRY, TARGET_REGISTRIES)
    
    # Start monitoring and syncing
    syncer.monitor_and_sync()
```

### Content Delivery Network (CDN) Integration

```nginx
# nginx-registry-cdn.conf
upstream registry_backend {
    server registry:5000;
    keepalive 32;
}

proxy_cache_path /var/cache/nginx/registry 
                 levels=1:2 
                 keys_zone=registry_cache:10m 
                 max_size=10g 
                 inactive=60m 
                 use_temp_path=off;

server {
    listen 80;
    server_name registry.example.com;
    
    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name registry.example.com;
    
    ssl_certificate /etc/nginx/certs/domain.crt;
    ssl_certificate_key /etc/nginx/certs/domain.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
    
    client_max_body_size 0;
    chunked_transfer_encoding on;
    
    # Docker registry API
    location /v2/ {
        # Don't cache API calls
        add_header 'Docker-Distribution-Api-Version' 'registry/2.0' always;
        
        proxy_pass http://registry_backend;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 900;
        
        # Cache blob downloads
        location ~ ^/v2/.*/blobs/sha256:.*$ {
            proxy_cache registry_cache;
            proxy_cache_valid 200 301 302 1y;
            proxy_cache_use_stale error timeout invalid_header updating;
            proxy_cache_lock on;
            
            proxy_pass http://registry_backend;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            add_header X-Cache-Status $upstream_cache_status;
        }
    }
    
    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

## 🔒 Content Trust & Image Signing

### Docker Content Trust Setup

```bash
# Enable Content Trust
export DOCKER_CONTENT_TRUST=1

# Initialize repository
docker trust key generate alice
docker trust signer add --key alice.pub alice myregistry.com/myapp

# Sign and push image
docker trust sign myregistry.com/myapp:v1.0

# Verify signature
docker trust inspect --pretty myregistry.com/myapp:v1.0
```

### Notary Server Configuration

```yaml
# notary-server.yml
version: '3.8'

services:
  notary-server:
    image: notary:server-0.6.1
    ports:
      - "4443:4443"
    environment:
      - NOTARY_SERVER_STORAGE_TYPE=mysql
      - NOTARY_SERVER_STORAGE_OPTIONS={"host":"mysql:3306","username":"notary","password":"notarypass","database":"notary_server"}
      - NOTARY_SERVER_TRUST_SERVICE_TYPE=remote
      - NOTARY_SERVER_TRUST_SERVICE_HOSTNAME=notary-signer
      - NOTARY_SERVER_TRUST_SERVICE_PORT=7899
      - NOTARY_SERVER_TRUST_SERVICE_KEY_ALGORITHM=ecdsa
    volumes:
      - ./fixtures:/go/src/github.com/theupdateframework/notary/fixtures
      - notary-server-data:/var/lib/notary
    depends_on:
      - mysql
      - notary-signer
    networks:
      - notary

  notary-signer:
    image: notary:signer-0.6.1
    environment:
      - NOTARY_SIGNER_STORAGE_TYPE=mysql
      - NOTARY_SIGNER_STORAGE_OPTIONS={"host":"mysql:3306","username":"notary","password":"notarypass","database":"notary_signer"}
    volumes:
      - ./fixtures:/go/src/github.com/theupdateframework/notary/fixtures
      - notary-signer-data:/var/lib/notary
    depends_on:
      - mysql
    networks:
      - notary
    expose:
      - "7899"

  mysql:
    image: mysql:5.7
    environment:
      - MYSQL_ROOT_PASSWORD=rootpass
      - MYSQL_DATABASE=notary_server
      - MYSQL_USER=notary
      - MYSQL_PASSWORD=notarypass
    volumes:
      - mysql-data:/var/lib/mysql
      - ./mysql-initdb.d:/docker-entrypoint-initdb.d
    networks:
      - notary

networks:
  notary:
    driver: bridge

volumes:
  notary-server-data:
  notary-signer-data:
  mysql-data:
```

### Cosign Integration (CNCF)

```bash
# Install Cosign
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign

# Generate key pair
cosign generate-key-pair

# Sign image
cosign sign --key cosign.key myregistry.com/myapp:v1.0

# Verify signature
cosign verify --key cosign.pub myregistry.com/myapp:v1.0

# Sign with keyless (experimental)
cosign sign myregistry.com/myapp:v1.0

# Attach SBOM (Software Bill of Materials)
cosign attach sbom --sbom sbom.json myregistry.com/myapp:v1.0
```

## 📊 Registry Monitoring & Maintenance

### Prometheus Monitoring

```yaml
# registry-monitoring.yml
version: '3.8'

services:
  registry:
    image: registry:2
    ports:
      - "5000:5000"
    environment:
      REGISTRY_HTTP_DEBUG_ADDR: :5001
      REGISTRY_HTTP_DEBUG_PROMETHEUS_ENABLED: "true"
    volumes:
      - registry-data:/var/lib/registry
    networks:
      - registry
      - monitoring

  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
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

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
      - ./monitoring/grafana:/etc/grafana/provisioning
    networks:
      - monitoring

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

networks:
  registry:
  monitoring:

volumes:
  registry-data:
  prometheus-data:
  grafana-data:
```

### Monitoring Configuration

```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "registry-rules.yml"

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
```

### Registry Health Monitor

```python
#!/usr/bin/env python3
# registry-monitor.py

import requests
import time
import logging
from dataclasses import dataclass
from typing import List, Dict
import json
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

@dataclass
class RegistryEndpoint:
    name: str
    url: str
    auth: tuple = None
    expected_repos: List[str] = None

class RegistryMonitor:
    def __init__(self, endpoints: List[RegistryEndpoint], config: Dict):
        self.endpoints = endpoints
        self.config = config
        self.logger = self._setup_logging()
        
    def _setup_logging(self):
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        return logging.getLogger(__name__)
    
    def check_registry_health(self, endpoint: RegistryEndpoint):
        """Check if registry is healthy"""
        try:
            # Check basic connectivity
            health_url = f"{endpoint.url}/v2/"
            response = requests.get(health_url, auth=endpoint.auth, timeout=10)
            
            if response.status_code == 200:
                self.logger.info(f"✅ {endpoint.name} is healthy")
                return True
            else:
                self.logger.error(f"❌ {endpoint.name} returned {response.status_code}")
                return False
                
        except Exception as e:
            self.logger.error(f"❌ {endpoint.name} connection failed: {e}")
            return False
    
    def check_repository_availability(self, endpoint: RegistryEndpoint):
        """Check if expected repositories are available"""
        if not endpoint.expected_repos:
            return True
            
        try:
            catalog_url = f"{endpoint.url}/v2/_catalog"
            response = requests.get(catalog_url, auth=endpoint.auth, timeout=10)
            
            if response.status_code != 200:
                self.logger.error(f"❌ {endpoint.name} catalog unavailable")
                return False
            
            available_repos = response.json().get('repositories', [])
            missing_repos = []
            
            for expected_repo in endpoint.expected_repos:
                if expected_repo not in available_repos:
                    missing_repos.append(expected_repo)
            
            if missing_repos:
                self.logger.warning(f"⚠️ {endpoint.name} missing repos: {missing_repos}")
                return False
            else:
                self.logger.info(f"✅ {endpoint.name} all expected repos available")
                return True
                
        except Exception as e:
            self.logger.error(f"❌ {endpoint.name} repo check failed: {e}")
            return False
    
    def check_disk_usage(self, endpoint: RegistryEndpoint):
        """Check registry disk usage (if metrics available)"""
        try:
            # Try to get metrics from registry debug endpoint
            metrics_url = f"{endpoint.url.replace(':5000', ':5001')}/metrics"
            response = requests.get(metrics_url, timeout=5)
            
            if response.status_code == 200:
                # Parse Prometheus metrics for disk usage
                metrics = response.text
                for line in metrics.split('\n'):
                    if 'registry_storage_' in line and 'bytes' in line:
                        self.logger.info(f"📊 {endpoint.name} storage: {line}")
                        
        except Exception as e:
            self.logger.debug(f"Metrics not available for {endpoint.name}: {e}")
    
    def send_alert(self, subject: str, message: str):
        """Send email alert"""
        if not self.config.get('smtp'):
            return
            
        try:
            smtp_config = self.config['smtp']
            
            msg = MIMEMultipart()
            msg['From'] = smtp_config['from']
            msg['To'] = smtp_config['to']
            msg['Subject'] = subject
            
            msg.attach(MIMEText(message, 'plain'))
            
            server = smtplib.SMTP(smtp_config['host'], smtp_config['port'])
            if smtp_config.get('tls'):
                server.starttls()
            if smtp_config.get('user'):
                server.login(smtp_config['user'], smtp_config['password'])
            
            server.send_message(msg)
            server.quit()
            
            self.logger.info(f"📧 Alert sent: {subject}")
            
        except Exception as e:
            self.logger.error(f"Failed to send alert: {e}")
    
    def run_health_checks(self):
        """Run all health checks for all endpoints"""
        results = {}
        
        for endpoint in self.endpoints:
            self.logger.info(f"🔍 Checking {endpoint.name}")
            
            health_ok = self.check_registry_health(endpoint)
            repos_ok = self.check_repository_availability(endpoint)
            
            results[endpoint.name] = {
                'health': health_ok,
                'repositories': repos_ok,
                'overall': health_ok and repos_ok
            }
            
            # Check disk usage
            self.check_disk_usage(endpoint)
            
            # Send alert if registry is down
            if not health_ok:
                self.send_alert(
                    f"🚨 Registry Alert: {endpoint.name} Down",
                    f"Registry {endpoint.name} at {endpoint.url} is not responding to health checks."
                )
        
        return results
    
    def monitor_continuously(self, interval: int = 300):
        """Monitor registries continuously"""
        self.logger.info(f"🔄 Starting continuous monitoring (interval: {interval}s)")
        
        while True:
            try:
                results = self.run_health_checks()
                
                # Log summary
                healthy_count = sum(1 for r in results.values() if r['overall'])
                total_count = len(results)
                
                self.logger.info(f"📈 Health Summary: {healthy_count}/{total_count} registries healthy")
                
                time.sleep(interval)
                
            except KeyboardInterrupt:
                self.logger.info("👋 Monitoring stopped by user")
                break
            except Exception as e:
                self.logger.error(f"Monitoring error: {e}")
                time.sleep(60)

if __name__ == "__main__":
    # Configuration
    endpoints = [
        RegistryEndpoint(
            name="Production Registry",
            url="https://registry.example.com",
            auth=("username", "password"),
            expected_repos=["app/frontend", "app/backend", "app/worker"]
        ),
        RegistryEndpoint(
            name="Staging Registry", 
            url="https://staging-registry.example.com",
            expected_repos=["app/frontend", "app/backend"]
        ),
        RegistryEndpoint(
            name="Local Registry",
            url="http://localhost:5000"
        )
    ]
    
    config = {
        'smtp': {
            'host': 'smtp.example.com',
            'port': 587,
            'tls': True,
            'user': 'alerts@example.com',
            'password': 'password',
            'from': 'alerts@example.com',
            'to': 'admin@example.com'
        }
    }
    
    # Start monitoring
    monitor = RegistryMonitor(endpoints, config)
    monitor.monitor_continuously()
```

## 🔧 Registry Maintenance & Operations

### Automated Cleanup

```python
#!/usr/bin/env python3
# registry-cleanup.py

import requests
import json
import os
import subprocess
from datetime import datetime, timedelta
from typing import List, Dict

class RegistryCleanup:
    def __init__(self, registry_url: str, auth: tuple = None):
        self.registry_url = registry_url.rstrip('/')
        self.auth = auth
        
    def get_repositories(self) -> List[str]:
        """Get list of all repositories"""
        response = requests.get(f"{self.registry_url}/v2/_catalog", auth=self.auth)
        response.raise_for_status()
        return response.json().get('repositories', [])
    
    def get_tags(self, repository: str) -> List[str]:
        """Get list of tags for repository"""
        response = requests.get(f"{self.registry_url}/v2/{repository}/tags/list", auth=self.auth)
        response.raise_for_status()
        return response.json().get('tags', [])
    
    def get_manifest(self, repository: str, tag: str) -> Dict:
        """Get manifest for specific tag"""
        headers = {'Accept': 'application/vnd.docker.distribution.manifest.v2+json'}
        response = requests.get(
            f"{self.registry_url}/v2/{repository}/manifests/{tag}",
            headers=headers,
            auth=self.auth
        )
        response.raise_for_status()
        return {
            'manifest': response.json(),
            'digest': response.headers.get('Docker-Content-Digest')
        }
    
    def delete_manifest(self, repository: str, digest: str) -> bool:
        """Delete manifest by digest"""
        try:
            response = requests.delete(
                f"{self.registry_url}/v2/{repository}/manifests/{digest}",
                auth=self.auth
            )
            return response.status_code == 202
        except Exception as e:
            print(f"Failed to delete {repository}@{digest}: {e}")
            return False
    
    def cleanup_old_tags(self, repository: str, keep_count: int = 5, 
                        keep_days: int = 30, dry_run: bool = True) -> List[str]:
        """Clean up old tags based on count and age"""
        tags = self.get_tags(repository)
        if len(tags) <= keep_count:
            return []
        
        # Get tag information with timestamps
        tag_info = []
        cutoff_date = datetime.now() - timedelta(days=keep_days)
        
        for tag in tags:
            try:
                manifest_data = self.get_manifest(repository, tag)
                manifest = manifest_data['manifest']
                digest = manifest_data['digest']
                
                # Extract creation date from config
                config_digest = manifest['config']['digest']
                config_response = requests.get(
                    f"{self.registry_url}/v2/{repository}/blobs/{config_digest}",
                    auth=self.auth
                )
                
                if config_response.status_code == 200:
                    config = config_response.json()
                    created_str = config.get('created', '')
                    if created_str:
                        created = datetime.fromisoformat(created_str.replace('Z', '+00:00'))
                        tag_info.append({
                            'tag': tag,
                            'digest': digest,
                            'created': created
                        })
                
            except Exception as e:
                print(f"Error processing tag {tag}: {e}")
                continue
        
        # Sort by creation date (newest first)
        tag_info.sort(key=lambda x: x['created'], reverse=True)
        
        # Determine tags to delete
        to_delete = []
        
        # Keep newest N tags
        keep_newest = tag_info[:keep_count]
        candidates = tag_info[keep_count:]
        
        # Delete old candidates
        for tag_data in candidates:
            if tag_data['created'] < cutoff_date:
                to_delete.append(tag_data)
        
        # Perform deletion
        deleted = []
        for tag_data in to_delete:
            print(f"{'[DRY RUN] ' if dry_run else ''}Deleting {repository}:{tag_data['tag']} (created: {tag_data['created']})")
            
            if not dry_run:
                if self.delete_manifest(repository, tag_data['digest']):
                    deleted.append(tag_data['tag'])
                    print(f"✅ Deleted {repository}:{tag_data['tag']}")
                else:
                    print(f"❌ Failed to delete {repository}:{tag_data['tag']}")
            else:
                deleted.append(tag_data['tag'])
        
        return deleted
    
    def run_garbage_collection(self, registry_path: str = "/var/lib/registry"):
        """Run registry garbage collection"""
        try:
            print("🗑️ Running garbage collection...")
            
            # Stop registry temporarily for GC
            subprocess.run(["docker-compose", "stop", "registry"], check=True)
            
            # Run garbage collection
            gc_command = [
                "docker", "run", "--rm",
                "-v", f"{registry_path}:/var/lib/registry",
                "registry:2", "garbage-collect",
                "/etc/registry/config.yml"
            ]
            
            result = subprocess.run(gc_command, capture_output=True, text=True)
            print(result.stdout)
            
            if result.stderr:
                print(f"GC stderr: {result.stderr}")
            
            # Restart registry
            subprocess.run(["docker-compose", "start", "registry"], check=True)
            
            print("✅ Garbage collection completed")
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Garbage collection failed: {e}")
    
    def cleanup_all_repositories(self, keep_count: int = 5, 
                                keep_days: int = 30, dry_run: bool = True):
        """Clean up all repositories"""
        repositories = self.get_repositories()
        
        print(f"🧹 Starting cleanup for {len(repositories)} repositories")
        print(f"Keep {keep_count} newest tags, delete tags older than {keep_days} days")
        print(f"Mode: {'DRY RUN' if dry_run else 'LIVE'}")
        
        total_deleted = 0
        
        for repo in repositories:
            print(f"\n📦 Processing repository: {repo}")
            deleted_tags = self.cleanup_old_tags(repo, keep_count, keep_days, dry_run)
            total_deleted += len(deleted_tags)
            
            if deleted_tags:
                print(f"  Deleted {len(deleted_tags)} tags: {', '.join(deleted_tags)}")
            else:
                print(f"  No tags to delete")
        
        print(f"\n📊 Cleanup Summary:")
        print(f"  Repositories processed: {len(repositories)}")
        print(f"  Total tags deleted: {total_deleted}")
        
        if not dry_run and total_deleted > 0:
            print("\n🗑️ Running garbage collection to free disk space...")
            self.run_garbage_collection()

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Registry cleanup tool')
    parser.add_argument('--registry-url', required=True, help='Registry URL')
    parser.add_argument('--username', help='Registry username')
    parser.add_argument('--password', help='Registry password')
    parser.add_argument('--keep-count', type=int, default=5, help='Number of tags to keep')
    parser.add_argument('--keep-days', type=int, default=30, help='Keep tags newer than N days')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be deleted')
    
    args = parser.parse_args()
    
    auth = None
    if args.username and args.password:
        auth = (args.username, args.password)
    
    cleanup = RegistryCleanup(args.registry_url, auth)
    cleanup.cleanup_all_repositories(args.keep_count, args.keep_days, args.dry_run)
```

## 🎯 Chapter Checkpoint

### Questions

1. **What are the main components of a Docker Registry?**
   - Registry server, storage backend, authentication service, content trust

2. **How do you implement secure registry authentication?**
   - TLS/SSL, htpasswd, token-based auth, OAuth2/OIDC integration

3. **What's the purpose of registry mirroring?**
   - Improve performance, reduce bandwidth, provide redundancy

4. **How does content trust work with registries?**
   - Digital signatures verify image integrity and authenticity

### Tasks

- [ ] Deploy private registry with TLS and authentication
- [ ] Implement registry monitoring and alerting
- [ ] Set up automated cleanup procedures
- [ ] Configure content trust and signing

---

## 🚀 What's Next?

In [Chapter 08: Docker Security](../08-docker-security/README.md), you'll learn:
- Container security best practices
- Runtime security and scanning
- Secrets management
- Network security
- Compliance and auditing

## 📚 Key Takeaways

✅ **Private registries** provide secure, controlled image distribution
✅ **Registry security** protects against unauthorized access and tampering
✅ **Content trust** ensures image integrity and authenticity
✅ **Monitoring** provides visibility into registry health and usage
✅ **Automation** reduces operational overhead and ensures consistency
✅ **Distribution strategies** optimize performance and reliability

## 📝 Practice Checklist

Before moving on, ensure you can:
- [ ] Deploy and configure private Docker registries
- [ ] Implement authentication and authorization
- [ ] Set up registry monitoring and maintenance
- [ ] Configure content trust and image signing
- [ ] Optimize registry performance and distribution
- [ ] Automate registry operations and cleanup

---

**🎉 Congratulations!** You now have comprehensive Docker Registry management skills. Complete the [lab exercise](lab/README.md) to practice these concepts, then validate your knowledge with the [checkpoint](checkpoint.md)!

---

<div align="center">

**[⬅️ Previous: Docker Compose](../06-docker-compose/README.md)** | **[Next: Docker Security ➡️](../08-docker-security/README.md)**

</div>
``` 