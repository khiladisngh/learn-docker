# 🐳 Chapter 01: Docker Basics - Your First Docker Application

Welcome to hands-on Docker development! In this chapter, you'll master the essential Docker commands and build your first containerized application from scratch.

## 🎯 Learning Objectives

By the end of this chapter, you will:
- ✅ Master essential Docker CLI commands
- ✅ Understand Docker image layers and caching
- ✅ Build your first Dockerfile
- ✅ Create and manage containers effectively
- ✅ Implement best practices for development workflows
- ✅ Build a complete web application with Docker

## 🛠️ Essential Docker Commands

### Container Lifecycle Management

```bash
# Create and run a new container
docker run [OPTIONS] IMAGE [COMMAND] [ARG...]

# Common options:
docker run -d nginx                    # Run in background (detached)
docker run -it ubuntu bash             # Interactive with terminal
docker run -p 8080:80 nginx           # Port mapping
docker run --name my-app nginx        # Custom name
docker run -v /host:/container nginx   # Volume mounting
docker run -e ENV_VAR=value nginx     # Environment variables

# Container management
docker ps                             # List running containers
docker ps -a                          # List all containers (including stopped)
docker start container_name           # Start existing container
docker stop container_name            # Stop running container
docker restart container_name         # Restart container
docker rm container_name              # Remove container
docker rm -f container_name           # Force remove running container
```

### Image Management

```bash
# Image operations
docker images                         # List local images
docker pull image:tag                 # Download image from registry
docker build -t name:tag .            # Build image from Dockerfile
docker tag source:tag target:tag      # Tag an image
docker rmi image:tag                  # Remove image
docker save -o file.tar image:tag     # Export image to tar file
docker load -i file.tar               # Import image from tar file

# Image inspection
docker inspect image:tag              # Detailed image information
docker history image:tag              # Show image layers
```

### System Commands

```bash
# System information
docker info                           # System-wide information
docker version                        # Docker version info
docker system df                      # Disk usage
docker system prune                   # Clean up unused resources

# Container inspection and debugging
docker logs container_name            # View container logs
docker exec -it container_name bash   # Execute command in running container
docker inspect container_name         # Detailed container information
docker stats                          # Real-time resource usage
docker top container_name             # Running processes in container
```

## 📦 Understanding Docker Images

### Image Layers and Caching

Docker images are built in layers, and each layer represents a filesystem change:

```dockerfile
# Each instruction creates a new layer
FROM ubuntu:20.04          # Layer 1: Base Ubuntu filesystem
RUN apt-get update         # Layer 2: Package index update
RUN apt-get install nginx  # Layer 3: Nginx installation
COPY app/ /var/www/html/   # Layer 4: Application files
```

**Key Benefits:**
- **Caching**: Unchanged layers are reused
- **Efficiency**: Multiple images can share layers
- **Speed**: Only changed layers need rebuilding

### Layer Optimization Example

❌ **Inefficient Dockerfile:**
```dockerfile
FROM node:16
COPY . /app
WORKDIR /app
RUN npm install
```

✅ **Optimized Dockerfile:**
```dockerfile
FROM node:16
WORKDIR /app
# Copy package files first (changes less frequently)
COPY package*.json ./
RUN npm install
# Copy source code last (changes frequently)
COPY . .
```

## 🏗️ Your First Dockerfile

Let's build a simple Node.js web application:

### Step 1: Create the Application

**package.json:**
```json
{
  "name": "my-docker-app",
  "version": "1.0.0",
  "description": "My first Docker application",
  "main": "app.js",
  "scripts": {
    "start": "node app.js"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
```

**app.js:**
```javascript
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from Docker!',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    hostname: require('os').hostname()
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running at http://0.0.0.0:${port}`);
});
```

### Step 2: Create the Dockerfile

**Dockerfile:**
```dockerfile
# Use official Node.js runtime as base image
FROM node:16-alpine

# Set working directory inside container
WORKDIR /usr/src/app

# Copy package files first (for better caching)
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application source code
COPY . .

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Change ownership of app directory
RUN chown -R nextjs:nodejs /usr/src/app
USER nextjs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Define default command
CMD ["npm", "start"]
```

### Step 3: Build and Run

```bash
# Build the image
docker build -t my-node-app:1.0 .

# Run the container
docker run -d -p 3000:3000 --name my-app my-node-app:1.0

# Test the application
curl http://localhost:3000

# Check logs
docker logs my-app

