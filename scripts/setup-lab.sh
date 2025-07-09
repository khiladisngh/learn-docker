#!/bin/bash

# Setup Lab Environment Script
# This script sets up the lab environment for Docker and Kubernetes learning

echo "🚀 Setting up Docker & Kubernetes Learning Lab Environment..."

# Check if running from the correct directory
if [ ! -d "docker" ] || [ ! -d "kubernetes" ]; then
    echo "❌ Error: Please run this script from the root of the learn-docker repository"
    exit 1
fi

# Create lab directories
echo "📁 Creating lab directories..."

# Docker labs
mkdir -p labs/docker/{images,containers,networking,storage,compose,security}
mkdir -p labs/docker/projects/{microservices,ci-cd,monitoring}

# Kubernetes labs
mkdir -p labs/kubernetes/{pods,services,deployments,storage,security,networking}
mkdir -p labs/kubernetes/projects/{microservices,monitoring,cicd,production}

# Exercise directories
echo "📝 Creating exercise directories..."

# Docker exercises
for i in {1..10}; do
    mkdir -p exercises/docker/chapter-$(printf "%02d" $i)
done

# Kubernetes exercises
for i in {1..13}; do
    mkdir -p exercises/kubernetes/chapter-$(printf "%02d" $i)
done

# Create sample files
echo "📄 Creating sample configuration files..."

# Docker sample files
cat > labs/docker/.env.example << 'EOF'
# Example environment variables for Docker labs
POSTGRES_USER=myuser
POSTGRES_PASSWORD=mypassword
POSTGRES_DB=mydb
REDIS_PASSWORD=redispass
NODE_ENV=development
EOF

# Create a sample docker-compose file
cat > labs/docker/docker-compose.example.yml << 'EOF'
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
    volumes:
      - ./app:/usr/src/app
    depends_on:
      - db
      - redis

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASSWORD}

volumes:
  postgres_data:
EOF

# Create resources directory structure
mkdir -p resources/{docker,kubernetes,tools,references}

echo "✅ Lab setup complete!"
echo ""
echo "📌 Next steps:"
echo "   1. Install Docker Desktop or Docker Engine"
echo "   2. Install kubectl and minikube/kind for local Kubernetes"
echo "   3. Start with docker/00-introduction/README.md"
echo ""
echo "Happy Learning! 🎉" 