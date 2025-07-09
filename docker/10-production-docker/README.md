# 🏢 Chapter 10: Production Docker - Enterprise Deployment & Operations

Welcome to enterprise Docker mastery! This final chapter covers large-scale production deployments, advanced orchestration patterns, high availability architectures, and operational excellence for mission-critical applications.

## 🎯 Learning Objectives

By the end of this chapter, you will:
- ✅ Design enterprise-scale container architectures
- ✅ Implement high availability and disaster recovery
- ✅ Master advanced Kubernetes patterns
- ✅ Establish CI/CD pipelines for production
- ✅ Implement comprehensive observability
- ✅ Manage enterprise security and compliance

## 🏗️ Enterprise Architecture Patterns

### 1. Multi-Tier Production Architecture

```yaml
# enterprise-architecture.yml
version: '3.8'

services:
  # Load Balancer Tier
  traefik:
    image: traefik:v3.0
    command:
      - --api.dashboard=true
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --providers.docker=true
      - --providers.docker.exposedByDefault=false
      - --certificatesresolvers.letsencrypt.acme.tlschallenge=true
      - --certificatesresolvers.letsencrypt.acme.email=admin@company.com
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
      - --metrics.prometheus=true
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik-certs:/letsencrypt
    networks:
      - frontend
      - monitoring
    deploy:
      replicas: 3
      placement:
        constraints:
          - node.role == manager
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3

  # Application Tier
  api-gateway:
    image: company/api-gateway:${VERSION}
    environment:
      - NODE_ENV=production
      - REDIS_URL=redis://redis-cluster:6379
      - DATABASE_URL=postgresql://postgres-primary:5432/app
      - JWT_SECRET_FILE=/run/secrets/jwt_secret
      - API_KEY_FILE=/run/secrets/api_key
    secrets:
      - jwt_secret
      - api_key
    networks:
      - frontend
      - backend
    deploy:
      replicas: 5
      resources:
        limits:
          cpus: '2.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
      update_config:
        parallelism: 2
        delay: 30s
        failure_action: rollback
        monitor: 60s
      restart_policy:
        condition: on-failure
    labels:
      - traefik.enable=true
      - traefik.http.routers.api.rule=Host(`api.company.com`)
      - traefik.http.routers.api.tls.certresolver=letsencrypt
      - traefik.http.services.api.loadbalancer.server.port=3000
      - traefik.http.middlewares.api-ratelimit.ratelimit.burst=100

  user-service:
    image: company/user-service:${VERSION}
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://postgres-primary:5432/users
      - REDIS_URL=redis://redis-cluster:6379
    secrets:
      - db_password
    networks:
      - backend
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
      placement:
        constraints:
          - node.labels.tier == application
      update_config:
        parallelism: 1
        delay: 10s

  # Data Tier
  postgres-primary:
    image: postgres:15
    environment:
      - POSTGRES_DB=app
      - POSTGRES_USER=app_user
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
      - POSTGRES_REPLICATION_MODE=master
      - POSTGRES_REPLICATION_USER=replicator
      - POSTGRES_REPLICATION_PASSWORD_FILE=/run/secrets/replication_password
    secrets:
      - db_password
      - replication_password
    volumes:
      - postgres-primary-data:/var/lib/postgresql/data
      - ./postgres/postgresql.conf:/etc/postgresql/postgresql.conf
    networks:
      - backend
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.tier == database
          - node.labels.storage == ssd
      resources:
        limits:
          cpus: '4.0'
          memory: 8G
        reservations:
          cpus: '2.0'
          memory: 4G

  postgres-replica:
    image: postgres:15
    environment:
      - POSTGRES_REPLICATION_MODE=slave
      - POSTGRES_MASTER_SERVICE=postgres-primary
      - POSTGRES_REPLICATION_USER=replicator
      - POSTGRES_REPLICATION_PASSWORD_FILE=/run/secrets/replication_password
    secrets:
      - replication_password
    volumes:
      - postgres-replica-data:/var/lib/postgresql/data
    networks:
      - backend
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.labels.tier == database
      resources:
        limits:
          cpus: '2.0'
          memory: 4G

  redis-cluster:
    image: redis:7-alpine
    command: >
      redis-server
      --cluster-enabled yes
      --cluster-config-file nodes.conf
      --cluster-node-timeout 5000
      --appendonly yes
      --maxmemory 1gb
      --maxmemory-policy allkeys-lru
    volumes:
      - redis-data:/data
    networks:
      - backend
    deploy:
      replicas: 6
      placement:
        constraints:
          - node.labels.tier == cache
      resources:
        limits:
          cpus: '1.0'
          memory: 1.5G

networks:
  frontend:
    driver: overlay
    attachable: true
  backend:
    driver: overlay
    internal: true
  monitoring:
    driver: overlay

volumes:
  traefik-certs:
  postgres-primary-data:
  postgres-replica-data:
  redis-data:

secrets:
  jwt_secret:
    external: true
  api_key:
    external: true
  db_password:
    external: true
  replication_password:
    external: true
```

