# 🎯 Chapter 07 Checkpoint: Docker Registry Mastery

## 📝 Knowledge Assessment

**Total Points: 100**  
**Passing Score: 75**  
**Time Limit: 45 minutes**

---

### Section A: Registry Architecture & Deployment (25 points)

#### Question 1 (5 points)
**What are the main components of a production Docker Registry?**

a) Registry server, storage backend, authentication service  
b) Docker daemon, image cache, network proxy  
c) Container runtime, image builder, volume manager  
d) Registry server, storage backend, authentication service, content trust, monitoring  

<details>
<summary>💡 Click to reveal answer</summary>

**Answer: d) Registry server, storage backend, authentication service, content trust, monitoring**

**Explanation:** A production Docker Registry consists of:
- **Registry server**: Core registry service handling API requests
- **Storage backend**: File system, S3, GCS, or other storage for image layers
- **Authentication service**: htpasswd, token auth, or OAuth integration
- **Content trust**: Notary or Cosign for image signing/verification
- **Monitoring**: Prometheus metrics, health checks, alerting
</details>

#### Question 2 (10 points)
**Configure a secure Docker Registry with TLS and authentication:**

Write the essential configuration sections for:
- Registry config with TLS enabled
- Basic authentication setup
- Storage configuration with deletion enabled

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

```yaml
# Registry configuration (config.yml)
version: 0.1
log:
  level: info

storage:
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true

http:
  addr: :5000
  tls:
    certificate: /certs/domain.crt
    key: /certs/domain.key
    minimumtls: tls1.2
  headers:
    X-Content-Type-Options: [nosniff]

auth:
  htpasswd:
    realm: "Registry Realm"
    path: /auth/htpasswd

health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
```

**htpasswd setup:**
```bash
# Create authentication file
docker run --rm --entrypoint htpasswd \
  httpd:2 -Bbn username password > auth/htpasswd
```

**TLS certificates:**
```bash
# Generate self-signed certificate
openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout certs/domain.key \
  -x509 -days 365 \
  -out certs/domain.crt
```
</details>

#### Question 3 (10 points)
**Explain the difference between these registry deployment patterns:**

```yaml
# Pattern A: Basic Registry
services:
  registry:
    image: registry:2
    ports:
      - "5000:5000"
    volumes:
      - registry-data:/var/lib/registry

# Pattern B: Production Registry
services:
  registry:
    image: registry:2
    environment:
      REGISTRY_AUTH: token
      REGISTRY_AUTH_TOKEN_REALM: https://auth.example.com/auth
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/domain.crt
    volumes:
      - ./config.yml:/etc/registry/config.yml
      - registry-data:/var/lib/registry
```

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**Pattern A (Basic Registry):**
- No authentication or encryption
- Default configuration
- Suitable only for development/testing
- No security controls
- Basic storage configuration

**Pattern B (Production Registry):**
- Token-based authentication with external auth service
- TLS encryption enabled
- Custom configuration file
- Production-ready security
- Proper certificate management

**Key Differences:**
1. **Security**: Pattern B has authentication and TLS
2. **Configuration**: Pattern B uses custom config file
3. **Authentication**: Pattern B uses token auth vs no auth
4. **Use case**: Pattern A for dev, Pattern B for production
5. **Scalability**: Pattern B supports external auth services

**Production Requirements:**
- Always use TLS in production
- Implement proper authentication
- Use external storage backends for HA
- Configure monitoring and alerting
- Implement backup and disaster recovery
</details>

---

### Section B: Authentication & Authorization (25 points)

#### Question 4 (15 points)
**Design a token-based authentication system for Docker Registry with RBAC:**

Create a system that supports:
- Role-based access control
- Repository-level permissions
- JWT token generation
- Different user roles (admin, developer, readonly)

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

