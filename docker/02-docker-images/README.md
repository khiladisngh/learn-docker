# 🐳 Chapter 02: Docker Images - Mastering Image Creation & Optimization

Welcome to advanced Docker image management! In this chapter, you'll master image optimization, security scanning, registry management, and advanced Dockerfile techniques used in production environments.

## 🎯 Learning Objectives

By the end of this chapter, you will:
- ✅ Optimize Docker images for size, security, and performance
- ✅ Master advanced Dockerfile techniques and patterns
- ✅ Work with Docker registries (public and private)
- ✅ Implement image security scanning and best practices
- ✅ Create custom base images
- ✅ Understand image layers and filesystem mechanics

## 📦 Understanding Docker Images Deep Dive

### Image Architecture & Layers

Docker images are built using a **Union File System** with multiple read-only layers:

```
┌─────────────────────────────────────────┐
│           Container Layer               │ ← Read/Write
├─────────────────────────────────────────┤
│     Application Layer (COPY app/)       │ ← Read-Only
├─────────────────────────────────────────┤
│     Dependencies Layer (RUN npm...)     │ ← Read-Only
├─────────────────────────────────────────┤
│     Base Image Layer (FROM node:16)     │ ← Read-Only
└─────────────────────────────────────────┘
```

### Layer Sharing & Storage Efficiency

```bash
# Example: Multiple Node.js apps sharing base layers
App A Image: [Base Node.js] + [App A Dependencies] + [App A Code]
App B Image: [Base Node.js] + [App B Dependencies] + [App B Code]
             └─ Shared ─┘

# Storage: Base layer stored once, shared by both images
```

### Image Manifests & Metadata

```bash
# Inspect image layers and metadata
docker inspect nginx:alpine

# View layer history
docker history nginx:alpine

# Analyze layer sizes
docker history nginx:alpine --format "table {{.ID}}\t{{.Size}}\t{{.CreatedBy}}"
```

## 🚀 Advanced Dockerfile Techniques

### 1. Multi-Stage Builds for Production

**Problem:** Development images are often bloated with build tools and dependencies.

**Solution:** Multi-stage builds create optimized production images.

```dockerfile
# ❌ Single-stage build (bloated)
FROM node:16
WORKDIR /app
COPY package*.json ./
RUN npm install  # Includes dev dependencies
COPY . .
RUN npm run build
CMD ["npm", "start"]
# Result: ~1GB image with dev dependencies

# ✅ Multi-stage build (optimized)
# Build stage
FROM node:16-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# Production stage
FROM node:16-alpine AS production
WORKDIR /app
# Copy only production dependencies
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
# Copy built application
COPY --from=builder /app/dist ./dist
# Create non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001
USER nextjs
EXPOSE 3000
CMD ["node", "dist/server.js"]
# Result: ~150MB optimized image
```

### 2. Build Arguments & Environment Variables

```dockerfile
# Build-time variables (ARG)
ARG NODE_VERSION=16
ARG APP_VERSION=1.0.0
ARG BUILD_DATE
ARG GIT_COMMIT

FROM node:${NODE_VERSION}-alpine

# Runtime environment variables (ENV)
ENV NODE_ENV=production \
    APP_VERSION=${APP_VERSION} \
    BUILD_DATE=${BUILD_DATE} \
    GIT_COMMIT=${GIT_COMMIT}

# Labels for metadata
LABEL version="${APP_VERSION}" \
      description="My awesome application" \
      maintainer="your-email@example.com" \
      build-date="${BUILD_DATE}" \
      git-commit="${GIT_COMMIT}"

WORKDIR /app
COPY . .
RUN npm ci --only=production

CMD ["npm", "start"]
```

**Build with arguments:**
```bash
docker build \
  --build-arg APP_VERSION=2.1.0 \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg GIT_COMMIT=$(git rev-parse HEAD) \
  -t myapp:2.1.0 .
```

