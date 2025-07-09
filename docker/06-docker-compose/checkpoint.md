# 🎯 Chapter 06 Checkpoint: Docker Compose Mastery

## 📝 Knowledge Assessment

**Total Points: 100**  
**Passing Score: 75**  
**Time Limit: 45 minutes**

---

### Section A: Docker Compose Fundamentals (25 points)

#### Question 1 (5 points)
**What are the main top-level sections in a Docker Compose file?**

a) services, volumes, networks, secrets  
b) containers, images, ports, environment  
c) applications, databases, networks, configs  
d) services, networks, volumes, configs, secrets  

<details>
<summary>💡 Click to reveal answer</summary>

**Answer: d) services, networks, volumes, configs, secrets**

**Explanation:** Docker Compose files have five main top-level sections:
- `services`: Define application containers
- `networks`: Custom network configurations
- `volumes`: Named volume definitions
- `configs`: Non-sensitive configuration management
- `secrets`: Secure sensitive data management
</details>

#### Question 2 (10 points)
**Explain the difference between these Docker Compose networking approaches:**

```yaml
# Approach A
services:
  web:
    depends_on:
      - db
    links:
      - db

# Approach B  
services:
  web:
    depends_on:
      db:
        condition: service_healthy
    networks:
      - backend
```

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**Approach A (Legacy/Deprecated):**
- Uses `links` which is deprecated since Docker Compose v2
- Only provides startup ordering with `depends_on`
- Creates implicit network connections
- Less control over networking

**Approach B (Modern/Recommended):**
- Uses explicit `networks` for better isolation
- `depends_on` with `condition` waits for health checks
- More granular network control
- Better for production environments
- Supports service health validation

**Key Differences:**
- Modern approach provides health-based dependencies
- Explicit networking is more secure and manageable
- Better support for scaling and load balancing
</details>

#### Question 3 (10 points)
**Write a docker-compose.yml service definition that includes:**
- Multi-stage build with build arguments
- Resource limits (CPU: 0.5, Memory: 512M)
- Health check every 30 seconds
- Secrets management
- Proper restart policy

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

```yaml
version: '3.8'

services:
  api:
    build:
      context: ./api
      target: production
      args:
        - NODE_ENV=production
        - API_VERSION=1.0.0
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    secrets:
      - db_password
      - api_key
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password
      - API_KEY_FILE=/run/secrets/api_key
    restart: unless-stopped

secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_key:
    external: true
    name: production_api_key
```
</details>

---

### Section B: Service Orchestration & Dependencies (25 points)

#### Question 4 (10 points)
**Design a Docker Compose configuration for a microservices architecture with:**
- API Gateway (Traefik)
- 2 backend services (user-service, order-service)
- Each service with its own database
- Shared message queue (RabbitMQ)
- Proper network isolation

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

```yaml
version: '3.8'

services:
  # API Gateway
  gateway:
    image: traefik:v2.9
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - gateway
    labels:
      - "traefik.enable=true"

  # User Service
  user-service:
    build: ./services/user
    networks:
      - gateway
      - user-network
    depends_on:
      - user-db
      - rabbitmq
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.user.rule=PathPrefix(`/api/users`)"
      - "traefik.http.services.user.loadbalancer.server.port=8080"

  user-db:
    image: postgres:13
    environment:
      - POSTGRES_DB=users
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD_FILE=/run/secrets/user_db_password
    secrets:
      - user_db_password
    volumes:
      - user_db_data:/var/lib/postgresql/data
    networks:
      - user-network

  # Order Service
  order-service:
    build: ./services/order
    networks:
      - gateway
      - order-network
      - messaging
    depends_on:
      - order-db
      - rabbitmq
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.order.rule=PathPrefix(`/api/orders`)"

  order-db:
    image: postgres:13
    environment:
      - POSTGRES_DB=orders
      - POSTGRES_USER=order
      - POSTGRES_PASSWORD_FILE=/run/secrets/order_db_password
    secrets:
      - order_db_password
    volumes:
      - order_db_data:/var/lib/postgresql/data
    networks:
      - order-network

  # Message Queue
  rabbitmq:
    image: rabbitmq:3-management
    networks:
      - messaging
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq

networks:
  gateway:
    driver: bridge
  user-network:
    driver: bridge
    internal: true
  order-network:
    driver: bridge
    internal: true
  messaging:
    driver: bridge
    internal: true

volumes:
  user_db_data:
  order_db_data:
  rabbitmq_data:

secrets:
  user_db_password:
    file: ./secrets/user_db_password.txt
  order_db_password:
    file: ./secrets/order_db_password.txt
```
</details>