```python
# JWT Token Authentication Server
from flask import Flask, request, jsonify
import jwt
import datetime

app = Flask(__name__)
SECRET_KEY = 'your-secret-key'

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
    }
}

USERS = {
    'admin': {'password': 'admin123', 'roles': ['admin']},
    'dev': {'password': 'dev123', 'roles': ['developer']},
    'user': {'password': 'user123', 'roles': ['readonly']}
}

def check_permission(user_roles, repository, action):
    for role_name in user_roles:
        role = ROLES.get(role_name, {})
        if action in role.get('actions', []):
            for repo_pattern in role.get('repositories', []):
                if match_repository(repository, repo_pattern):
                    return True
    return False

def match_repository(repository, pattern):
    if pattern == '*':
        return True
    if pattern.endswith('/*'):
        return repository.startswith(pattern[:-2] + '/')
    return repository == pattern

@app.route('/auth')
def auth():
    # Get credentials from Basic Auth
    auth_header = request.headers.get('Authorization', '')
    if not auth_header.startswith('Basic '):
        return jsonify({'error': 'Basic auth required'}), 401
    
    import base64
    encoded = auth_header[6:]
    username, password = base64.b64decode(encoded).decode().split(':', 1)
    
    # Verify user
    user = USERS.get(username)
    if not user or user['password'] != password:
        return jsonify({'error': 'Invalid credentials'}), 401
    
    # Parse scope
    scope = request.args.get('scope', '')
    if scope:
        scope_parts = scope.split(':')
        repo_name = scope_parts[1]
        actions = scope_parts[2].split(',')
    else:
        repo_name = ''
        actions = []
    
    # Check permissions
    allowed_actions = [a for a in actions 
                      if check_permission(user['roles'], repo_name, a)]
    
    # Generate JWT token
    payload = {
        'iss': 'registry-auth',
        'aud': 'registry',
        'sub': username,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=1),
        'access': [{
            'type': 'repository',
            'name': repo_name,
            'actions': allowed_actions
        }]
    }
    
    token = jwt.encode(payload, SECRET_KEY, algorithm='HS256')
    
    return jsonify({
        'token': token,
        'expires_in': 3600
    })
```

**Registry Configuration:**
```yaml
auth:
  token:
    realm: https://auth.example.com/auth
    service: registry
    issuer: registry-auth
    rootcertbundle: /certs/auth.crt
```
</details>

#### Question 5 (10 points)
**What are the key differences between these authentication methods?**

1. **htpasswd authentication**
2. **Token-based authentication**
3. **OAuth2/OIDC integration**

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**1. htpasswd Authentication:**
- **Method**: Basic HTTP authentication with username/password
- **Storage**: Local file with hashed passwords
- **Pros**: Simple setup, no external dependencies
- **Cons**: Limited scalability, no fine-grained permissions
- **Use case**: Small teams, development environments

**2. Token-based Authentication:**
- **Method**: JWT tokens issued by authentication service
- **Storage**: External auth service with user database
- **Pros**: Scalable, fine-grained permissions, stateless
- **Cons**: More complex setup, requires auth service
- **Use case**: Production environments, large teams

**3. OAuth2/OIDC Integration:**
- **Method**: Industry-standard OAuth2 with OpenID Connect
- **Storage**: External identity provider (Google, Azure AD, etc.)
- **Pros**: Enterprise integration, SSO, standardized
- **Cons**: Most complex, dependency on external provider
- **Use case**: Enterprise environments, SSO requirements

**Comparison Matrix:**
| Feature | htpasswd | Token | OAuth2/OIDC |
|---------|----------|-------|-------------|
| Complexity | Low | Medium | High |
| Scalability | Poor | Good | Excellent |
| Permissions | Basic | Fine-grained | Fine-grained |
| SSO Support | No | Limited | Yes |
| Enterprise | No | Yes | Yes |
</details>

---

### Section C: Content Trust & Security (25 points)

#### Question 6 (10 points)
**Explain Docker Content Trust and how it protects against image tampering:**

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**Docker Content Trust (DCT)** is a security feature that provides cryptographic verification of image integrity and publisher identity.

**How it works:**
1. **Image Signing**: When DCT is enabled, images are cryptographically signed before push
2. **Key Management**: Uses root keys and repository keys for signing hierarchy
3. **Notary Service**: Stores signatures and metadata separately from images
4. **Verification**: Client verifies signatures before pulling/running images