### 2. High Availability Patterns

#### Active-Passive Failover
```python
#!/usr/bin/env python3
# ha-failover-manager.py

import docker
import time
import requests
import logging
from typing import Dict, List
import threading

class HAFailoverManager:
    def __init__(self, config: Dict):
        self.client = docker.from_env()
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.active_services = {}
        self.passive_services = {}
        
    def setup_active_passive(self, service_name: str):
        """Setup active-passive configuration"""
        active_service = f"{service_name}-active"
        passive_service = f"{service_name}-passive"
        
        # Deploy active service
        self.client.services.create(
            image=self.config['image'],
            name=active_service,
            mode={'Replicated': {'Replicas': self.config['active_replicas']}},
            endpoint_spec={
                'Ports': [{'Protocol': 'tcp', 'TargetPort': 3000, 'PublishedPort': 3000}]
            },
            labels={'role': 'active', 'service_group': service_name}
        )
        
        # Deploy passive service (standby)
        self.client.services.create(
            image=self.config['image'],
            name=passive_service,
            mode={'Replicated': {'Replicas': self.config['passive_replicas']}},
            endpoint_spec={
                'Ports': [{'Protocol': 'tcp', 'TargetPort': 3000, 'PublishedPort': 3001}]
            },
            labels={'role': 'passive', 'service_group': service_name}
        )
        
        self.active_services[service_name] = active_service
        self.passive_services[service_name] = passive_service
        
        self.logger.info(f"HA setup completed for {service_name}")
    
    def health_check(self, service_name: str) -> bool:
        """Check health of active service"""
        try:
            response = requests.get(
                f"http://localhost:3000/health",
                timeout=5
            )
            return response.status_code == 200
        except Exception as e:
            self.logger.error(f"Health check failed for {service_name}: {e}")
            return False
    
    def failover(self, service_name: str):
        """Execute failover from active to passive"""
        self.logger.warning(f"Initiating failover for {service_name}")
        
        active_service_name = self.active_services[service_name]
        passive_service_name = self.passive_services[service_name]
        
        try:
            # Get services
            active_service = self.client.services.get(active_service_name)
            passive_service = self.client.services.get(passive_service_name)
            
            # Promote passive to active
            passive_service.update(
                endpoint_spec={
                    'Ports': [{'Protocol': 'tcp', 'TargetPort': 3000, 'PublishedPort': 3000}]
                },
                labels={'role': 'active', 'service_group': service_name}
            )
            
            # Demote active to passive
            active_service.update(
                endpoint_spec={
                    'Ports': [{'Protocol': 'tcp', 'TargetPort': 3000, 'PublishedPort': 3001}]
                },
                labels={'role': 'passive', 'service_group': service_name}
            )
            
            # Update internal tracking
            self.active_services[service_name] = passive_service_name
            self.passive_services[service_name] = active_service_name
            
            self.logger.info(f"Failover completed for {service_name}")
            
        except Exception as e:
            self.logger.error(f"Failover failed for {service_name}: {e}")
    
    def monitor_services(self):
        """Continuous monitoring and automatic failover"""
        while True:
            for service_name in self.active_services.keys():
                if not self.health_check(service_name):
                    self.logger.warning(f"Service {service_name} unhealthy, checking again...")
                    time.sleep(5)
                    
                    # Double-check before failover
                    if not self.health_check(service_name):
                        self.failover(service_name)
                        
                        # Wait for failover to complete
                        time.sleep(30)
            
            time.sleep(10)
    
    def start_monitoring(self):
        """Start monitoring in background thread"""
        monitor_thread = threading.Thread(target=self.monitor_services)
        monitor_thread.daemon = True
        monitor_thread.start()
        self.logger.info("HA monitoring started")

# Usage
if __name__ == "__main__":
    config = {
        'image': 'company/api:latest',
        'active_replicas': 3,
        'passive_replicas': 2
    }
    
    ha_manager = HAFailoverManager(config)
    ha_manager.setup_active_passive('api-service')
    ha_manager.start_monitoring()
    
    # Keep running
    try:
        while True:
            time.sleep(60)
    except KeyboardInterrupt:
        print("Shutting down HA manager")
```

## ☸️ Advanced Kubernetes Patterns