### 3. Advanced COPY Patterns

```dockerfile
# Copy specific files with patterns
COPY package*.json ./
COPY tsconfig*.json ./
COPY ["file with spaces.txt", "./dest/"]

# Copy with ownership (avoid chown later)
COPY --chown=node:node . /app

# Copy from URLs (limited use cases)
ADD https://github.com/user/repo/archive/main.tar.gz /tmp/

# Copy and extract archives
ADD app.tar.gz /app/

# Multi-source copy
COPY src/ config/ /app/
```

### 4. Advanced RUN Optimizations

```dockerfile
# ❌ Multiple RUN commands (multiple layers)
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y git
RUN apt-get clean

# ✅ Combined RUN command (single layer)
RUN apt-get update && \
    apt-get install -y \
        curl \
        git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ✅ Using heredocs (Docker 20.10+)
RUN <<EOF
apt-get update
apt-get install -y curl git
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF

# ✅ Multi-line with proper escaping
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        curl \
        git \
        ca-certificates; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*
```

## 🔧 Image Optimization Strategies

### 1. Choosing the Right Base Image

```dockerfile
# Size comparison for Node.js apps

# Largest: Full Ubuntu with Node.js
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y nodejs npm
# Size: ~400MB

# Medium: Official Node.js
FROM node:16
# Size: ~350MB

# Smaller: Alpine variant
FROM node:16-alpine
# Size: ~110MB

# Smallest: Distroless (Google)
FROM gcr.io/distroless/nodejs:16
# Size: ~50MB (production only)

# Ultra-minimal: Scratch (for compiled binaries)
FROM scratch
COPY app .
# Size: Just your binary
```

### 2. Layer Optimization Techniques

```dockerfile
# ✅ Optimized Dockerfile example
FROM python:3.11-alpine AS base

# Install system dependencies in one layer
RUN apk update && apk add --no-cache \
    gcc \
    musl-dev \
    postgresql-dev && \
    pip install --upgrade pip

# Create app user
RUN adduser -D -s /bin/sh appuser

FROM base AS dependencies
WORKDIR /app
# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM dependencies AS application
# Copy application code (changes most frequently)
COPY --chown=appuser:appuser . .
USER appuser

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["python", "app.py"]
```

### 3. Using .dockerignore Effectively

**`.dockerignore`:**
```gitignore
# Version control
.git
.gitignore

# Dependencies (will be installed in container)
node_modules
__pycache__
*.pyc

# Development files
.env.local
.env.development
*.log
coverage/
.pytest_cache

# IDE files
.vscode
.idea
*.swp
*.swo

# Documentation
README.md
docs/
*.md

# CI/CD
.github
.gitlab-ci.yml
Jenkinsfile

# Docker files
Dockerfile*
docker-compose*.yml

# OS files
.DS_Store
Thumbs.db

# Build artifacts
dist/
build/
target/

# Test files
tests/
spec/
**/*test*
**/*spec*
```

### 4. Cache Optimization Patterns

```dockerfile
# ✅ Package manager optimization
FROM node:16-alpine

WORKDIR /app

# Copy package files first (changes rarely)
COPY package*.json ./
COPY yarn.lock ./

# Install dependencies (cached layer)
RUN npm ci --only=production && npm cache clean --force

# Copy source code last (changes frequently)
COPY . .

RUN npm run build

# ✅ Multi-stage caching
FROM golang:1.19-alpine AS builder
WORKDIR /app

# Copy go mod files first
COPY go.mod go.sum ./
RUN go mod download  # Cached layer

# Copy source and build
COPY . .
RUN go build -o app .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
COPY --from=builder /app/app .
CMD ["./app"]
```

## 🚀 Chapter Checkpoint

### Questions

1. **What are Docker images composed of?**
   - Layers, each providing a filesystem change

2. **How does multi-stage build improve image size and performance?**
   - By separating build and production stages, we include only necessary files

