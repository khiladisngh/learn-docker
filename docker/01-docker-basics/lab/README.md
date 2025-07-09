# 🧪 Lab Exercise: Docker Basics - Building Your First Application

Welcome to your hands-on Docker development lab! You'll build multiple applications, create Dockerfiles, and master container management.

## 🎯 Lab Objectives

By completing this lab, you will:
- ✅ Create production-ready Dockerfiles
- ✅ Build and optimize Docker images
- ✅ Manage container lifecycle effectively
- ✅ Implement security best practices
- ✅ Debug common container issues
- ✅ Set up development workflows

## 🛠️ Prerequisites

- Completed Chapter 00 lab
- Docker Desktop running
- Text editor (VS Code recommended)
- Basic knowledge of Node.js or Python

## 📝 Lab Setup

Create your lab workspace:

```bash
# Create lab directory
mkdir docker-basics-lab
cd docker-basics-lab

# Create project structure
mkdir -p {node-app,python-app,multi-stage-app}
```

## Part 1: Node.js Web Application

### Step 1: Create the Application

Create `node-app/package.json`:
```json
{
  "name": "docker-node-app",
  "version": "1.0.0",
  "description": "Learning Docker with Node.js",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^2.0.20"
  }
}
```

Create `node-app/server.js`:
```javascript
const express = require('express');
const cors = require('cors');
const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Hello from Dockerized Node.js!',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    hostname: require('os').hostname(),
    environment: process.env.NODE_ENV || 'development',
    uptime: process.uptime()
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy',
    timestamp: new Date().toISOString()
  });
});

app.get('/api/users', (req, res) => {
  res.json([
    { id: 1, name: 'Alice', email: 'alice@example.com' },
    { id: 2, name: 'Bob', email: 'bob@example.com' },
    { id: 3, name: 'Charlie', email: 'charlie@example.com' }
  ]);
});

app.post('/api/users', (req, res) => {
  const user = req.body;
  user.id = Date.now();
  res.status(201).json(user);
});

app.listen(port, '0.0.0.0', () => {
  console.log(`🚀 Server running on http://0.0.0.0:${port}`);
  console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🏠 Hostname: ${require('os').hostname()}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('📥 SIGTERM received, shutting down gracefully');
  process.exit(0);
});
```

### Step 2: Create Production Dockerfile

Create `node-app/Dockerfile`:
```dockerfile
# Use official Node.js runtime as base image
FROM node:18-alpine

# Set working directory
WORKDIR /usr/src/app

# Copy package files first (for better caching)
COPY package*.json ./

# Install production dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy application source
COPY . .

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Change ownership of the app directory
RUN chown -R nextjs:nodejs /usr/src/app
USER nextjs

# Expose port
EXPOSE 3000

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# Run the application
CMD ["npm", "start"]
```

### Step 3: Build and Test

```bash
cd node-app

# Build the image
docker build -t my-node-app:1.0 .

# Run the container
docker run -d -p 3000:3000 --name node-app my-node-app:1.0

# Test the application
curl http://localhost:3000
curl http://localhost:3000/health
curl http://localhost:3000/api/users

# Check logs
docker logs node-app

# Check health status
docker inspect node-app --format='{{.State.Health.Status}}'
```

### Step 4: Development Dockerfile

Create `node-app/Dockerfile.dev`:
```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev)
RUN npm install

# Copy source code
COPY . .

# Expose port
EXPOSE 3000

# Run development server with hot reload
CMD ["npm", "run", "dev"]
```

### Step 5: Environment Variables

```bash
# Run with environment variables
docker run -d -p 3001:3000 \
  --name node-app-prod \
  -e NODE_ENV=production \
  -e PORT=3000 \
  my-node-app:1.0

# Test environment
curl http://localhost:3001
```

## Part 2: Python Flask Application

### Step 1: Create Python Application

Create `python-app/requirements.txt`:
```txt
Flask==2.3.2
requests==2.31.0
python-dotenv==1.0.0
```

Create `python-app/app.py`:
```python
from flask import Flask, jsonify, request
import os
import socket
import time
import requests
from datetime import datetime

app = Flask(__name__)

# Configuration
DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'
PORT = int(os.getenv('PORT', 5000))

@app.route('/')
def hello():
    return jsonify({
        'message': 'Hello from Dockerized Python Flask!',
        'version': '1.0.0',
        'timestamp': datetime.now().isoformat(),
        'hostname': socket.gethostname(),
        'environment': os.getenv('FLASK_ENV', 'development'),
        'debug': DEBUG
    })

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat()
    }), 200

@app.route('/api/info')
def system_info():
    return jsonify({
        'python_version': os.sys.version,
        'platform': os.name,
        'hostname': socket.gethostname(),
        'current_time': datetime.now().isoformat(),
        'environment_variables': {
            'FLASK_ENV': os.getenv('FLASK_ENV'),
            'DEBUG': os.getenv('DEBUG'),
            'PORT': os.getenv('PORT')
        }
    })

