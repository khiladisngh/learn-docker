# 🧪 Lab 06: Docker Compose - Multi-Container Application Orchestration

In this lab, you'll practice advanced Docker Compose concepts including multi-service orchestration, scaling, environment management, and production deployment patterns.

## 🎯 Lab Objectives

By completing this lab, you will:
- Build complex multi-container applications with Docker Compose
- Implement service scaling and load balancing
- Manage environment-specific configurations
- Handle secrets and sensitive data securely
- Deploy production-ready applications

## 📋 Prerequisites

- Docker and Docker Compose installed
- Understanding of Docker containers and networking
- Basic knowledge of web applications and databases
- Text editor (VS Code, nano, vim)

## 🚀 Lab Exercises

### Exercise 1: Basic Multi-Service Application

**Goal:** Create a simple web application with frontend, backend, and database.

#### Step 1: Project Structure Setup

```bash
# Create project structure
mkdir -p compose-lab/{frontend,backend,database,nginx}
cd compose-lab

# Create basic file structure
touch docker-compose.yml
touch .env
mkdir -p secrets
```

#### Step 2: Backend API Service

```python
# Create backend/app.py
cat > backend/app.py << 'EOF'
#!/usr/bin/env python3
from flask import Flask, jsonify, request
import psycopg2
import os
import redis
from datetime import datetime
import json

app = Flask(__name__)

# Database connection
def get_db_connection():
    return psycopg2.connect(
        host=os.getenv('DB_HOST', 'postgres'),
        database=os.getenv('DB_NAME', 'webapp'),
        user=os.getenv('DB_USER', 'webapp'),
        password=os.getenv('DB_PASSWORD', 'password')
    )

# Redis connection
redis_client = redis.Redis(
    host=os.getenv('REDIS_HOST', 'redis'),
    port=int(os.getenv('REDIS_PORT', 6379)),
    decode_responses=True
)

@app.route('/api/health')
def health():
    """Health check endpoint"""
    try:
        # Test database connection
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT 1')
        cursor.close()
        conn.close()
        
        # Test Redis connection
        redis_client.ping()
        
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'services': {
                'database': 'healthy',
                'redis': 'healthy'
            }
        }), 200
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 503

@app.route('/api/users', methods=['GET'])
def get_users():
    """Get all users"""
    try:
        # Check cache first
        cached_users = redis_client.get('users')
        if cached_users:
            return jsonify(json.loads(cached_users))
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT id, name, email, created_at FROM users ORDER BY created_at DESC')
        users = [
            {
                'id': row[0],
                'name': row[1], 
                'email': row[2],
                'created_at': row[3].isoformat() if row[3] else None
            }
            for row in cursor.fetchall()
        ]
        cursor.close()
        conn.close()
        
        # Cache for 5 minutes
        redis_client.setex('users', 300, json.dumps(users))
        
        return jsonify(users)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/users', methods=['POST'])
def create_user():
    """Create new user"""
    try:
        data = request.get_json()
        name = data.get('name')
        email = data.get('email')
        
        if not name or not email:
            return jsonify({'error': 'Name and email are required'}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            'INSERT INTO users (name, email) VALUES (%s, %s) RETURNING id',
            (name, email)
        )
        user_id = cursor.fetchone()[0]
        conn.commit()
        cursor.close()
        conn.close()
        
        # Clear cache
        redis_client.delete('users')
        
        return jsonify({
            'id': user_id,
            'name': name,
            'email': email,
            'message': 'User created successfully'
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/stats')
def get_stats():
    """Get application statistics"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT COUNT(*) FROM users')
        user_count = cursor.fetchone()[0]
        cursor.close()
        conn.close()
        
        return jsonify({
            'total_users': user_count,
            'timestamp': datetime.now().isoformat(),
            'version': '1.0.0'
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
EOF

# Create backend requirements
cat > backend/requirements.txt << 'EOF'
Flask==2.3.2
psycopg2-binary==2.9.7
redis==4.6.0
gunicorn==21.2.0
EOF

# Create backend Dockerfile
cat > backend/Dockerfile << 'EOF'
FROM python:3.11-alpine

# Install system dependencies
RUN apk add --no-cache postgresql-dev gcc musl-dev curl

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app.py .

# Create non-root user
RUN adduser -D -s /bin/sh appuser
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/api/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
EOF
```

#### Step 3: Frontend Application