**Protection Against Tampering:**
- **Image Integrity**: Ensures image hasn't been modified after signing
- **Publisher Authentication**: Verifies who signed the image
- **Replay Attacks**: Timestamps prevent use of old signatures
- **Supply Chain Security**: End-to-end verification from build to deployment

**Key Components:**
```bash
# Enable Content Trust
export DOCKER_CONTENT_TRUST=1

# Generate keys
docker trust key generate alice

# Add signer
docker trust signer add --key alice.pub alice myregistry.com/myapp

# Sign and push
docker trust sign myregistry.com/myapp:v1.0

# Verify
docker trust inspect --pretty myregistry.com/myapp:v1.0
```

**Modern Alternative - Cosign:**
```bash
# Generate keypair
cosign generate-key-pair

# Sign image
cosign sign --key cosign.key myregistry.com/myapp:v1.0

# Verify signature
cosign verify --key cosign.pub myregistry.com/myapp:v1.0
```

**Benefits:**
- Prevents malicious image injection
- Ensures image authenticity
- Supports compliance requirements
- Integrates with CI/CD pipelines
</details>

#### Question 7 (15 points)
**Design a secure registry deployment with content trust:**

Create a complete setup including:
- Registry with content trust enabled
- Notary server configuration
- Client-side verification process
- Key management strategy

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**1. Registry with Content Trust:**
```yaml
# docker-compose.yml
version: '3.8'
services:
  registry:
    image: registry:2
    environment:
      REGISTRY_AUTH: token
      REGISTRY_AUTH_TOKEN_REALM: https://notary:4443/auth
      REGISTRY_AUTH_TOKEN_SERVICE: registry
      REGISTRY_AUTH_TOKEN_ISSUER: notary
    volumes:
      - ./certs:/certs
      - registry-data:/var/lib/registry
    depends_on:
      - notary-server
```

**2. Notary Server Configuration:**
```yaml
  notary-server:
    image: notary:server
    ports:
      - "4443:4443"
    environment:
      NOTARY_SERVER_STORAGE_TYPE: mysql
      NOTARY_SERVER_TRUST_SERVICE_TYPE: remote
      NOTARY_SERVER_TRUST_SERVICE_HOSTNAME: notary-signer
    volumes:
      - ./notary-config:/etc/notary
    depends_on:
      - mysql
      - notary-signer

  notary-signer:
    image: notary:signer
    environment:
      NOTARY_SIGNER_STORAGE_TYPE: mysql
    depends_on:
      - mysql

  mysql:
    image: mysql:5.7
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_DATABASE: notary_server
```

**3. Client-side Verification:**
```bash
# Enable content trust
export DOCKER_CONTENT_TRUST=1
export DOCKER_CONTENT_TRUST_SERVER=https://notary.example.com:4443

# Initialize repository
docker trust key generate alice
docker trust signer add --key alice.pub alice registry.example.com/myapp

# Sign and push image
docker tag myapp:latest registry.example.com/myapp:v1.0
docker trust sign registry.example.com/myapp:v1.0

# Verify image
docker trust inspect --pretty registry.example.com/myapp:v1.0

# Pull with verification (automatic with DCT enabled)
docker pull registry.example.com/myapp:v1.0
```

**4. Key Management Strategy:**
```bash
# Key hierarchy
ROOT_KEY="Root signing key (offline, secure storage)"
TARGETS_KEY="Repository signing key (online, secure server)"
SNAPSHOT_KEY="Metadata signing key (automated)"
TIMESTAMP_KEY="Freshness key (automated)"

# Key storage locations
~/.docker/trust/private/  # Local key storage
/secure-storage/keys/     # Offline root key storage
/etc/notary/keys/         # Server key storage

# Key rotation procedure
docker trust key rotate registry.example.com/myapp snapshot
docker trust key rotate registry.example.com/myapp targets --server-managed

# Backup strategy
tar -czf keys-backup-$(date +%Y%m%d).tar.gz ~/.docker/trust/
gpg --encrypt --recipient admin@example.com keys-backup-*.tar.gz
```