# Stop and remove
docker stop my-app
docker rm my-app
```

## 🔧 Dockerfile Instructions Deep Dive

### Essential Instructions

| Instruction | Purpose | Example |
|-------------|---------|---------|
| `FROM` | Base image | `FROM node:16-alpine` |
| `WORKDIR` | Set working directory | `WORKDIR /app` |
| `COPY` | Copy files from host | `COPY . /app` |
| `ADD` | Copy + extract archives | `ADD app.tar.gz /app` |
| `RUN` | Execute commands | `RUN npm install` |
| `CMD` | Default command | `CMD ["npm", "start"]` |
| `ENTRYPOINT` | Fixed entry point | `ENTRYPOINT ["node"]` |
| `EXPOSE` | Document ports | `EXPOSE 3000` |
| `ENV` | Environment variables | `ENV NODE_ENV=production` |
| `ARG` | Build-time variables | `ARG VERSION=1.0` |
| `VOLUME` | Mount points | `VOLUME ["/data"]` |
| `USER` | Set user | `USER nodejs` |
| `HEALTHCHECK` | Health monitoring | `HEALTHCHECK CMD curl -f http://localhost:3000/health` |

### Multi-Stage Builds

Build optimized production images:

```dockerfile
# Build stage
FROM node:16-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM node:16-alpine AS production
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY --from=builder /app/dist ./dist
USER node
EXPOSE 3000
CMD ["node", "dist/app.js"]
```

## 🌐 Real-World Example: Full-Stack Application

Let's build a complete web application with database:

### Frontend (React)