3. **What are some best practices for optimizing Dockerfiles?**
   - Using specific base images, minimizing layers, caching, and limiting scope of COPY


### Tasks

- [ ] Review and refactor a given Dockerfile for an existing project
- [ ] Scan a Docker image for vulnerabilities using a scanning tool of your choice

---

## 🏪 Working with Docker Registries

### 1. Docker Hub

```bash
# Login to Docker Hub
docker login

# Tag and push image
docker tag myapp:latest username/myapp:latest
docker push username/myapp:latest

# Pull image
docker pull username/myapp:latest

# Search for images
docker search nginx

# View image information
docker image inspect username/myapp:latest
```

### 2. Private Registry Setup

**Deploy a private registry:**
```bash
# Run private registry
docker run -d \
  -p 5000:5000 \
  --restart=always \
  --name registry \
  -v registry-data:/var/lib/registry \
  registry:2

# Push to private registry
docker tag myapp:latest localhost:5000/myapp:latest
docker push localhost:5000/myapp:latest

# Pull from private registry
docker pull localhost:5000/myapp:latest
```

**Secure private registry with TLS:**
```bash
# Generate certificates
mkdir -p certs
openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout certs/domain.key \
  -x509 -days 365 \
  -out certs/domain.crt

# Run secure registry
docker run -d \
  -p 5000:5000 \
  --restart=always \
  --name secure-registry \
  -v $(pwd)/certs:/certs \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_PRIVATE_KEY=/certs/domain.key \
  registry:2
```

### 3. Authentication & Authorization

```bash
# Create htpasswd file for basic auth
mkdir auth
docker run --rm \
  --entrypoint htpasswd \
  httpd:2 -Bbn username password > auth/htpasswd

# Run registry with authentication
docker run -d \
  -p 5000:5000 \
  --restart=always \
  --name auth-registry \
  -v $(pwd)/auth:/auth \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  registry:2

# Login to authenticated registry
docker login localhost:5000
```

### 4. Cloud Registry Examples

**AWS ECR:**
```bash
# Login to ECR
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-west-2.amazonaws.com

# Tag and push
docker tag myapp:latest \
  123456789012.dkr.ecr.us-west-2.amazonaws.com/myapp:latest
docker push 123456789012.dkr.ecr.us-west-2.amazonaws.com/myapp:latest
```

**Google Container Registry:**
```bash
# Configure Docker to use gcloud as a credential helper
gcloud auth configure-docker

# Tag and push
docker tag myapp:latest gcr.io/project-id/myapp:latest
docker push gcr.io/project-id/myapp:latest
```

**Azure Container Registry:**
```bash
# Login to ACR
az acr login --name myregistry

# Tag and push
docker tag myapp:latest myregistry.azurecr.io/myapp:latest
docker push myregistry.azurecr.io/myapp:latest
```

## 🔒 Image Security & Scanning

### 1. Security Best Practices

```dockerfile
# ✅ Security-hardened Dockerfile
FROM node:16-alpine AS base

# Update system packages
RUN apk update && apk upgrade && apk add --no-cache dumb-init

# Create non-root user with specific UID/GID
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs

FROM base AS dependencies
WORKDIR /app

# Set proper ownership before copying
COPY --chown=nextjs:nodejs package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force && \
    # Remove npm to reduce attack surface
    npm uninstall -g npm

FROM dependencies AS application

# Copy application with proper ownership
COPY --chown=nextjs:nodejs . .

# Switch to non-root user
USER nextjs

# Use dumb-init as PID 1
ENTRYPOINT ["dumb-init", "--"]

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js

# Expose only necessary port
EXPOSE 3000

CMD ["node", "server.js"]
```

### 2. Vulnerability Scanning