#### Question 5 (15 points)
**Explain the startup sequence and dependencies in this configuration:**

```yaml
services:
  web:
    depends_on:
      api:
        condition: service_healthy
      cache:
        condition: service_started
  
  api:
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s

  db:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
```

What happens when you run `docker-compose up`?

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**Startup Sequence:**

1. **Database (db) starts first**
   - No dependencies, starts immediately
   - Health check runs every 30s using `pg_isready`
   - Must become healthy before dependent services start

2. **API service starts after db is healthy**
   - Waits for `db` service to pass health checks
   - Once db is healthy, API starts
   - API's own health check begins (curl to /health endpoint)
   - Must become healthy before web service starts

3. **Cache service starts in parallel**
   - No health check dependency, just needs to be started
   - Can start as soon as compose begins (no blocking dependencies)

4. **Web service starts last**
   - Waits for `api` to become healthy (passes health checks)
   - Waits for `cache` to be started (not necessarily healthy)
   - Only starts when both conditions are met

**Key Points:**
- `condition: service_healthy` waits for health checks to pass
- `condition: service_started` only waits for container to start
- Services without dependencies can start immediately
- Health checks are crucial for proper dependency management
- This ensures the application stack starts in the correct order
</details>

---

### Section C: Scaling & Load Balancing (25 points)

#### Question 6 (10 points)
**What's the difference between these scaling approaches?**

```bash
# Approach A
docker-compose up -d --scale web=3

# Approach B
version: '3.8'
services:
  web:
    deploy:
      replicas: 3
```

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**Approach A (Runtime Scaling):**
- Manual scaling using CLI command
- Temporary scaling that doesn't persist in configuration
- Overrides any replica count in compose file
- Good for testing and temporary scaling
- Requires manual intervention

**Approach B (Declarative Scaling):**
- Scaling defined in compose file
- Persistent configuration that's version controlled
- Automatic scaling when running `docker-compose up`
- Better for production environments
- Part of infrastructure as code approach

**Best Practice:**
- Use Approach B for production (declarative)
- Use Approach A for testing and temporary scaling
- Combine both: define baseline in file, adjust temporarily with CLI
</details>

#### Question 7 (15 points)
**Design a load-balanced web application with:**
- HAProxy load balancer
- 3 web server instances
- Health checks for all instances
- Port range mapping for scaling
- Backend server template configuration

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  haproxy:
    image: haproxy:alpine
    ports:
      - "80:80"
      - "8404:8404"  # Stats
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
    depends_on:
      - web
    networks:
      - frontend
    restart: unless-stopped

  web:
    build: ./web
    ports:
      - "8080-8085:80"  # Port range for scaling
    deploy:
      replicas: 3
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - frontend
    restart: unless-stopped

networks:
  frontend:
    driver: bridge
```

**haproxy.cfg:**
```
global
    daemon
    maxconn 4096

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    option httpchk GET /health

frontend web_frontend
    bind *:80
    default_backend web_servers

backend web_servers
    balance roundrobin
    option httpchk GET /health
    server-template web 3 web:80 check

frontend stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 30s
```

**Key Features:**
- HAProxy automatically discovers 3 web instances
- Health checks ensure only healthy servers receive traffic
- Round-robin load balancing
- Statistics dashboard on port 8404
- Port range allows for easy scaling
</details>

---

### Section D: Environment Management & Production (25 points)

#### Question 8 (10 points)
**Explain the compose file inheritance and override pattern:**

```bash
# Base configuration
docker-compose.yml

# Development overrides  
docker-compose.override.yml

# Production deployment
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

How does this pattern work?

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**File Inheritance Pattern:**

1. **docker-compose.yml (Base)**
   - Contains common configuration for all environments
   - Service definitions, basic networks, volumes
   - Environment-agnostic settings

2. **docker-compose.override.yml (Development)**
   - Automatically loaded with base file
   - Development-specific overrides (port mappings, volumes for hot reload)
   - Debug settings, development databases