@app.route('/api/external')
def external_api():
    try:
        response = requests.get('https://httpbin.org/json', timeout=5)
        return jsonify({
            'status': 'success',
            'data': response.json()
        })
    except requests.RequestException as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not found'}), 404

if __name__ == '__main__':
    print(f"🐍 Starting Flask app on port {PORT}")
    print(f"📊 Debug mode: {DEBUG}")
    print(f"🏠 Hostname: {socket.gethostname()}")
    
    app.run(host='0.0.0.0', port=PORT, debug=DEBUG)
```

### Step 2: Create Python Dockerfile

Create `python-app/Dockerfile`:
```dockerfile
# Use official Python runtime as base image
FROM python:3.11-alpine

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apk update && apk add --no-cache \
    gcc \
    musl-dev \
    linux-headers

# Copy requirements first (for better caching)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN adduser -D -s /bin/sh appuser
RUN chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:5000/health', timeout=3)"

# Run the application
CMD ["python", "app.py"]
```

### Step 3: Build and Test Python App

```bash
cd ../python-app

# Build the image
docker build -t my-python-app:1.0 .

# Run the container
docker run -d -p 5000:5000 --name python-app my-python-app:1.0

# Test the application
curl http://localhost:5000
curl http://localhost:5000/health
curl http://localhost:5000/api/info
curl http://localhost:5000/api/external

# Check logs
docker logs python-app
```

## Part 3: Multi-Stage Build

### Step 1: Create Multi-Stage Node.js App

Create `multi-stage-app/package.json`:
```json
{
  "name": "multi-stage-app",
  "version": "1.0.0",
  "scripts": {
    "build": "webpack --mode production",
    "start": "node dist/server.js"
  },
  "dependencies": {
    "express": "^4.18.0"
  },
  "devDependencies": {
    "webpack": "^5.88.0",
    "webpack-cli": "^5.1.0"
  }
}
```

Create `multi-stage-app/src/server.js`:
```javascript
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'Multi-stage build success!',
    build_time: new Date().toISOString(),
    hostname: require('os').hostname()
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Multi-stage app running on port ${port}`);
});
```

Create `multi-stage-app/webpack.config.js`:
```javascript
const path = require('path');

module.exports = {
  entry: './src/server.js',
  target: 'node',
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'server.js'
  },
  mode: 'production'
};
```

### Step 2: Multi-Stage Dockerfile

Create `multi-stage-app/Dockerfile`:
```dockerfile
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM node:18-alpine AS production

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install only production dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy built application from builder stage
COPY --from=builder /app/dist ./dist

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

RUN chown -R nextjs:nodejs /app
USER nextjs

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

CMD ["npm", "start"]
```

### Step 3: Build and Compare

```bash
cd ../multi-stage-app

# Build multi-stage image
docker build -t multi-stage-app:1.0 .

# Run the container
docker run -d -p 3002:3000 --name multi-stage-app multi-stage-app:1.0

# Test
curl http://localhost:3002

# Compare image sizes
docker images | grep -E "(my-node-app|my-python-app|multi-stage-app)"
```

## Part 4: Container Management & Debugging

### Step 1: Container Inspection

```bash
# List all containers
docker ps -a

# Inspect containers
docker inspect node-app | jq '.[]'

# Check resource usage
docker stats --no-stream

# View container processes
docker top node-app

# Check container logs with timestamps
docker logs -t node-app

# Follow logs in real-time
docker logs -f python-app
```

### Step 2: Interactive Debugging

```bash
# Execute commands in running container
docker exec -it node-app /bin/sh

# Inside the container, explore:
ps aux
ls -la
cat /etc/passwd
whoami
exit

# Copy files from container
docker cp node-app:/usr/src/app/package.json ./package-from-container.json

# View filesystem changes
docker diff node-app
```

### Step 3: Troubleshooting Exercise

```bash
# Intentionally break a container
docker run -d --name broken-app \
  -p 9999:3000 \
  -e NODE_ENV=production \
  my-node-app:1.0

# Simulate issues and debug:

# 1. Check if container is running
docker ps -a

# 2. Check logs for errors
docker logs broken-app

# 3. Check resource usage
docker stats broken-app --no-stream

# 4. Test connectivity
curl http://localhost:9999 || echo "Connection failed"

# 5. Enter container to debug
docker exec -it broken-app /bin/sh
# Inside container: test network, check processes, etc.
```

## Part 5: Volume and Network Management

### Step 1: Volume Mounting

```bash
# Create a data directory
mkdir -p data

# Run container with volume mount
docker run -d -p 3003:3000 \
  --name node-app-volume \
  -v $(pwd)/data:/app/data \
  my-node-app:1.0

# Create files in mounted volume
echo "Hello from host!" > data/message.txt

# Verify inside container
docker exec node-app-volume cat /app/data/message.txt
```

### Step 2: Named Volumes

```bash
# Create named volume
docker volume create app-data

# Run container with named volume
docker run -d -p 3004:3000 \
  --name node-app-named-volume \
  -v app-data:/app/data \
  my-node-app:1.0

# List volumes
docker volume ls

# Inspect volume
docker volume inspect app-data
```

### Step 3: Custom Networks