**Docker Scout (Built-in):**
```bash
# Enable Docker Scout
docker scout version

# Quick vulnerability overview
docker scout quickview myapp:latest

# Detailed vulnerability report
docker scout cves myapp:latest

# Compare images
docker scout compare myapp:latest --to myapp:previous

# Recommendations for fixes
docker scout recommendations myapp:latest
```

**Trivy Scanner:**
```bash
# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Scan image for vulnerabilities
trivy image myapp:latest

# Scan for specific severity
trivy image --severity HIGH,CRITICAL myapp:latest

# Generate report
trivy image --format json --output report.json myapp:latest
```

**Snyk Integration:**
```bash
# Install Snyk CLI
npm install -g snyk

# Authenticate
snyk auth

# Test Docker image
snyk test --docker myapp:latest

# Monitor image for new vulnerabilities
snyk monitor --docker myapp:latest
```

### 3. Image Signing & Verification

**Docker Content Trust:**
```bash
# Enable content trust
export DOCKER_CONTENT_TRUST=1

# Generate delegation keys
docker trust key generate mykey

# Add signer to repository
docker trust signer add --key mykey.pub myuser myrepo

# Sign and push image
docker trust sign myrepo:latest

# Verify signed image
docker trust inspect --pretty myrepo:latest
```

**Cosign (CNCF):**
```bash
# Install Cosign
go install github.com/sigstore/cosign/cmd/cosign@latest

# Generate key pair
cosign generate-key-pair

# Sign image
cosign sign --key cosign.key myapp:latest

# Verify signature
cosign verify --key cosign.pub myapp:latest
```

## 🎨 Custom Base Images

### 1. Creating Custom Base Images

```dockerfile
# Example: Custom Python base with security tools
FROM python:3.11-alpine AS base

# Install security and monitoring tools
RUN apk update && apk add --no-cache \
    curl \
    ca-certificates \
    dumb-init \
    tini \
    # Security tools
    openssl \
    # Monitoring tools
    htop \
    && rm -rf /var/cache/apk/*

# Configure Python environment
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Create application user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Install common Python packages
RUN pip install --no-cache-dir \
    gunicorn \
    prometheus-client \
    psutil

# Set up working directory
WORKDIR /app
RUN chown appuser:appgroup /app

# Switch to non-root user
USER appuser

# Health check script
COPY --chown=appuser:appgroup healthcheck.py /usr/local/bin/
RUN chmod +x /usr/local/bin/healthcheck.py

# Default health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python /usr/local/bin/healthcheck.py

# Default command (can be overridden)
CMD ["python", "app.py"]
```

### 2. Distroless Images

```dockerfile
# Google Distroless example
FROM node:16-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# Distroless production image
FROM gcr.io/distroless/nodejs:16
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
EXPOSE 3000
CMD ["dist/server.js"]
```

### 3. Scratch Images for Go

```dockerfile
# Multi-stage build for Go with scratch
FROM golang:1.19-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o app .

# Scratch image (minimal)
FROM scratch
COPY --from=builder /app/app .
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
EXPOSE 8080
USER 1001
CMD ["./app"]
```

## 📊 Image Management & Maintenance

### 1. Image Lifecycle Management

```bash
# Tagging strategy
docker tag myapp:latest myapp:v1.2.3
docker tag myapp:latest myapp:stable

# Automated tagging in CI/CD
docker tag myapp:${GIT_COMMIT} myapp:latest
docker tag myapp:${GIT_COMMIT} myapp:${VERSION}

# Cleanup old images
docker image prune -f

# Remove specific images
docker rmi $(docker images -f "dangling=true" -q)

# Clean up by age
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}" | \
  grep "months ago" | awk '{print $1":"$2}' | xargs docker rmi
```

### 2. Image Size Analysis

```bash
# Analyze image layers
docker history --no-trunc myapp:latest

# Using dive for interactive analysis
dive myapp:latest

# Using docker-slim for optimization
docker-slim build --target myapp:latest --tag myapp:slim
```

### 3. Multi-Architecture Images