**frontend/Dockerfile:**
```dockerfile
# Multi-stage build for React app
FROM node:16-alpine AS build

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Production stage with nginx
FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**frontend/nginx.conf:**
```nginx
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    server {
        listen 80;
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
            try_files $uri $uri/ /index.html;
        }
        
        location /api {
            proxy_pass http://backend:3000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```

### Backend API

**backend/Dockerfile:**
```dockerfile
FROM node:16-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001
RUN chown -R nextjs:nodejs /app
USER nextjs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["npm", "start"]
```

### Docker Compose Setup

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  frontend:
    build: ./frontend
    ports:
      - "80:80"
    depends_on:
      - backend
    networks:
      - app-network

  backend:
    build: ./backend
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DB_HOST=database
      - DB_USER=myuser
      - DB_PASSWORD=mypass
      - DB_NAME=myapp
    depends_on:
      - database
    networks:
      - app-network

  database:
    image: postgres:13-alpine
    environment:
      - POSTGRES_USER=myuser
      - POSTGRES_PASSWORD=mypass
      - POSTGRES_DB=myapp
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app-network

volumes:
  postgres_data:

networks:
  app-network:
    driver: bridge
```

## 🎯 Container Debugging and Troubleshooting

### Common Issues and Solutions

#### Container Won't Start
```bash
# Check exit code and logs
docker ps -a
docker logs container_name

# Common exit codes:
# 0: Success
# 1: General error
# 125: Docker daemon error
# 126: Container command not executable
# 127: Container command not found
```

#### Port Conflicts
```bash
# Check what's using a port
netstat -tulpn | grep :3000

# Use different port
docker run -p 3001:3000 my-app
```

#### Image Build Failures
```bash
# Build with verbose output
docker build --no-cache --progress=plain -t my-app .

# Debug specific layer
docker run -it --rm <intermediate_image_id> /bin/sh
```

#### Container Resource Issues
```bash
# Monitor resource usage
docker stats container_name

# Set resource limits
docker run --memory="256m" --cpus="0.5" my-app
```

### Debugging Commands

```bash
# Enter running container
docker exec -it container_name /bin/bash

# Copy files from container
docker cp container_name:/path/to/file ./local/path

# View file changes
docker diff container_name

# Export container as image
docker commit container_name new_image:tag

# Inspect container network
docker network ls
docker network inspect bridge
```

## 🔒 Security Best Practices

### Image Security

```dockerfile
# Use specific tags, not 'latest'
FROM node:16.17.0-alpine

# Run as non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001
USER nextjs

# Use multi-stage builds to reduce attack surface
FROM node:16-alpine AS build
# ... build steps ...
FROM node:16-alpine AS production
COPY --from=build /app/dist ./dist

# Scan for vulnerabilities
# docker scout quickview my-app:latest
```

### Runtime Security

```bash
# Run with security options
docker run --read-only --tmpfs /tmp my-app

# Limit capabilities
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE my-app

# Use security profiles
docker run --security-opt=no-new-privileges my-app
```

## 📝 Development Workflow

### Development vs Production Images

**Dockerfile.dev:**
```dockerfile
FROM node:16-alpine

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .

# Install development dependencies
RUN npm install

# Development server with hot reload
CMD ["npm", "run", "dev"]
```

**Build and run for development:**
```bash
# Build development image
docker build -f Dockerfile.dev -t my-app:dev .

# Run with volume mounting for hot reload
docker run -d -p 3000:3000 \
  -v $(pwd):/app \
  -v /app/node_modules \
  --name my-app-dev \
  my-app:dev
```

## 🐍 Python Examples in Docker

### Python Flask Web Application

Let's create a complete Python Flask application with best practices:

**requirements.txt:**
```txt
Flask==2.3.2
gunicorn==20.1.0
redis==4.6.0
psycopg2-binary==2.9.7
python-dotenv==1.0.0
```

**app.py:**
```python
from flask import Flask, jsonify, request
import os
import redis
import psycopg2
from datetime import datetime
import socket

app = Flask(__name__)

# Configuration
DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'
PORT = int(os.getenv('PORT', 5000))
REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://user:pass@localhost/db')

# Initialize Redis connection
try:
    redis_client = redis.from_url(REDIS_URL)
    redis_client.ping()
    redis_available = True
except:
    redis_available = False

@app.route('/')
def hello():
    hostname = socket.gethostname()
    
    # Increment visit counter in Redis
    visits = 0
    if redis_available:
        try:
            visits = redis_client.incr('visits')
        except:
            pass
    
    return jsonify({
        'message': 'Hello from Python Flask in Docker!',
        'version': '1.0.0',
        'timestamp': datetime.now().isoformat(),
        'hostname': hostname,
        'environment': os.getenv('FLASK_ENV', 'development'),
        'visits': visits,
        'redis_available': redis_available,
        'debug': DEBUG
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    health_status = {
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'services': {
            'redis': redis_available
        }
    }
    
    # Test database connection
    try:
        conn = psycopg2.connect(DATABASE_URL)
        conn.close()
        health_status['services']['database'] = True
    except:
        health_status['services']['database'] = False
    
    status_code = 200 if all(health_status['services'].values()) else 503
    return jsonify(health_status), status_code

@app.route('/api/users', methods=['GET'])
def get_users():
    """Get users from database"""
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        cur.execute("SELECT id, name, email FROM users LIMIT 10")
        users = [{'id': row[0], 'name': row[1], 'email': row[2]} for row in cur.fetchall()]
        conn.close()
        return jsonify(users)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/users', methods=['POST'])
def create_user():
    """Create a new user"""
    data = request.get_json()
    if not data or 'name' not in data or 'email' not in data:
        return jsonify({'error': 'Name and email required'}), 400
    
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO users (name, email) VALUES (%s, %s) RETURNING id",
            (data['name'], data['email'])
        )
        user_id = cur.fetchone()[0]
        conn.commit()
        conn.close()
        
        return jsonify({
            'id': user_id,
            'name': data['name'],
            'email': data['email']
        }), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/cache/<key>')
def get_cache(key):
    """Get value from Redis cache"""
    if not redis_available:
        return jsonify({'error': 'Redis not available'}), 503
    
    try:
        value = redis_client.get(key)
        if value:
            return jsonify({'key': key, 'value': value.decode('utf-8')})
        else:
            return jsonify({'error': 'Key not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/cache/<key>', methods=['POST'])
def set_cache(key):
    """Set value in Redis cache"""
    if not redis_available:
        return jsonify({'error': 'Redis not available'}), 503
    
    data = request.get_json()
    if not data or 'value' not in data:
        return jsonify({'error': 'Value required'}), 400
    
    try:
        redis_client.setex(key, 3600, data['value'])  # 1 hour expiry
        return jsonify({'key': key, 'value': data['value'], 'expires_in': 3600})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print(f"🐍 Starting Flask app on port {PORT}")
    print(f"📊 Debug mode: {DEBUG}")
    print(f"🏠 Hostname: {socket.gethostname()}")
    print(f"🔴 Redis available: {redis_available}")
    
    if DEBUG:
        app.run(host='0.0.0.0', port=PORT, debug=True)
    else:
        # Use Gunicorn in production
        from gunicorn.app.wsgiapp import WSGIApplication
        options = {
            'bind': f'0.0.0.0:{PORT}',
            'workers': 4,
            'worker_class': 'sync',
            'timeout': 30,
            'keepalive': 2,
            'max_requests': 1000,
            'preload_app': True
        }
        WSGIApplication("%(prog)s [OPTIONS] [APP_MODULE]").run()
```

**Production-Ready Python Dockerfile:**
```dockerfile
# Multi-stage build for Python Flask
FROM python:3.11-alpine AS base

# Install system dependencies
RUN apk update && apk add --no-cache \
    gcc \
    musl-dev \
    linux-headers \
    postgresql-dev \
    curl \
    && rm -rf /var/cache/apk/*

# Set Python environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

FROM base AS dependencies

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

FROM dependencies AS application

# Copy application code
COPY --chown=appuser:appgroup . .

# Create necessary directories
RUN mkdir -p /app/logs && \
    chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Use gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "app:app"]
```

**Development Dockerfile:**
```dockerfile
FROM python:3.11-alpine

# Install system dependencies including dev tools
RUN apk update && apk add --no-cache \
    gcc \
    musl-dev \
    linux-headers \
    postgresql-dev \
    curl \
    git \
    && rm -rf /var/cache/apk/*

# Set environment
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    FLASK_ENV=development \
    DEBUG=True

WORKDIR /app

# Install dependencies including dev dependencies
COPY requirements.txt requirements-dev.txt ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir -r requirements-dev.txt

# Copy source code
COPY . .

EXPOSE 5000

# Development server with hot reload
CMD ["python", "app.py"]
```

## ✅ Quick Exercises

### Exercise 1: Python Data Science Application
Create a containerized data analysis service:

**Solution:**
```python
# data_app.py
from flask import Flask, jsonify, request
import pandas as pd
import numpy as np
import os
from datetime import datetime

app = Flask(__name__)

# Generate sample data
def generate_sample_data():
    np.random.seed(42)
    data = {
        'timestamp': pd.date_range('2024-01-01', periods=100, freq='D'),
        'sales': np.random.randint(1000, 5000, 100),
        'users': np.random.randint(50, 200, 100),
        'revenue': np.random.uniform(10000, 50000, 100)
    }
    return pd.DataFrame(data)

@app.route('/')
def index():
    return jsonify({
        'message': 'Python Data Science API',
        'endpoints': ['/stats', '/trends', '/health']
    })

@app.route('/stats')
def get_stats():
    df = generate_sample_data()
    stats = {
        'total_sales': int(df['sales'].sum()),
        'avg_daily_sales': float(df['sales'].mean()),
        'total_users': int(df['users'].sum()),
        'avg_revenue': float(df['revenue'].mean()),
        'max_sales_day': df.loc[df['sales'].idxmax(), 'timestamp'].isoformat()
    }
    return jsonify(stats)

@app.route('/trends')
def get_trends():
    df = generate_sample_data()
    # Calculate 7-day rolling average
    df['sales_trend'] = df['sales'].rolling(window=7).mean()
    df['users_trend'] = df['users'].rolling(window=7).mean()
    
    trends = {
        'sales_growth': float((df['sales'].iloc[-7:].mean() - df['sales'].iloc[:7].mean()) / df['sales'].iloc[:7].mean() * 100),
        'user_growth': float((df['users'].iloc[-7:].mean() - df['users'].iloc[:7].mean()) / df['users'].iloc[:7].mean() * 100),
        'latest_trends': df[['timestamp', 'sales_trend', 'users_trend']].tail(10).to_dict('records')
    }
    return jsonify(trends)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
```

**Data Science Dockerfile:**
```dockerfile
FROM python:3.11-slim

# Install system dependencies for data science
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements
COPY requirements-data.txt .

# Install Python packages for data science
RUN pip install --no-cache-dir -r requirements-data.txt

COPY data_app.py .

EXPOSE 5000

CMD ["python", "data_app.py"]
```

**requirements-data.txt:**
```txt
Flask==2.3.2
pandas==2.0.3
numpy==1.24.3
scikit-learn==1.3.0
matplotlib==3.7.2
seaborn==0.12.2
```

### Exercise 2: Environment Variables
Run the same container with different configurations:

```bash
# Development
docker run -e ENV=dev -e DEBUG=true my-app

# Production
docker run -e ENV=prod -e DEBUG=false my-app
```

### Exercise 3: Volume Mounting
```bash
# Mount host directory for persistent data
docker run -v /host/data:/container/data my-app

# Create named volume
docker volume create my-data
docker run -v my-data:/data my-app
```

## 🚀 What's Next?

In [Chapter 02: Docker Images](../02-docker-images/README.md), you'll learn:
- Advanced Dockerfile techniques
- Image optimization strategies
- Working with registries
- Image security scanning
- Custom base images

## 📚 Key Takeaways

✅ **Docker CLI mastery** is essential for daily development
✅ **Dockerfile optimization** improves build speed and image size
✅ **Layer caching** is crucial for efficient builds
✅ **Multi-stage builds** create production-ready images
✅ **Security practices** should be built into every image
✅ **Development workflows** can be streamlined with Docker

## 📝 Practice Checklist

Before moving on, ensure you can:
- [ ] Write effective Dockerfiles
- [ ] Build and run containers confidently
- [ ] Debug container issues
- [ ] Implement basic security practices
- [ ] Set up development workflows
- [ ] Use Docker Compose for multi-service apps

---

**🎉 Congratulations!** You now have solid Docker fundamentals. Complete the [lab exercise](lab/README.md) to reinforce your learning, then move on to the [checkpoint](checkpoint.md) to validate your progress!

---

<div align="center">

**[⬅️ Previous: Introduction](../00-introduction/README.md)** | **[Next: Docker Images ➡️](../02-docker-images/README.md)**

</div> 