### 1. Production Kubernetes Deployment

```yaml
# k8s-production-deployment.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: production
  labels:
    app: api-service
    version: v1.0.0
    tier: backend
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 1
  selector:
    matchLabels:
      app: api-service
  template:
    metadata:
      labels:
        app: api-service
        version: v1.0.0
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: api-service
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - api-service
              topologyKey: kubernetes.io/hostname
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-type
                operator: In
                values:
                - application
      containers:
      - name: api
        image: company/api-service:v1.0.0
        imagePullPolicy: Always
        ports:
        - containerPort: 3000
          name: http
        - containerPort: 9090
          name: metrics
        env:
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: url
        - name: REDIS_URL
          valueFrom:
            configMapKeyRef:
              name: cache-config
              key: redis-url
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
        startupProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 30
        volumeMounts:
        - name: app-config
          mountPath: /app/config
          readOnly: true
        - name: secrets-volume
          mountPath: /app/secrets
          readOnly: true
        - name: tmp-volume
          mountPath: /tmp
      volumes:
      - name: app-config
        configMap:
          name: api-config
      - name: secrets-volume
        secret:
          secretName: api-secrets
          defaultMode: 0400
      - name: tmp-volume
        emptyDir: {}
      imagePullSecrets:
      - name: registry-credentials
      terminationGracePeriodSeconds: 30

---
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: production
  labels:
    app: api-service
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
    name: http
  - port: 9090
    targetPort: 9090
    protocol: TCP
    name: metrics
  selector:
    app: api-service

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-ingress
  namespace: production
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - api.company.com
    secretName: api-tls
  rules:
  - host: api.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80

---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-service-pdb
  namespace: production
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: api-service

---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-service-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-service
  minReplicas: 5
  maxReplicas: 50
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Pods
        value: 2
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Pods
        value: 4
        periodSeconds: 60
      - type: Percent
        value: 100
        periodSeconds: 15
```

### 2. GitOps CI/CD Pipeline

```yaml
# .github/workflows/production-deploy.yml
name: Production Deployment

on:
  push:
    branches: [main]
    tags: ['v*']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: company/api-service

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'

  build-and-test:
    runs-on: ubuntu-latest
    needs: security-scan
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3
    
    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
          type=sha,prefix={{branch}}-
    
    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        platforms: linux/amd64,linux/arm64
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
    
    - name: Scan Docker image
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.version }}
        format: 'sarif'
        output: 'image-trivy-results.sarif'
    
    - name: Sign container image
      run: |
        cosign sign --yes ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.meta.outputs.digest }}
      env:
        COSIGN_EXPERIMENTAL: 1

  deploy-staging:
    runs-on: ubuntu-latest
    needs: build-and-test
    environment: staging
    steps:
    - uses: actions/checkout@v4
    
    - name: Deploy to staging
      run: |
        # Update Kubernetes manifests
        yq eval '.spec.template.spec.containers[0].image = "${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ needs.build-and-test.outputs.version }}"' -i k8s/staging/deployment.yml
        
        # Apply to cluster
        kubectl apply -f k8s/staging/ --namespace=staging
        
        # Wait for rollout
        kubectl rollout status deployment/api-service --namespace=staging --timeout=300s
    
    - name: Run integration tests
      run: |
        # Wait for service to be ready
        kubectl wait --for=condition=ready pod -l app=api-service --namespace=staging --timeout=300s
        
        # Run tests
        npm run test:integration -- --endpoint=https://staging-api.company.com

  deploy-production:
    runs-on: ubuntu-latest
    needs: [build-and-test, deploy-staging]
    environment: production
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
    - uses: actions/checkout@v4
    
    - name: Blue-Green Deployment
      run: |
        # Get current deployment
        CURRENT_VERSION=$(kubectl get deployment api-service -o jsonpath='{.metadata.labels.version}' --namespace=production)
        NEW_VERSION=${{ needs.build-and-test.outputs.version }}
        
        # Create new deployment
        yq eval '.metadata.name = "api-service-' + env(NEW_VERSION) + '"' -i k8s/production/deployment.yml
        yq eval '.spec.template.spec.containers[0].image = "${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:' + env(NEW_VERSION) + '"' -i k8s/production/deployment.yml
        
        # Deploy new version
        kubectl apply -f k8s/production/deployment.yml --namespace=production
        
        # Wait for new deployment to be ready
        kubectl rollout status deployment/api-service-${NEW_VERSION} --namespace=production --timeout=600s
        
        # Health check
        kubectl run health-check --image=curlimages/curl --rm -i --restart=Never -- \
          sh -c "curl -f http://api-service-${NEW_VERSION}/health"
        
        # Switch service to new deployment
        kubectl patch service api-service --namespace=production -p '{"spec":{"selector":{"version":"'${NEW_VERSION}'"}}}'
        
        # Remove old deployment after 5 minutes
        sleep 300
        kubectl delete deployment api-service-${CURRENT_VERSION} --namespace=production || true
        
        # Update main deployment
        kubectl patch deployment api-service --namespace=production -p '{"metadata":{"labels":{"version":"'${NEW_VERSION}'"}}}'

  notify:
    runs-on: ubuntu-latest
    needs: [deploy-production]
    if: always()
    steps:
    - name: Notify deployment status
      uses: 8398a7/action-slack@v3
      with:
        status: ${{ needs.deploy-production.result }}
        channel: '#deployments'
        text: |
          Production deployment ${{ needs.deploy-production.result }}
          Version: ${{ github.ref_name }}
          Commit: ${{ github.sha }}
      env:
        SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## 📊 Enterprise Observability

### 1. Comprehensive Monitoring Stack

```yaml
# monitoring-stack-enterprise.yml
version: '3.8'