**5. CI/CD Integration:**
```yaml
# .github/workflows/build-and-sign.yml
- name: Sign and push image
  env:
    DOCKER_CONTENT_TRUST: 1
    DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE: ${{ secrets.SIGNING_KEY_PASSPHRASE }}
  run: |
    docker trust sign registry.example.com/myapp:${{ github.sha }}
```

**Security Best Practices:**
- Store root keys offline in secure hardware
- Use separate keys for different environments
- Implement key rotation policies
- Monitor signing events and verify in CI/CD
- Regular backup and recovery testing
</details>

---

### Section D: Monitoring & Maintenance (25 points)

#### Question 8 (10 points)
**What registry metrics should be monitored in production?**

List the key metrics and explain their importance.

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**Core Registry Metrics:**

**1. Availability Metrics:**
- `up{job="registry"}` - Registry service availability
- `registry_http_requests_total` - Total HTTP requests
- `registry_http_request_duration_seconds` - Request latency

**2. Storage Metrics:**
- `registry_storage_filesystem_free_bytes` - Available disk space
- `registry_storage_filesystem_size_bytes` - Total disk space
- `registry_storage_blob_size_bytes` - Individual blob sizes

**3. Performance Metrics:**
- `registry_http_requests_total{code="200"}` - Successful requests
- `registry_http_requests_total{code=~"5.."}` - Server errors
- `registry_notifications_events_total` - Webhook events

**4. Security Metrics:**
- `registry_http_requests_total{code="401"}` - Authentication failures
- `registry_http_requests_total{code="403"}` - Authorization failures
- Authentication attempts per user/IP

**5. Business Metrics:**
- Number of repositories
- Number of tags per repository
- Image pull/push rates
- Storage growth rate

**Monitoring Configuration:**
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'registry'
    static_configs:
      - targets: ['registry:5001']
    metrics_path: /metrics

# Alert rules
groups:
  - name: registry
    rules:
      - alert: RegistryDown
        expr: up{job="registry"} == 0
        for: 1m
        
      - alert: RegistryHighErrorRate
        expr: rate(registry_http_requests_total{code=~"5.."}[5m]) > 0.1
        
      - alert: RegistryStorageSpace
        expr: (registry_storage_filesystem_free_bytes / registry_storage_filesystem_size_bytes) * 100 < 10
```

**Importance:**
- **Availability**: Ensure registry is accessible for deployments
- **Performance**: Identify bottlenecks and optimize
- **Storage**: Prevent disk space issues
- **Security**: Detect potential attacks or misconfigurations
- **Capacity**: Plan for scaling and growth
</details>

#### Question 9 (15 points)
**Create a registry maintenance automation script:**

Write a Python script that:
- Monitors registry health
- Cleans up old tags based on retention policy
- Runs garbage collection
- Sends alerts on issues

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

```python
#!/usr/bin/env python3
import requests
import subprocess
import logging
import smtplib
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from typing import List, Dict