```bash
# Create multi-architecture manifest
docker buildx create --name multiarch --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t myapp:latest --push .

# Inspect multi-arch manifest
docker buildx imagetools inspect myapp:latest
```

## ✅ Real-World Examples

### 1. Optimized Node.js Production Image

```dockerfile
# Production-ready Node.js with all optimizations
FROM node:18-alpine AS base

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create app directory and user
RUN mkdir -p /home/node/app && chown node:node /home/node/app
WORKDIR /home/node/app
USER node

# Dependencies stage
FROM base AS dependencies
COPY --chown=node:node package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Build stage
FROM base AS build
COPY --chown=node:node package*.json ./
RUN npm ci
COPY --chown=node:node . .
RUN npm run build

# Production stage
FROM base AS production
COPY --from=dependencies /home/node/app/node_modules ./node_modules
COPY --from=build /home/node/app/dist ./dist
COPY --chown=node:node package*.json ./

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]
```

### 2. Python Flask with Security Focus

```dockerfile
FROM python:3.11-alpine AS base

# Install security updates and tools
RUN apk update && apk upgrade && \
    apk add --no-cache \
        dumb-init \
        curl \
        ca-certificates && \
    rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

FROM base AS dependencies
WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

FROM dependencies AS application
# Copy application
COPY --chown=appuser:appgroup . .

# Switch to non-root user
USER appuser

# Security: Run as non-root, use dumb-init
ENTRYPOINT ["dumb-init", "--"]

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5000/health || exit 1

CMD ["python", "app.py"]
```

## 🐍 Advanced Python Examples

### 1. Python Machine Learning API

**ml_app.py:**
```python
from flask import Flask, request, jsonify
import numpy as np
import pickle
import os
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.datasets import make_classification
import joblib

app = Flask(__name__)

class MLModel:
    def __init__(self):
        self.model = None
        self.model_path = '/app/models/classifier.pkl'
        self.load_or_train_model()
    
    def load_or_train_model(self):
        """Load existing model or train a new one"""
        if os.path.exists(self.model_path):
            self.model = joblib.load(self.model_path)
            print("📚 Model loaded from disk")
        else:
            self.train_model()
    
    def train_model(self):
        """Train a sample model"""
        print("🎯 Training new model...")
        
        # Generate sample data
        X, y = make_classification(
            n_samples=1000, 
            n_features=20, 
            n_informative=10, 
            n_redundant=10, 
            random_state=42
        )
        
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )
        
        # Train model
        self.model = RandomForestClassifier(n_estimators=100, random_state=42)
        self.model.fit(X_train, y_train)
        
        # Save model
        os.makedirs(os.path.dirname(self.model_path), exist_ok=True)
        joblib.dump(self.model, self.model_path)
        
        # Calculate accuracy
        accuracy = self.model.score(X_test, y_test)
        print(f"✅ Model trained with accuracy: {accuracy:.2f}")
    
    def predict(self, features):
        """Make prediction"""
        if self.model is None:
            raise ValueError("Model not loaded")
        
        prediction = self.model.predict([features])
        probability = self.model.predict_proba([features])[0]
        
        return {
            'prediction': int(prediction[0]),
            'probability': {
                'class_0': float(probability[0]),
                'class_1': float(probability[1])
            }
        }

# Initialize ML model
ml_model = MLModel()

@app.route('/')
def index():
    return jsonify({
        'message': 'Python ML API',
        'version': '1.0.0',
        'endpoints': {
            'predict': '/predict (POST)',
            'retrain': '/retrain (POST)',
            'health': '/health (GET)'
        }
    })

@app.route('/predict', methods=['POST'])
def predict():
    """Make prediction endpoint"""
    try:
        data = request.get_json()
        if not data or 'features' not in data:
            return jsonify({'error': 'Features array required'}), 400
        
        features = data['features']
        if len(features) != 20:
            return jsonify({'error': 'Exactly 20 features required'}), 400
        
        result = ml_model.predict(features)
        return jsonify(result)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/retrain', methods=['POST'])
def retrain():
    """Retrain model endpoint"""
    try:
        ml_model.train_model()
        return jsonify({'message': 'Model retrained successfully'})
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health():
    """Health check"""
    model_status = ml_model.model is not None
    return jsonify({
        'status': 'healthy' if model_status else 'unhealthy',
        'model_loaded': model_status
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
```