services:
  # Metrics Collection
  prometheus:
    image: prom/prometheus:latest
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus-data:/prometheus
    networks:
      - monitoring
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.labels.monitoring == true

  # Long-term Storage
  thanos-sidecar:
    image: thanosio/thanos:latest
    command:
      - sidecar
      - --tsdb.path=/prometheus
      - --prometheus.url=http://prometheus:9090
      - --grpc-address=0.0.0.0:10901
      - --http-address=0.0.0.0:10902
      - --objstore.config-file=/etc/thanos/bucket.yml
    volumes:
      - prometheus-data:/prometheus:ro
      - ./thanos:/etc/thanos
    networks:
      - monitoring

  thanos-query:
    image: thanosio/thanos:latest
    command:
      - query
      - --http-address=0.0.0.0:19192
      - --store=thanos-sidecar:10901
      - --store=thanos-store:10901
    ports:
      - "19192:19192"
    networks:
      - monitoring

  # Visualization
  grafana:
    image: grafana/grafana-enterprise:latest
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
      - GF_ENTERPRISE_LICENSE_TEXT=${GRAFANA_LICENSE}
      - GF_INSTALL_PLUGINS=grafana-piechart-panel,grafana-worldmap-panel
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    networks:
      - monitoring
      - frontend
    deploy:
      replicas: 2
      labels:
        - traefik.enable=true
        - traefik.http.routers.grafana.rule=Host(`grafana.company.com`)
        - traefik.http.routers.grafana.tls.certresolver=letsencrypt

  # Logging
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.8.0
    environment:
      - cluster.name=production-logs
      - node.name=es-node-${HOSTNAME}
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms4g -Xmx4g"
      - xpack.security.enabled=true
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data
    networks:
      - monitoring
    deploy:
      resources:
        limits:
          memory: 8G
        reservations:
          memory: 4G

  kibana:
    image: docker.elastic.co/kibana/kibana:8.8.0
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=${ELASTIC_PASSWORD}
    networks:
      - monitoring
      - frontend
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.kibana.rule=Host(`logs.company.com`)

  logstash:
    image: docker.elastic.co/logstash/logstash:8.8.0
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline
      - ./logstash/config:/usr/share/logstash/config
    environment:
      - "LS_JAVA_OPTS=-Xms2g -Xmx2g"
    networks:
      - monitoring
    deploy:
      resources:
        limits:
          memory: 4G

  # Tracing
  jaeger:
    image: jaegertracing/all-in-one:latest
    environment:
      - COLLECTOR_OTLP_ENABLED=true
      - SPAN_STORAGE_TYPE=elasticsearch
      - ES_SERVER_URLS=http://elasticsearch:9200
      - ES_USERNAME=elastic
      - ES_PASSWORD=${ELASTIC_PASSWORD}
    networks:
      - monitoring
      - frontend
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.jaeger.rule=Host(`tracing.company.com`)

  # Alerting
  alertmanager:
    image: prom/alertmanager:latest
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=https://alerts.company.com'
      - '--cluster.peer=alertmanager-2:9094'
    volumes:
      - ./alertmanager:/etc/alertmanager
      - alertmanager-data:/alertmanager
    networks:
      - monitoring
      - frontend
    deploy:
      replicas: 2
      labels:
        - traefik.enable=true
        - traefik.http.routers.alertmanager.rule=Host(`alerts.company.com`)

networks:
  monitoring:
    driver: overlay
    attachable: true
  frontend:
    driver: overlay
    external: true