```html
<!-- Create frontend/index.html -->
cat > frontend/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Docker Compose Lab</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .form-group {
            margin-bottom: 15px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }
        input[type="text"], input[type="email"] {
            width: 100%;
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-sizing: border-box;
        }
        button {
            background-color: #007bff;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            margin-right: 10px;
        }
        button:hover {
            background-color: #0056b3;
        }
        .user-list {
            margin-top: 20px;
        }
        .user-item {
            background: #f8f9fa;
            padding: 10px;
            margin: 5px 0;
            border-radius: 4px;
            border-left: 4px solid #007bff;
        }
        .stats {
            background: #e9ecef;
            padding: 15px;
            border-radius: 4px;
            margin-bottom: 20px;
        }
        .error {
            color: #dc3545;
            background: #f8d7da;
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
        }
        .success {
            color: #155724;
            background: #d4edda;
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐙 Docker Compose Lab</h1>
        
        <div id="stats" class="stats">
            <h3>Application Statistics</h3>
            <p id="stats-content">Loading...</p>
        </div>

        <h2>Add New User</h2>
        <form id="userForm">
            <div class="form-group">
                <label for="name">Name:</label>
                <input type="text" id="name" name="name" required>
            </div>
            <div class="form-group">
                <label for="email">Email:</label>
                <input type="email" id="email" name="email" required>
            </div>
            <button type="submit">Add User</button>
            <button type="button" onclick="loadUsers()">Refresh Users</button>
        </form>

        <div id="message"></div>

        <div class="user-list">
            <h2>Users</h2>
            <div id="users">Loading users...</div>
        </div>
    </div>

    <script>
        const API_URL = '/api';

        // Load statistics
        function loadStats() {
            fetch(`${API_URL}/stats`)
                .then(response => response.json())
                .then(data => {
                    document.getElementById('stats-content').innerHTML = `
                        <strong>Total Users:</strong> ${data.total_users}<br>
                        <strong>Version:</strong> ${data.version}<br>
                        <strong>Last Updated:</strong> ${new Date(data.timestamp).toLocaleString()}
                    `;
                })
                .catch(error => {
                    document.getElementById('stats-content').innerHTML = 'Error loading stats';
                    console.error('Error:', error);
                });
        }

        // Load users
        function loadUsers() {
            fetch(`${API_URL}/users`)
                .then(response => response.json())
                .then(users => {
                    const usersDiv = document.getElementById('users');
                    if (users.length === 0) {
                        usersDiv.innerHTML = '<p>No users found. Add some users!</p>';
                    } else {
                        usersDiv.innerHTML = users.map(user => `
                            <div class="user-item">
                                <strong>${user.name}</strong> - ${user.email}<br>
                                <small>ID: ${user.id} | Created: ${new Date(user.created_at).toLocaleString()}</small>
                            </div>
                        `).join('');
                    }
                    loadStats(); // Refresh stats
                })
                .catch(error => {
                    document.getElementById('users').innerHTML = '<div class="error">Error loading users</div>';
                    console.error('Error:', error);
                });
        }

        // Show message
        function showMessage(message, isError = false) {
            const messageDiv = document.getElementById('message');
            messageDiv.innerHTML = `<div class="${isError ? 'error' : 'success'}">${message}</div>`;
            setTimeout(() => {
                messageDiv.innerHTML = '';
            }, 3000);
        }

        // Handle form submission
        document.getElementById('userForm').addEventListener('submit', function(e) {
            e.preventDefault();
            
            const formData = new FormData(e.target);
            const userData = {
                name: formData.get('name'),
                email: formData.get('email')
            };

            fetch(`${API_URL}/users`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(userData)
            })
            .then(response => response.json())
            .then(data => {
                if (data.error) {
                    showMessage(data.error, true);
                } else {
                    showMessage(`User ${data.name} created successfully!`);
                    document.getElementById('userForm').reset();
                    loadUsers();
                }
            })
            .catch(error => {
                showMessage('Error creating user', true);
                console.error('Error:', error);
            });
        });

        // Load data on page load
        document.addEventListener('DOMContentLoaded', function() {
            loadUsers();
            loadStats();
            
            // Refresh stats every 30 seconds
            setInterval(loadStats, 30000);
        });
    </script>
</body>
</html>
EOF

# Create frontend Dockerfile
cat > frontend/Dockerfile << 'EOF'
FROM nginx:alpine

# Copy HTML file
COPY index.html /usr/share/nginx/html/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1
EOF

# Create nginx configuration for frontend
cat > frontend/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    
    root /usr/share/nginx/html;
    index index.html;
    
    # Serve static files
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Proxy API requests to backend
    location /api/ {
        proxy_pass http://backend:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
```