class RegistryMaintenance:
    def __init__(self, registry_url: str, auth: tuple, config: Dict):
        self.registry_url = registry_url.rstrip('/')
        self.auth = auth
        self.config = config
        self.logger = self._setup_logging()
    
    def _setup_logging(self):
        logging.basicConfig(level=logging.INFO)
        return logging.getLogger(__name__)
    
    def check_health(self) -> bool:
        """Check registry health"""
        try:
            response = requests.get(f"{self.registry_url}/v2/", 
                                  auth=self.auth, timeout=10)
            healthy = response.status_code == 200
            
            if not healthy:
                self.send_alert("Registry Health Check Failed", 
                              f"Registry returned status {response.status_code}")
            
            return healthy
        except Exception as e:
            self.send_alert("Registry Health Check Error", str(e))
            return False
    
    def get_repositories(self) -> List[str]:
        """Get all repositories"""
        response = requests.get(f"{self.registry_url}/v2/_catalog", 
                              auth=self.auth)
        response.raise_for_status()
        return response.json().get('repositories', [])
    
    def get_tags_with_metadata(self, repository: str) -> List[Dict]:
        """Get tags with creation metadata"""
        tags_response = requests.get(f"{self.registry_url}/v2/{repository}/tags/list",
                                   auth=self.auth)
        tags_response.raise_for_status()
        tags = tags_response.json().get('tags', [])
        
        tag_metadata = []
        for tag in tags:
            try:
                # Get manifest
                manifest_response = requests.get(
                    f"{self.registry_url}/v2/{repository}/manifests/{tag}",
                    headers={'Accept': 'application/vnd.docker.distribution.manifest.v2+json'},
                    auth=self.auth
                )
                
                if manifest_response.status_code == 200:
                    manifest = manifest_response.json()
                    digest = manifest_response.headers.get('Docker-Content-Digest')
                    
                    # Get config blob for creation date
                    config_digest = manifest['config']['digest']
                    config_response = requests.get(
                        f"{self.registry_url}/v2/{repository}/blobs/{config_digest}",
                        auth=self.auth
                    )
                    
                    created = datetime.now()  # Default to now
                    if config_response.status_code == 200:
                        config = config_response.json()
                        created_str = config.get('created', '')
                        if created_str:
                            created = datetime.fromisoformat(created_str.replace('Z', '+00:00'))
                    
                    tag_metadata.append({
                        'tag': tag,
                        'digest': digest,
                        'created': created,
                        'size': sum(layer['size'] for layer in manifest.get('layers', []))
                    })
                    
            except Exception as e:
                self.logger.warning(f"Error getting metadata for {repository}:{tag}: {e}")
        
        return tag_metadata
    
    def cleanup_repository(self, repository: str, retention_days: int = 30, 
                          keep_count: int = 5) -> int:
        """Clean up old tags in repository"""
        tag_metadata = self.get_tags_with_metadata(repository)
        
        if len(tag_metadata) <= keep_count:
            return 0
        
        # Sort by creation date (newest first)
        tag_metadata.sort(key=lambda x: x['created'], reverse=True)
        
        # Keep newest tags
        keep_tags = tag_metadata[:keep_count]
        candidates = tag_metadata[keep_count:]
        
        # Delete old tags
        cutoff_date = datetime.now() - timedelta(days=retention_days)
        deleted_count = 0
        
        for tag_data in candidates:
            if tag_data['created'] < cutoff_date:
                try:
                    response = requests.delete(
                        f"{self.registry_url}/v2/{repository}/manifests/{tag_data['digest']}",
                        auth=self.auth
                    )
                    
                    if response.status_code == 202:
                        deleted_count += 1
                        self.logger.info(f"Deleted {repository}:{tag_data['tag']}")
                    else:
                        self.logger.warning(f"Failed to delete {repository}:{tag_data['tag']}")
                        
                except Exception as e:
                    self.logger.error(f"Error deleting {repository}:{tag_data['tag']}: {e}")
        
        return deleted_count
    
    def run_garbage_collection(self):
        """Run registry garbage collection"""
        try:
            self.logger.info("Running garbage collection...")
            
            # Stop registry
            subprocess.run(["docker-compose", "stop", "registry"], check=True)
            
            # Run GC
            gc_command = [
                "docker", "run", "--rm",
                "-v", "registry-data:/var/lib/registry",
                "registry:2", "garbage-collect", "/etc/registry/config.yml"
            ]
            
            result = subprocess.run(gc_command, capture_output=True, text=True)
            
            if result.returncode == 0:
                self.logger.info("Garbage collection completed successfully")
                self.logger.info(result.stdout)
            else:
                self.logger.error(f"Garbage collection failed: {result.stderr}")
            
            # Restart registry
            subprocess.run(["docker-compose", "start", "registry"], check=True)
            
        except Exception as e:
            self.logger.error(f"Garbage collection error: {e}")
            self.send_alert("Garbage Collection Failed", str(e))
    
    def send_alert(self, subject: str, message: str):
        """Send email alert"""
        if not self.config.get('smtp'):
            return
        
        try:
            smtp_config = self.config['smtp']
            
            msg = MIMEText(message)
            msg['Subject'] = f"[Registry Alert] {subject}"
            msg['From'] = smtp_config['from']
            msg['To'] = smtp_config['to']
            
            server = smtplib.SMTP(smtp_config['host'], smtp_config['port'])
            if smtp_config.get('tls'):
                server.starttls()
            if smtp_config.get('user'):
                server.login(smtp_config['user'], smtp_config['password'])
            
            server.send_message(msg)
            server.quit()
            
            self.logger.info(f"Alert sent: {subject}")
            
        except Exception as e:
            self.logger.error(f"Failed to send alert: {e}")
    
    def run_maintenance(self):
        """Run complete maintenance cycle"""
        self.logger.info("Starting registry maintenance")
        
        # Health check
        if not self.check_health():
            return
        
        # Cleanup repositories
        repositories = self.get_repositories()
        total_deleted = 0
        
        for repo in repositories:
            deleted = self.cleanup_repository(
                repo, 
                self.config.get('retention_days', 30),
                self.config.get('keep_count', 5)
            )
            total_deleted += deleted
        
        if total_deleted > 0:
            self.logger.info(f"Deleted {total_deleted} old tags")
            self.run_garbage_collection()
        
        self.logger.info("Maintenance completed")