```bash
# Create custom network
docker network create my-app-network

# Run containers on custom network
docker run -d --name db-container \
  --network my-app-network \
  -e POSTGRES_PASSWORD=secret \
  postgres:13-alpine

docker run -d -p 3005:3000 \
  --name app-with-db \
  --network my-app-network \
  my-node-app:1.0

# Test network connectivity
docker exec app-with-db ping db-container
```

## Part 6: Environment-Specific Builds

### Step 1: Development Environment

```bash
# Build development image
docker build -f node-app/Dockerfile.dev -t my-node-app:dev node-app/

# Run with development setup
docker run -d -p 3006:3000 \
  --name node-dev \
  -v $(pwd)/node-app:/app \
  -v /app/node_modules \
  my-node-app:dev

# Test hot reload by editing node-app/server.js
```

### Step 2: Production Environment

```bash
# Build production image with build args
docker build \
  --build-arg NODE_ENV=production \
  --build-arg APP_VERSION=1.0.0 \
  -t my-node-app:prod \
  node-app/

# Run production container
docker run -d -p 3007:3000 \
  --name node-prod \
  --read-only \
  --tmpfs /tmp \
  --restart unless-stopped \
  my-node-app:prod
```

## 🎯 Lab Challenges

### Challenge 1: Multi-Container Application

Create a complete web stack with:
- Frontend (nginx serving static files)
- Backend API (your Node.js app)
- Database (PostgreSQL)

**Requirements:**
- All containers on custom network
- Persistent database storage
- Environment-specific configuration

### Challenge 2: Optimization Competition

Optimize your Docker images for:
1. **Size**: Make the smallest possible image
2. **Security**: Implement all security best practices
3. **Performance**: Fastest build time

**Hint:** Use `.dockerignore`, multi-stage builds, alpine images, and minimal base images.

### Challenge 3: Debugging Scenario

You're given a broken application. Debug and fix:
```bash
# This container won't start properly
docker run -d --name mystery-app \
  -p 8080:3000 \
  -e DATABASE_URL=invalid \
  my-node-app:1.0
```

Find and fix the issues using Docker debugging tools.

## 📝 Lab Report

Complete this report to demonstrate your understanding:

### Part 1: Build Analysis

**1. Compare image sizes:**
```bash
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

| Image | Tag | Size | Notes |
|-------|-----|------|-------|
| my-node-app | 1.0 | | |
| my-python-app | 1.0 | | |
| multi-stage-app | 1.0 | | |

**2. Layer analysis:**
```bash
docker history my-node-app:1.0
```

Which layers are largest? Why?
```
_________________________________________________
_________________________________________________
```

### Part 2: Security Assessment

**1. What security practices did you implement?**
- [ ] Non-root user
- [ ] Specific base image tags
- [ ] Minimal attack surface
- [ ] Read-only filesystem
- [ ] Health checks

**2. How would you scan for vulnerabilities?**
```
_________________________________________________
```

### Part 3: Performance Optimization

**1. Build time comparison:**

| Build Type | Time | Optimization Used |
|------------|------|-------------------|
| Initial build | | |
| Rebuild (no changes) | | |
| Rebuild (code change) | | |

**2. What caching strategies did you observe?**
```
_________________________________________________
_________________________________________________
```

### Part 4: Troubleshooting Experience

**1. What issues did you encounter and how did you solve them?**

| Issue | Solution | Tools Used |
|-------|----------|------------|
| | | |
| | | |
| | | |

**2. Most useful debugging commands:**
```
_________________________________________________
_________________________________________________
```

## ✅ Lab Completion Checklist

- [ ] Built Node.js application with Dockerfile
- [ ] Built Python Flask application with Dockerfile
- [ ] Created multi-stage build
- [ ] Implemented security best practices
- [ ] Used volumes for data persistence
- [ ] Created custom networks
- [ ] Debugged container issues
- [ ] Optimized images for size and performance
- [ ] Completed all challenges
- [ ] Filled out lab report

## 🎉 Congratulations!

You've completed the Docker Basics lab! You now have hands-on experience with:
- ✅ Building production-ready Dockerfiles
- ✅ Container lifecycle management
- ✅ Multi-stage builds
- ✅ Security implementation
- ✅ Volume and network management
- ✅ Debugging and troubleshooting

## 🧹 Cleanup

When you're done, clean up your environment:

```bash
# Stop all containers
docker stop $(docker ps -aq)

# Remove all containers
docker rm $(docker ps -aq)

# Remove custom networks
docker network rm my-app-network

# Remove volumes (be careful!)
docker volume rm app-data

# Clean up images (optional)
docker image prune

# Or remove specific images
docker rmi my-node-app:1.0 my-python-app:1.0 multi-stage-app:1.0
```

## 🚀 Next Steps

1. Complete the [Chapter Checkpoint](../checkpoint.md)
2. Move on to [Chapter 02: Docker Images](../../02-docker-images/README.md)
3. Explore the [Chapter Project](../project/README.md) for advanced practice

---

**Need Help?** Check the [troubleshooting guide](../../../resources/troubleshooting.md) or ask in the community forum! 