#### Step 4: Database Initialization

```sql
-- Create database/init.sql
cat > database/init.sql << 'EOF'
-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO users (name, email) VALUES 
    ('Alice Johnson', 'alice@example.com'),
    ('Bob Smith', 'bob@example.com'),
    ('Charlie Brown', 'charlie@example.com')
ON CONFLICT (email) DO NOTHING;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
EOF
```

#### Step 5: Basic Compose Configuration

```yaml
# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  frontend:
    build: ./frontend
    ports:
      - "80:80"
    depends_on:
      - backend
    networks:
      - frontend
    restart: unless-stopped

  backend:
    build: ./backend
    environment:
      - DB_HOST=postgres
      - DB_NAME=webapp
      - DB_USER=webapp
      - DB_PASSWORD=${DB_PASSWORD:-password}
      - REDIS_HOST=redis
      - REDIS_PORT=6379
    depends_on:
      - postgres
      - redis
    networks:
      - frontend
      - backend
    restart: unless-stopped

  postgres:
    image: postgres:13
    environment:
      - POSTGRES_DB=webapp
      - POSTGRES_USER=webapp
      - POSTGRES_PASSWORD=${DB_PASSWORD:-password}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - backend
    restart: unless-stopped

  redis:
    image: redis:alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - backend
    restart: unless-stopped

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true

volumes:
  postgres_data:
  redis_data:
EOF

# Create environment file
cat > .env << 'EOF'
# Database configuration
DB_PASSWORD=secure_password_123

# Application settings
NODE_ENV=development
LOG_LEVEL=info
EOF
```

#### Step 6: Test Basic Setup

```bash
# Build and start services
docker-compose up --build -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f backend

# Test the application
curl http://localhost/api/health
curl http://localhost/api/users

# Access web interface
echo "🌐 Open http://localhost in your browser"

# Monitor resources
docker-compose top
```

### Exercise 2: Service Scaling and Load Balancing

**Goal:** Implement service scaling with load balancing.

#### Step 1: HAProxy Load Balancer

```bash
# Create HAProxy configuration
cat > haproxy.cfg << 'EOF'
global
    daemon
    log stdout local0
    maxconn 4096

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    timeout http-request 15s
    timeout http-keep-alive 15s
    log global
    option httplog
    option dontlognull
    option redispatch
    retries 3

# Frontend for web traffic
frontend web_frontend
    bind *:80
    capture request header Host len 32
    default_backend web_servers

# Backend pool for web servers
backend web_servers
    balance roundrobin
    option httpchk GET /api/health
    server-template backend 5 backend:8080 check

# HAProxy stats page
frontend stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 30s
    stats admin if TRUE
EOF

# Update docker-compose.yml to include HAProxy
cat > docker-compose.scale.yml << 'EOF'
version: '3.8'

services:
  # Load Balancer
  haproxy:
    image: haproxy:alpine
    ports:
      - "80:80"
      - "8404:8404"  # Stats page
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
    depends_on:
      - backend
    networks:
      - frontend
    restart: unless-stopped

  frontend:
    build: ./frontend
    # Remove port mapping since HAProxy handles it
    depends_on:
      - backend
    networks:
      - frontend
    restart: unless-stopped

  backend:
    build: ./backend
    environment:
      - DB_HOST=postgres
      - DB_NAME=webapp
      - DB_USER=webapp
      - DB_PASSWORD=${DB_PASSWORD:-password}
      - REDIS_HOST=redis
      - REDIS_PORT=6379
    depends_on:
      - postgres
      - redis
    networks:
      - frontend
      - backend
    restart: unless-stopped
    # Don't expose ports - HAProxy will handle traffic

  postgres:
    image: postgres:13
    environment:
      - POSTGRES_DB=webapp
      - POSTGRES_USER=webapp
      - POSTGRES_PASSWORD=${DB_PASSWORD:-password}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - backend
    restart: unless-stopped

  redis:
    image: redis:alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - backend
    restart: unless-stopped

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true

volumes:
  postgres_data:
  redis_data:
EOF
```

#### Step 2: Test Service Scaling

```bash
# Stop current setup
docker-compose down

# Start with scaling configuration
docker-compose -f docker-compose.scale.yml up -d

# Scale backend service to 3 instances
docker-compose -f docker-compose.scale.yml up -d --scale backend=3

# Check running services
docker-compose -f docker-compose.scale.yml ps

# View HAProxy stats
echo "📊 HAProxy Stats: http://localhost:8404/stats"

# Test load balancing
for i in {1..10}; do
    echo "Request $i:"
    curl -s http://localhost/api/stats | grep timestamp
    sleep 1
done
```