3. **docker-compose.prod.yml (Production)**
   - Production-specific overrides
   - Security settings, resource limits, secrets
   - External volumes, production databases

**How it works:**
- Base file provides foundation
- Override files modify/extend base configuration
- Later files override earlier settings for same properties
- Arrays/lists are merged, not replaced
- Explicit file specification: `-f file1.yml -f file2.yml`

**Benefits:**
- DRY principle (Don't Repeat Yourself)
- Environment-specific configurations
- Easy switching between environments
- Version control friendly
- Gradual configuration enhancement
</details>

#### Question 9 (15 points)
**Create environment-specific configurations for this scenario:**

**Requirements:**
- Development: Port exposure, volume mounting, debug mode
- Production: Secrets, resource limits, health checks, no port exposure

**Base service:**
```yaml
services:
  api:
    build: .
    environment:
      - NODE_ENV=development
    networks:
      - backend
```

<details>
<summary>💡 Click to reveal answer</summary>

**Answer:**

**docker-compose.yml (Base):**
```yaml
version: '3.8'

services:
  api:
    build: .
    environment:
      - NODE_ENV=development
    networks:
      - backend
    restart: unless-stopped

networks:
  backend:
    driver: bridge
```

**docker-compose.override.yml (Development):**
```yaml
version: '3.8'

services:
  api:
    ports:
      - "8080:8080"
    volumes:
      - .:/app
      - node_modules:/app/node_modules
    environment:
      - NODE_ENV=development
      - DEBUG=true
    command: npm run dev

volumes:
  node_modules:
```

**docker-compose.prod.yml (Production):**
```yaml
version: '3.8'

services:
  api:
    build:
      target: production
    environment:
      - NODE_ENV=production
      - DB_PASSWORD_FILE=/run/secrets/db_password
      - API_KEY_FILE=/run/secrets/api_key
    secrets:
      - db_password
      - api_key
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    # No ports exposed - accessed through load balancer
    restart: always

secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_key:
    external: true
    name: production_api_key
```

**Usage:**
```bash
# Development (automatic override)
docker-compose up -d

# Production (explicit files)
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```
</details>

---

## 🏆 Performance Assessment

### Scoring Rubric

| Score Range | Grade | Performance Level |
|-------------|-------|-------------------|
| 90-100 | A+ | Expert Level - Production Ready |
| 80-89 | A | Advanced - Complex Deployments |
| 75-79 | B+ | Proficient - Multi-Service Apps |
| 65-74 | B | Competent - Basic Orchestration |
| 55-64 | C | Developing - Simple Compose |
| Below 55 | F | Needs Review |

### Assessment Breakdown

**Section A: Fundamentals (25 points)**
- Understanding of Compose file structure
- Knowledge of networking and dependencies
- Service configuration best practices

**Section B: Orchestration (25 points)**
- Complex service relationships
- Dependency management
- Microservices architecture patterns

**Section C: Scaling & Load Balancing (25 points)**
- Service scaling strategies
- Load balancer configuration
- High availability patterns

**Section D: Environment Management (25 points)**
- Multi-environment configurations
- Secrets and security
- Production deployment patterns

## 🎯 Remediation Plan

### If you scored below 75:

#### Review These Topics:
1. **Docker Compose file structure and syntax**
2. **Service dependencies and health checks**
3. **Network isolation and security**
4. **Scaling and load balancing concepts**
5. **Environment-specific configurations**

#### Recommended Actions:
1. **Repeat the lab exercises** in Chapter 06
2. **Practice writing compose files** from scratch
3. **Experiment with scaling** different services
4. **Study production deployment patterns**
5. **Review Docker networking** concepts

#### Additional Resources:
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Compose Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- Practice with the lab exercises

## ✅ Next Steps

### If you passed (75+):
- Proceed to **[Chapter 07: Docker Registry](../07-docker-registry/README.md)**
- Consider the advanced challenges in the lab
- Share your compose configurations with the community

### If you need to improve:
- Review the failed sections
- Complete additional practice exercises
- Retake the checkpoint when ready

---

**🎉 Congratulations on completing the Docker Compose checkpoint!**

Understanding multi-container orchestration is crucial for modern application deployment. Keep practicing these concepts as you move toward production Docker deployments.

---

**[⬅️ Back to Chapter 06](../README.md)** | **[Next: Chapter 07 ➡️](../07-docker-registry/README.md)** 