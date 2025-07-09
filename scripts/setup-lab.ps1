# Setup Lab Environment Script for Windows
# This script sets up the lab environment for Docker and Kubernetes learning

Write-Host "🚀 Setting up Docker & Kubernetes Learning Lab Environment..." -ForegroundColor Cyan

# Check if running from the correct directory
if (-not (Test-Path "docker") -or -not (Test-Path "kubernetes")) {
    Write-Host "❌ Error: Please run this script from the root of the learn-docker repository" -ForegroundColor Red
    exit 1
}

# Create lab directories
Write-Host "📁 Creating lab directories..." -ForegroundColor Yellow

# Docker labs
$dockerLabs = @(
    "labs\docker\images",
    "labs\docker\containers",
    "labs\docker\networking",
    "labs\docker\storage",
    "labs\docker\compose",
    "labs\docker\security",
    "labs\docker\projects\microservices",
    "labs\docker\projects\ci-cd",
    "labs\docker\projects\monitoring"
)

foreach ($dir in $dockerLabs) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# Kubernetes labs
$k8sLabs = @(
    "labs\kubernetes\pods",
    "labs\kubernetes\services",
    "labs\kubernetes\deployments",
    "labs\kubernetes\storage",
    "labs\kubernetes\security",
    "labs\kubernetes\networking",
    "labs\kubernetes\projects\microservices",
    "labs\kubernetes\projects\monitoring",
    "labs\kubernetes\projects\cicd",
    "labs\kubernetes\projects\production"
)

foreach ($dir in $k8sLabs) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# Exercise directories
Write-Host "📝 Creating exercise directories..." -ForegroundColor Yellow

# Docker exercises
1..10 | ForEach-Object {
    $chapter = "{0:D2}" -f $_
    New-Item -ItemType Directory -Path "exercises\docker\chapter-$chapter" -Force | Out-Null
}

# Kubernetes exercises
1..13 | ForEach-Object {
    $chapter = "{0:D2}" -f $_
    New-Item -ItemType Directory -Path "exercises\kubernetes\chapter-$chapter" -Force | Out-Null
}

# Create sample files
Write-Host "📄 Creating sample configuration files..." -ForegroundColor Yellow

# Docker sample files
$envExample = @"
# Example environment variables for Docker labs
POSTGRES_USER=myuser
POSTGRES_PASSWORD=mypassword
POSTGRES_DB=mydb
REDIS_PASSWORD=redispass
NODE_ENV=development
"@

$envExample | Out-File -FilePath "labs\docker\.env.example" -Encoding UTF8

# Create a sample docker-compose file
$dockerComposeExample = @"
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
      - POSTGRES_USER=`${POSTGRES_USER}
      - POSTGRES_PASSWORD=`${POSTGRES_PASSWORD}
      - POSTGRES_DB=`${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    command: redis-server --requirepass `${REDIS_PASSWORD}

volumes:
  postgres_data:
"@

$dockerComposeExample | Out-File -FilePath "labs\docker\docker-compose.example.yml" -Encoding UTF8

# Create resources directory structure
$resourceDirs = @(
    "resources\docker",
    "resources\kubernetes",
    "resources\tools",
    "resources\references"
)

foreach ($dir in $resourceDirs) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

Write-Host "`n✅ Lab setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📌 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Install Docker Desktop or Docker Engine"
Write-Host "   2. Install kubectl and minikube/kind for local Kubernetes"
Write-Host "   3. Start with docker\00-introduction\README.md"
Write-Host ""
Write-Host "Happy Learning! 🎉" -ForegroundColor Magenta 