### Exercise 3: Environment Management

**Goal:** Create environment-specific configurations for development, staging, and production.

#### Step 1: Development Override

```yaml
# Create docker-compose.override.yml (development)
cat > docker-compose.override.yml << 'EOF'
version: '3.8'

services:
  frontend:
    ports:
      - "3000:80"
    volumes:
      - ./frontend:/usr/share/nginx/html
    environment:
      - NODE_ENV=development

  backend:
    ports:
      - "8080:8080"
    volumes:
      - ./backend:/app
    environment:
      - FLASK_ENV=development
      - FLASK_DEBUG=1
    command: python app.py

  postgres:
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_PASSWORD=dev_password

  redis:
    ports:
      - "6379:6379"
EOF
```

#### Step 2: Production Configuration

```yaml
# Create docker-compose.prod.yml
cat > docker-compose.prod.yml << 'EOF'
version: '3.8'

services:
  frontend:
    build:
      context: ./frontend
      target: production
    restart: always
    deploy:
      resources:
        limits:
          memory: 128M
        reservations:
          memory: 64M

  backend:
    build:
      context: ./backend
      target: production
    restart: always
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password
      - REDIS_PASSWORD_FILE=/run/secrets/redis_password
    secrets:
      - db_password
      - redis_password
    deploy:
      replicas: 3
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

  postgres:
    restart: always
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    secrets:
      - db_password
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M

  redis:
    restart: always
    command: redis-server --appendonly yes --requirepass_FILE /run/secrets/redis_password
    secrets:
      - redis_password
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M

  # Add monitoring
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    networks:
      - monitoring
    restart: always

  grafana:
    image: grafana/grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD_FILE=/run/secrets/grafana_password
    secrets:
      - grafana_password
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - monitoring
    restart: always

networks:
  monitoring:
    driver: bridge
    internal: true

volumes:
  prometheus_data:
  grafana_data:

secrets:
  db_password:
    file: ./secrets/db_password.txt
  redis_password:
    file: ./secrets/redis_password.txt
  grafana_password:
    file: ./secrets/grafana_password.txt
EOF
```

#### Step 3: Secrets Management

```bash
# Create secrets directory and files
mkdir -p secrets

echo "super_secure_db_password_123" > secrets/db_password.txt
echo "redis_password_456" > secrets/redis_password.txt
echo "grafana_admin_789" > secrets/grafana_password.txt

# Secure the secrets
chmod 600 secrets/*.txt

# Create monitoring configuration
mkdir -p monitoring

cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'backend'
    static_configs:
      - targets: ['backend:8080']
    metrics_path: '/api/metrics'
EOF
```

#### Step 4: Test Different Environments

```bash
# Development (default)
docker-compose up -d
echo "🔧 Development: http://localhost:3000"

# Production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
echo "🚀 Production: http://localhost"
echo "📊 Monitoring: http://localhost:9090 (Prometheus), http://localhost:3001 (Grafana)"

# Custom staging environment
cat > docker-compose.staging.yml << 'EOF'
version: '3.8'

services:
  backend:
    deploy:
      replicas: 2
    environment:
      - NODE_ENV=staging

  postgres:
    environment:
      - POSTGRES_DB=webapp_staging
EOF

docker-compose -f docker-compose.yml -f docker-compose.staging.yml up -d
echo "🧪 Staging environment ready"
```

### Exercise 4: Advanced Compose Features

**Goal:** Implement advanced features like health checks, dependency management, and monitoring.

#### Step 1: Enhanced Health Checks

```yaml
# Create docker-compose.advanced.yml
cat > docker-compose.advanced.yml << 'EOF'
version: '3.8'

services:
  frontend:
    build: ./frontend
    ports:
      - "80:80"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - frontend
    restart: unless-stopped

  backend:
    build: ./backend
    environment:
      - DB_HOST=postgres
      - DB_NAME=webapp
      - DB_USER=webapp
      - DB_PASSWORD=${DB_PASSWORD:-password}
      - REDIS_HOST=redis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - frontend
      - backend
    restart: unless-stopped

  postgres:
    image: postgres:13
    environment:
      - POSTGRES_DB=webapp
      - POSTGRES_USER=webapp
      - POSTGRES_PASSWORD=${DB_PASSWORD:-password}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U webapp -d webapp"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    networks:
      - backend
    restart: unless-stopped

  redis:
    image: redis:alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    networks:
      - backend
    restart: unless-stopped

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true

volumes:
  postgres_data:
  redis_data:
EOF
```