volumes:
  prometheus-data:
  grafana-data:
  elasticsearch-data:
  alertmanager-data:
```

### 2. Advanced Alerting Configuration

```yaml
# alertmanager.yml
global:
  smtp_smarthost: 'smtp.company.com:587'
  smtp_from: 'alerts@company.com'
  smtp_auth_username: 'alerts@company.com'
  smtp_auth_password: '${SMTP_PASSWORD}'

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'
  routes:
  - match:
      severity: critical
    receiver: 'critical-alerts'
    group_wait: 5s
    repeat_interval: 5m
  - match:
      severity: warning
    receiver: 'warning-alerts'
    repeat_interval: 30m
  - match_re:
      service: ^(database|cache).*
    receiver: 'infrastructure-alerts'

receivers:
- name: 'default'
  email_configs:
  - to: 'devops@company.com'
    subject: '[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}'
    body: |
      {{ range .Alerts }}
      Alert: {{ .Annotations.summary }}
      Description: {{ .Annotations.description }}
      Labels: {{ range .Labels.SortedPairs }}{{ .Name }}={{ .Value }} {{ end }}
      {{ end }}

- name: 'critical-alerts'
  email_configs:
  - to: 'oncall@company.com'
    subject: '🚨 CRITICAL: {{ .GroupLabels.alertname }}'
  slack_configs:
  - api_url: '${SLACK_WEBHOOK_URL}'
    channel: '#critical-alerts'
    title: '🚨 Critical Alert'
    text: |
      {{ range .Alerts }}
      *Alert:* {{ .Annotations.summary }}
      *Description:* {{ .Annotations.description }}
      *Severity:* {{ .Labels.severity }}
      *Service:* {{ .Labels.service }}
      {{ end }}
  pagerduty_configs:
  - routing_key: '${PAGERDUTY_KEY}'
    description: '{{ .GroupLabels.alertname }}: {{ .Annotations.summary }}'

- name: 'warning-alerts'
  slack_configs:
  - api_url: '${SLACK_WEBHOOK_URL}'
    channel: '#alerts'
    title: '⚠️ Warning Alert'

- name: 'infrastructure-alerts'
  email_configs:
  - to: 'infrastructure@company.com'
    subject: '[INFRA] {{ .GroupLabels.alertname }}'
  slack_configs:
  - api_url: '${SLACK_WEBHOOK_URL}'
    channel: '#infrastructure'

inhibit_rules:
- source_match:
    severity: 'critical'
  target_match:
    severity: 'warning'
  equal: ['alertname', 'service']
```

## 🚀 What's Next?

Congratulations! You've completed the comprehensive Docker learning journey. You now have enterprise-grade skills covering:

- **Container Fundamentals** → **Production Deployment**
- **Security Best Practices** → **Enterprise Architecture**
- **Performance Optimization** → **Advanced Orchestration**
- **Monitoring & Observability** → **Operational Excellence**

### Continue Your Journey

- **Kubernetes Mastery**: Deep dive into advanced K8s patterns
- **Service Mesh**: Implement Istio or Linkerd for microservices
- **GitOps**: Master ArgoCD and Flux for deployment automation
- **Cloud Native**: Explore CNCF landscape tools
- **Site Reliability Engineering**: Implement SRE practices

## 📚 Key Takeaways

✅ **Enterprise Architecture**: Multi-tier, highly available production systems  
✅ **Advanced Orchestration**: Kubernetes patterns for scale and reliability  
✅ **CI/CD Excellence**: GitOps workflows with security and quality gates  
✅ **Comprehensive Observability**: Metrics, logs, traces, and alerting  
✅ **Operational Excellence**: Automation, monitoring, and incident response  
✅ **Production Readiness**: Real-world patterns for mission-critical applications  

## 📝 Final Checklist

Before considering yourself production-ready, ensure you can:
- [ ] Design enterprise container architectures
- [ ] Implement high availability and disaster recovery
- [ ] Deploy applications using advanced Kubernetes patterns
- [ ] Establish comprehensive CI/CD pipelines
- [ ] Monitor and observe production systems
- [ ] Manage enterprise security and compliance
- [ ] Troubleshoot complex production issues
- [ ] Implement operational excellence practices

---

**🎉 Congratulations!** You've mastered enterprise Docker and are ready to architect and operate production container platforms. Complete the [lab exercise](lab/README.md) to practice these concepts, then validate your knowledge with the [checkpoint](checkpoint.md)!

---

<div align="center">

**[⬅️ Previous: Docker Best Practices](../09-docker-best-practices/README.md)** | **[🏠 Back to Course Home](../../README.md)**

</div> 