**ML Dockerfile:**
```dockerfile
# Multi-stage build for ML application
FROM python:3.11-slim AS base

# Install system dependencies for ML
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    gfortran \
    libopenblas-dev \
    liblapack-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set Python environment
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

FROM base AS dependencies

WORKDIR /app

# Copy requirements for ML
COPY requirements-ml.txt .

# Install ML dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements-ml.txt

FROM dependencies AS application

# Create directories
RUN mkdir -p /app/models

# Copy application
COPY ml_app.py .

# Create non-root user
RUN useradd -m -u 1001 mluser && \
    chown -R mluser:mluser /app

USER mluser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

CMD ["python", "ml_app.py"]
```

**requirements-ml.txt:**
```txt
Flask==2.3.2
scikit-learn==1.3.0
numpy==1.24.3
pandas==2.0.3
joblib==1.3.2
gunicorn==20.1.0
```

### 2. Python Async Web Application

**async_app.py:**
```python
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
import asyncio
import aioredis
import asyncpg
import os
from datetime import datetime
from typing import Optional, List
import uvicorn

app = FastAPI(
    title="Async Python API",
    description="High-performance async API with FastAPI",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379')
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://user:pass@localhost/db')

# Global connections
redis_pool = None
db_pool = None

@app.on_event("startup")
async def startup_event():
    """Initialize connections on startup"""
    global redis_pool, db_pool
    
    try:
        # Initialize Redis connection pool
        redis_pool = aioredis.from_url(REDIS_URL)
        await redis_pool.ping()
        print("✅ Redis connected")
    except Exception as e:
        print(f"❌ Redis connection failed: {e}")
        redis_pool = None
    
    try:
        # Initialize PostgreSQL connection pool
        db_pool = await asyncpg.create_pool(DATABASE_URL)
        print("✅ Database connected")
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        db_pool = None

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup connections on shutdown"""
    if redis_pool:
        await redis_pool.close()
    if db_pool:
        await db_pool.close()

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "High-performance Async Python API",
        "timestamp": datetime.now().isoformat(),
        "endpoints": ["/users", "/cache", "/stats", "/health"]
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    health_status = {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "services": {}
    }
    
    # Check Redis
    if redis_pool:
        try:
            await redis_pool.ping()
            health_status["services"]["redis"] = "healthy"
        except:
            health_status["services"]["redis"] = "unhealthy"
    else:
        health_status["services"]["redis"] = "unavailable"
    
    # Check Database
    if db_pool:
        try:
            async with db_pool.acquire() as conn:
                await conn.fetchval("SELECT 1")
            health_status["services"]["database"] = "healthy"
        except:
            health_status["services"]["database"] = "unhealthy"
    else:
        health_status["services"]["database"] = "unavailable"
    
    overall_healthy = all(
        status in ["healthy", "unavailable"] 
        for status in health_status["services"].values()
    )
    
    if not overall_healthy:
        health_status["status"] = "degraded"
    
    return health_status

@app.get("/users")
async def get_users():
    """Get users from database"""
    if not db_pool:
        raise HTTPException(status_code=503, detail="Database unavailable")
    
    try:
        async with db_pool.acquire() as conn:
            rows = await conn.fetch("SELECT id, name, email FROM users LIMIT 10")
            users = [dict(row) for row in rows]
            return {"users": users, "count": len(users)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/users")
async def create_user(user_data: dict):
    """Create a new user"""
    if not db_pool:
        raise HTTPException(status_code=503, detail="Database unavailable")
    
    name = user_data.get("name")
    email = user_data.get("email")
    
    if not name or not email:
        raise HTTPException(status_code=400, detail="Name and email required")
    
    try:
        async with db_pool.acquire() as conn:
            user_id = await conn.fetchval(
                "INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id",
                name, email
            )
            return {"id": user_id, "name": name, "email": email}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/cache/{key}")
async def get_cache(key: str):
    """Get value from Redis cache"""
    if not redis_pool:
        raise HTTPException(status_code=503, detail="Redis unavailable")
    
    try:
        value = await redis_pool.get(key)
        if value:
            return {"key": key, "value": value.decode()}
        else:
            raise HTTPException(status_code=404, detail="Key not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/cache/{key}")
async def set_cache(key: str, data: dict):
    """Set value in Redis cache"""
    if not redis_pool:
        raise HTTPException(status_code=503, detail="Redis unavailable")
    
    value = data.get("value")
    if not value:
        raise HTTPException(status_code=400, detail="Value required")
    
    try:
        await redis_pool.setex(key, 3600, value)  # 1 hour expiry
        return {"key": key, "value": value, "expires_in": 3600}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

async def background_task(name: str):
    """Example background task"""
    await asyncio.sleep(5)
    print(f"Background task {name} completed")

@app.post("/tasks")
async def create_task(background_tasks: BackgroundTasks, task_data: dict):
    """Create background task"""
    task_name = task_data.get("name", "unnamed")
    background_tasks.add_task(background_task, task_name)
    return {"message": f"Task {task_name} started"}

if __name__ == "__main__":
    uvicorn.run(
        "async_app:app",
        host="0.0.0.0",
        port=8000,
        workers=4,
        loop="uvloop"
    )
```