#### Step 2: Monitoring and Logging

```python
# Create monitoring script
cat > monitor-compose.py << 'EOF'
#!/usr/bin/env python3
import subprocess
import json
import time
from datetime import datetime
import sys

class ComposeMonitor:
    def __init__(self, compose_file=None):
        self.compose_file = compose_file or "docker-compose.yml"
        
    def get_services_status(self):
        """Get status of all services"""
        try:
            cmd = ["docker-compose", "-f", self.compose_file, "ps", "--format", "json"]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                services = []
                for line in result.stdout.strip().split('\n'):
                    if line.strip():
                        try:
                            services.append(json.loads(line))
                        except json.JSONDecodeError:
                            continue
                return services
            return []
        except Exception as e:
            print(f"Error getting services: {e}")
            return []
    
    def check_health_status(self, service_name):
        """Check health status of a service"""
        try:
            cmd = ["docker", "inspect", service_name, "--format", "{{.State.Health.Status}}"]
            result = subprocess.run(cmd, capture_output=True, text=True)
            return result.stdout.strip() if result.returncode == 0 else "unknown"
        except:
            return "unknown"
    
    def get_container_logs(self, service_name, lines=20):
        """Get recent logs for a service"""
        try:
            cmd = ["docker-compose", "-f", self.compose_file, "logs", "--tail", str(lines), service_name]
            result = subprocess.run(cmd, capture_output=True, text=True)
            return result.stdout
        except Exception as e:
            return f"Error getting logs: {e}"
    
    def monitor_services(self, interval=30):
        """Monitor services continuously"""
        print(f"🔍 Monitoring services from {self.compose_file}")
        print(f"Refresh interval: {interval} seconds")
        print("Press Ctrl+C to stop\n")
        
        while True:
            try:
                print(f"{'='*60}")
                print(f"📊 Service Status Report - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
                print(f"{'='*60}")
                
                services = self.get_services_status()
                
                if not services:
                    print("❌ No services found or error retrieving status")
                    time.sleep(interval)
                    continue
                
                for service in services:
                    name = service.get('Name', 'Unknown')
                    state = service.get('State', 'Unknown')
                    status = service.get('Status', 'Unknown')
                    
                    # Get health status
                    health = self.check_health_status(name)
                    
                    # Status emoji
                    if state == 'running':
                        if health == 'healthy':
                            emoji = "✅"
                        elif health == 'unhealthy':
                            emoji = "❌"
                        elif health == 'starting':
                            emoji = "🔄"
                        else:
                            emoji = "🟡"
                    else:
                        emoji = "🔴"
                    
                    print(f"{emoji} {name:20} | {state:10} | Health: {health:10} | {status}")
                
                print(f"\n🔗 Quick Commands:")
                print(f"  View logs: docker-compose -f {self.compose_file} logs -f [service]")
                print(f"  Restart:   docker-compose -f {self.compose_file} restart [service]")
                print(f"  Scale:     docker-compose -f {self.compose_file} up -d --scale [service]=[num]")
                
                time.sleep(interval)
                
            except KeyboardInterrupt:
                print("\n\n👋 Monitoring stopped by user")
                break
            except Exception as e:
                print(f"❌ Error during monitoring: {e}")
                time.sleep(interval)

if __name__ == "__main__":
    compose_file = sys.argv[1] if len(sys.argv) > 1 else "docker-compose.yml"
    monitor = ComposeMonitor(compose_file)
    monitor.monitor_services()
EOF

chmod +x monitor-compose.py
```

#### Step 3: Deployment Automation