# Usage
if __name__ == "__main__":
    config = {
        'retention_days': 30,
        'keep_count': 5,
        'smtp': {
            'host': 'smtp.example.com',
            'port': 587,
            'tls': True,
            'user': 'alerts@example.com',
            'password': 'password',
            'from': 'registry@example.com',
            'to': 'admin@example.com'
        }
    }
    
    maintenance = RegistryMaintenance(
        "https://registry.example.com:5000",
        ("admin", "password"),
        config
    )
    
    maintenance.run_maintenance()
```

**Cron Job Setup:**
```bash
# Add to crontab for daily maintenance
0 2 * * * /usr/bin/python3 /opt/registry/maintenance.py
```
</details>

---

## 🏆 Performance Assessment

### Scoring Rubric

| Score Range | Grade | Performance Level |
|-------------|-------|-------------------|
| 90-100 | A+ | Expert Level - Enterprise Ready |
| 80-89 | A | Advanced - Production Deployments |
| 75-79 | B+ | Proficient - Secure Registries |
| 65-74 | B | Competent - Basic Private Registries |
| 55-64 | C | Developing - Simple Setups |
| Below 55 | F | Needs Review |

### Assessment Breakdown

**Section A: Architecture & Deployment (25 points)**
- Understanding of registry components
- Secure deployment configuration
- Production vs development patterns

**Section B: Authentication & Authorization (25 points)**
- Authentication methods comparison
- RBAC implementation
- Token-based security systems

**Section C: Content Trust & Security (25 points)**
- Content trust mechanisms
- Image signing and verification
- Secure deployment design

**Section D: Monitoring & Maintenance (25 points)**
- Production monitoring strategies
- Automated maintenance scripts
- Health checks and alerting

## 🎯 Remediation Plan

### If you scored below 75:

#### Review These Topics:
1. **Registry architecture and components**
2. **Authentication and authorization methods**
3. **Content trust and image signing**
4. **Monitoring and maintenance automation**
5. **Production deployment patterns**

#### Recommended Actions:
1. **Repeat the lab exercises** in Chapter 07
2. **Practice registry deployment** with different auth methods
3. **Experiment with content trust** and signing
4. **Study monitoring configurations**
5. **Review enterprise registry patterns**

#### Additional Resources:
- [Docker Registry Documentation](https://docs.docker.com/registry/)
- [Notary Documentation](https://github.com/notaryproject/notary)
- [Cosign Documentation](https://docs.sigstore.dev/cosign/)
- Practice with the lab exercises

## ✅ Next Steps

### If you passed (75+):
- Proceed to **[Chapter 08: Docker Security](../08-docker-security/README.md)**
- Consider the advanced challenges in the lab
- Implement registry solutions in your organization

### If you need to improve:
- Review the failed sections
- Complete additional practice exercises
- Retake the checkpoint when ready

---

**🎉 Congratulations on completing the Docker Registry checkpoint!**

Mastering registry management is crucial for production Docker deployments. These skills enable you to build secure, scalable image distribution systems for your organization.

---

**[⬅️ Back to Chapter 07](../README.md)** | **[Next: Chapter 08 ➡️](../08-docker-security/README.md)** 