**AsyncAPI Dockerfile:**
```dockerfile
FROM python:3.11-slim AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

FROM base AS dependencies

WORKDIR /app

# Copy and install requirements
COPY requirements-async.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements-async.txt

FROM dependencies AS application

# Copy application
COPY async_app.py .

# Create non-root user
RUN useradd -m -u 1001 asyncuser && \
    chown -R asyncuser:asyncuser /app

USER asyncuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "async_app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

**requirements-async.txt:**
```txt
fastapi==0.103.0
uvicorn[standard]==0.23.2
aioredis==5.0.0
asyncpg==0.28.0
uvloop==0.17.0
httptools==0.6.0
```

## 🚀 What's Next?

In [Chapter 03: Docker Containers](../03-docker-containers/README.md), you'll learn:
- Advanced container runtime configurations
- Container resource management and limits
- Inter-container communication
- Container orchestration basics
- Production container patterns

## 📚 Key Takeaways

✅ **Image optimization** dramatically reduces deployment time and resource usage
✅ **Multi-stage builds** are essential for production-ready images  
✅ **Security scanning** should be integrated into CI/CD pipelines
✅ **Registry management** is crucial for team collaboration
✅ **Layer caching** optimization speeds up builds significantly
✅ **Custom base images** standardize your organization's container foundation

## 📝 Practice Checklist

Before moving on, ensure you can:
- [ ] Create optimized multi-stage Dockerfiles
- [ ] Implement comprehensive security practices
- [ ] Set up and use private Docker registries
- [ ] Scan images for vulnerabilities
- [ ] Build custom base images
- [ ] Optimize image layers and caching

---

**🎉 Congratulations!** You now have advanced Docker image skills. Complete the [lab exercise](lab/README.md) to practice these concepts, then validate your knowledge with the [checkpoint](checkpoint.md)!

---

<div align="center">

**[⬅️ Previous: Docker Basics](../01-docker-basics/README.md)** | **[Next: Docker Containers ➡️](../03-docker-containers/README.md)**

</div> 