```bash
# Create deployment script
cat > deploy.sh << 'EOF'
#!/bin/bash

set -e

ENVIRONMENT=${1:-development}
COMPOSE_FILES=""
PROJECT_NAME="compose-lab"

# Configure compose files based on environment
case $ENVIRONMENT in
    "development")
        COMPOSE_FILES="docker-compose.yml"
        ;;
    "staging")
        COMPOSE_FILES="docker-compose.yml:docker-compose.staging.yml"
        ;;
    "production")
        COMPOSE_FILES="docker-compose.yml:docker-compose.prod.yml"
        ;;
    "advanced")
        COMPOSE_FILES="docker-compose.advanced.yml"
        ;;
    *)
        echo "❌ Unknown environment: $ENVIRONMENT"
        echo "Available environments: development, staging, production, advanced"
        exit 1
        ;;
esac

echo "🚀 Deploying $PROJECT_NAME to $ENVIRONMENT environment"
echo "📄 Using compose files: $COMPOSE_FILES"

# Create backup of current state
echo "📦 Creating backup..."
BACKUP_FILE="backup-${ENVIRONMENT}-$(date +%Y%m%d_%H%M%S).yml"
COMPOSE_FILE=$COMPOSE_FILES docker-compose config > $BACKUP_FILE
echo "✅ Backup saved to $BACKUP_FILE"

# Build images
echo "🔨 Building images..."
COMPOSE_FILE=$COMPOSE_FILES docker-compose build

# Pull external images
echo "⬇️ Pulling external images..."
COMPOSE_FILE=$COMPOSE_FILES docker-compose pull

# Deploy services
echo "🎯 Deploying services..."
COMPOSE_FILE=$COMPOSE_FILES docker-compose up -d

# Wait for services to be healthy
echo "🩺 Waiting for services to become healthy..."
sleep 30

# Verify deployment
echo "✅ Verifying deployment..."
COMPOSE_FILE=$COMPOSE_FILES docker-compose ps

# Show service URLs
echo ""
echo "🌐 Service URLs:"
case $ENVIRONMENT in
    "development")
        echo "  Frontend: http://localhost:3000"
        echo "  Backend:  http://localhost:8080"
        ;;
    "production")
        echo "  Application: http://localhost"
        echo "  Prometheus:  http://localhost:9090"
        echo "  Grafana:     http://localhost:3001"
        ;;
    *)
        echo "  Application: http://localhost"
        ;;
esac

echo ""
echo "🎉 Deployment completed successfully!"
echo "📊 Monitor with: python3 monitor-compose.py ${COMPOSE_FILES%%:*}"
EOF

chmod +x deploy.sh
```

## ✅ Lab Verification

### Verification Steps

1. **Basic Multi-Service Verification:**
   ```bash
   # Test all services are running
   docker-compose ps
   
   # Test health endpoints
   curl http://localhost/api/health
   
   # Test application functionality
   curl -X POST http://localhost/api/users \
     -H "Content-Type: application/json" \
     -d '{"name": "Test User", "email": "test@example.com"}'
   ```

2. **Scaling Verification:**
   ```bash
   # Scale backend service
   docker-compose -f docker-compose.scale.yml up -d --scale backend=3
   
   # Check HAProxy stats
   curl http://localhost:8404/stats
   ```

3. **Environment Management Verification:**
   ```bash
   # Test different environments
   ./deploy.sh development
   ./deploy.sh production
   ```

4. **Monitoring Verification:**
   ```bash
   # Run monitoring script
   python3 monitor-compose.py &
   MONITOR_PID=$!
   sleep 60
   kill $MONITOR_PID
   ```

### Expected Outcomes

- Multi-service application should run with proper inter-service communication
- Load balancing should distribute requests across scaled backend instances
- Environment-specific configurations should work correctly
- Health checks should properly monitor service status
- Monitoring tools should provide real-time service status

## 🧹 Cleanup

```bash
# Stop all services
docker-compose down
docker-compose -f docker-compose.scale.yml down
docker-compose -f docker-compose.advanced.yml down

# Remove all volumes
docker volume prune -f

# Remove lab files
rm -f docker-compose.*.yml haproxy.cfg monitor-compose.py deploy.sh
rm -rf secrets monitoring backup-*.yml
rm -rf frontend backend database

echo "🧹 Lab cleanup completed!"
```

## 📚 Additional Challenges

1. **Implement service mesh** using Consul Connect or Istio sidecar
2. **Add distributed tracing** with Jaeger or Zipkin
3. **Create auto-scaling** based on CPU/memory metrics
4. **Implement blue-green deployment** strategy
5. **Add comprehensive logging** with ELK stack

## 🎯 Lab Summary

In this lab, you:
- ✅ Built complex multi-container applications with Docker Compose
- ✅ Implemented service scaling and load balancing with HAProxy
- ✅ Managed environment-specific configurations
- ✅ Handled secrets and sensitive data securely
- ✅ Created monitoring and deployment automation

**🎉 Congratulations!** You've mastered Docker Compose for production-ready application orchestration.

---

**[⬅️ Back to Chapter 06](../README.md)** | **[Next: Checkpoint ➡️](../checkpoint.md)** 