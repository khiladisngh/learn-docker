# 🧪 Lab Exercise: Docker Images - Advanced Image Creation & Optimization

Welcome to the advanced Docker Images lab! You'll master image optimization, security scanning, registry management, and build sophisticated Python applications.

## 🎯 Lab Objectives

By completing this lab, you will:
- ✅ Create highly optimized Docker images using multi-stage builds
- ✅ Implement comprehensive security practices
- ✅ Set up and work with private Docker registries
- ✅ Scan images for vulnerabilities
- ✅ Build custom base images
- ✅ Optimize image layers and caching strategies
- ✅ Create production-ready Python applications

## 🛠️ Prerequisites

- Completed Chapter 01 lab
- Docker Desktop running
- Basic knowledge of Python
- Understanding of multi-stage builds

## 📝 Lab Setup

Create your lab workspace:

```bash
# Create lab directory
mkdir docker-images-lab
cd docker-images-lab

# Create project structure
mkdir -p {python-flask,python-ml,python-async,optimization,registry,security}
```

## Part 1: Python Flask Microservice

### Step 1: Create Complete Flask Application

Create `python-flask/requirements.txt`:
```txt
Flask==2.3.2
gunicorn==20.1.0
redis==4.6.0
psycopg2-binary==2.9.7
python-dotenv==1.0.0
prometheus-client==0.17.1
structlog==23.1.0
```

Create `python-flask/app.py`:
```python
import os
import redis
import psycopg2
import structlog
from flask import Flask, jsonify, request
from datetime import datetime
from prometheus_client import Counter, Histogram, generate_latest
import socket
import time

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

app = Flask(__name__)

# Metrics
REQUEST_COUNT = Counter('flask_requests_total', 'Total requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('flask_request_duration_seconds', 'Request latency')

# Configuration
DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'
PORT = int(os.getenv('PORT', 5000))
REDIS_URL = os.getenv('REDIS_URL', 'redis://redis:6379/0')
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://user:password@postgres/app')

# Initialize connections
redis_client = None
db_available = False

def init_redis():
    """Initialize Redis connection"""
    global redis_client
    try:
        redis_client = redis.from_url(REDIS_URL, decode_responses=True)
        redis_client.ping()
        logger.info("Redis connected successfully")
        return True
    except Exception as e:
        logger.error("Redis connection failed", error=str(e))
        return False

def check_database():
    """Check database connection"""
    global db_available
    try:
        conn = psycopg2.connect(DATABASE_URL)
        conn.close()
        db_available = True
        logger.info("Database connection successful")
        return True
    except Exception as e:
        logger.error("Database connection failed", error=str(e))
        db_available = False
        return False

# Initialize connections
redis_available = init_redis()
check_database()

@app.before_request
def before_request():
    """Log request and start timer"""
    request.start_time = time.time()
    logger.info("Request started", 
                method=request.method, 
                path=request.path,
                remote_addr=request.remote_addr)

@app.after_request
def after_request(response):
    """Log response and record metrics"""
    duration = time.time() - request.start_time
    
    REQUEST_COUNT.labels(method=request.method, endpoint=request.endpoint).inc()
    REQUEST_LATENCY.observe(duration)
    
    logger.info("Request completed", 
                method=request.method,
                path=request.path,
                status_code=response.status_code,
                duration=duration)
    
    return response

@app.route('/')
def index():
    """Main endpoint with system information"""
    hostname = socket.gethostname()
    
    # Get visit count from Redis
    visits = 0
    if redis_available and redis_client:
        try:
            visits = redis_client.incr('visits')
        except Exception as e:
            logger.warning("Failed to increment visits", error=str(e))
    
    return jsonify({
        'message': 'Advanced Python Flask Microservice',
        'version': '2.0.0',
        'timestamp': datetime.now().isoformat(),
        'hostname': hostname,
        'environment': os.getenv('FLASK_ENV', 'production'),
        'visits': visits,
        'services': {
            'redis': redis_available,
            'database': db_available
        },
        'endpoints': {
            'health': '/health',
            'metrics': '/metrics',
            'users': '/api/users',
            'cache': '/api/cache/<key>',
            'load-test': '/api/load-test'
        }
    })

@app.route('/health')
def health():
    """Comprehensive health check"""
    health_status = {
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'hostname': socket.gethostname(),
        'services': {}
    }
    
    # Check Redis
    if redis_client:
        try:
            redis_client.ping()
            health_status['services']['redis'] = 'healthy'
        except Exception as e:
            health_status['services']['redis'] = 'unhealthy'
            health_status['status'] = 'degraded'
            logger.error("Redis health check failed", error=str(e))
    else:
        health_status['services']['redis'] = 'unavailable'
    
    # Check database
    try:
        conn = psycopg2.connect(DATABASE_URL)
        conn.close()
        health_status['services']['database'] = 'healthy'
    except Exception as e:
        health_status['services']['database'] = 'unhealthy'
        health_status['status'] = 'degraded'
        logger.error("Database health check failed", error=str(e))
    
    status_code = 200 if health_status['status'] == 'healthy' else 503
    return jsonify(health_status), status_code

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

@app.route('/api/users', methods=['GET'])
def get_users():
    """Get users from database"""
    if not db_available:
        return jsonify({'error': 'Database unavailable'}), 503
    
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        cur.execute("SELECT id, name, email, created_at FROM users ORDER BY created_at DESC LIMIT 10")
        users = []
        for row in cur.fetchall():
            users.append({
                'id': row[0],
                'name': row[1],
                'email': row[2],
                'created_at': row[3].isoformat() if row[3] else None
            })
        conn.close()
        
        logger.info("Users retrieved", count=len(users))
        return jsonify({'users': users, 'count': len(users)})
        
    except Exception as e:
        logger.error("Failed to retrieve users", error=str(e))
        return jsonify({'error': str(e)}), 500

@app.route('/api/users', methods=['POST'])
def create_user():
    """Create new user"""
    if not db_available:
        return jsonify({'error': 'Database unavailable'}), 503
    
    data = request.get_json()
    if not data or 'name' not in data or 'email' not in data:
        return jsonify({'error': 'Name and email required'}), 400
    
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO users (name, email, created_at) VALUES (%s, %s, %s) RETURNING id",
            (data['name'], data['email'], datetime.now())
        )
        user_id = cur.fetchone()[0]
        conn.commit()
        conn.close()
        
        # Cache user in Redis
        if redis_client:
            try:
                redis_client.hset(f"user:{user_id}", mapping={
                    'name': data['name'],
                    'email': data['email'],
                    'created_at': datetime.now().isoformat()
                })
                redis_client.expire(f"user:{user_id}", 3600)  # 1 hour
            except Exception as e:
                logger.warning("Failed to cache user", error=str(e))
        
        logger.info("User created", user_id=user_id, name=data['name'])
        return jsonify({
            'id': user_id,
            'name': data['name'],
            'email': data['email']
        }), 201
        
    except Exception as e:
        logger.error("Failed to create user", error=str(e))
        return jsonify({'error': str(e)}), 500

@app.route('/api/cache/<key>', methods=['GET'])
def get_cache(key):
    """Get value from cache"""
    if not redis_client:
        return jsonify({'error': 'Redis unavailable'}), 503
    
    try:
        value = redis_client.get(key)
        if value:
            return jsonify({'key': key, 'value': value})
        else:
            return jsonify({'error': 'Key not found'}), 404
    except Exception as e:
        logger.error("Cache get failed", key=key, error=str(e))
        return jsonify({'error': str(e)}), 500

@app.route('/api/cache/<key>', methods=['POST'])
def set_cache(key):
    """Set value in cache"""
    if not redis_client:
        return jsonify({'error': 'Redis unavailable'}), 503
    
    data = request.get_json()
    if not data or 'value' not in data:
        return jsonify({'error': 'Value required'}), 400
    
    try:
        ttl = data.get('ttl', 3600)  # Default 1 hour
        redis_client.setex(key, ttl, data['value'])
        logger.info("Cache set", key=key, ttl=ttl)
        return jsonify({'key': key, 'value': data['value'], 'ttl': ttl})
    except Exception as e:
        logger.error("Cache set failed", key=key, error=str(e))
        return jsonify({'error': str(e)}), 500

@app.route('/api/load-test')
def load_test():
    """Endpoint for load testing"""
    import random
    import time
    
    # Simulate some work
    work_time = random.uniform(0.01, 0.1)
    time.sleep(work_time)
    
    return jsonify({
        'message': 'Load test endpoint',
        'work_time': work_time,
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    logger.info("Starting Flask application", 
                port=PORT, 
                debug=DEBUG,
                hostname=socket.gethostname())
    
    if DEBUG:
        app.run(host='0.0.0.0', port=PORT, debug=True)
    else:
        # Production: This would typically be handled by gunicorn
        app.run(host='0.0.0.0', port=PORT, debug=False, threaded=True)
```

Create `python-flask/gunicorn.conf.py`:
```python
import multiprocessing
import os

# Server socket
bind = f"0.0.0.0:{os.getenv('PORT', 5000)}"
backlog = 2048

# Worker processes
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = 'sync'
worker_connections = 1000
timeout = 30
keepalive = 2

# Restart workers after this many requests
max_requests = 1000
max_requests_jitter = 50

# Logging
accesslog = '-'
errorlog = '-'
loglevel = 'info'
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# Process naming
proc_name = 'flask-microservice'

# Server mechanics
preload_app = True
daemon = False
pidfile = '/tmp/gunicorn.pid'
user = None
group = None
tmp_upload_dir = None

# SSL
keyfile = None
certfile = None
```

### Step 2: Create Optimized Dockerfile

Create `python-flask/Dockerfile`:
```dockerfile
# Multi-stage build for Python Flask microservice
FROM python:3.11-alpine AS base

# Install system dependencies
RUN apk update && apk add --no-cache \
    gcc \
    musl-dev \
    linux-headers \
    postgresql-dev \
    curl \
    dumb-init \
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

# Copy application files
COPY --chown=appuser:appgroup app.py gunicorn.conf.py ./

# Create necessary directories
RUN mkdir -p /app/logs && \
    chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Use gunicorn for production
CMD ["gunicorn", "--config", "gunicorn.conf.py", "app:app"]
```

### Step 3: Create Development Dockerfile

Create `python-flask/Dockerfile.dev`:
```dockerfile
FROM python:3.11-alpine

# Install dev dependencies
RUN apk update && apk add --no-cache \
    gcc \
    musl-dev \
    linux-headers \
    postgresql-dev \
    curl \
    git \
    && rm -rf /var/cache/apk/*

# Set development environment
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    FLASK_ENV=development \
    DEBUG=True

WORKDIR /app

# Install dependencies including dev tools
COPY requirements.txt requirements-dev.txt ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir -r requirements-dev.txt

# Copy source code
COPY . .

EXPOSE 5000

# Development server with auto-reload
CMD ["python", "app.py"]
```

Create `python-flask/requirements-dev.txt`:
```txt
pytest==7.4.0
pytest-flask==1.2.0
pytest-cov==4.1.0
black==23.7.0
flake8==6.0.0
mypy==1.5.0
bandit==1.7.5
```

### Step 4: Build and Test Flask Application

```bash
cd python-flask

# Build production image
docker build -t flask-microservice:prod .

# Build development image
docker build -f Dockerfile.dev -t flask-microservice:dev .

# Run with dependencies
docker network create microservice-net

# Start Redis
docker run -d --name redis \
  --network microservice-net \
  redis:7-alpine

# Start PostgreSQL
docker run -d --name postgres \
  --network microservice-net \
  -e POSTGRES_USER=user \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB=app \
  postgres:15-alpine

# Create users table
docker exec postgres psql -U user -d app -c "
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"

# Run Flask application
docker run -d --name flask-app \
  --network microservice-net \
  -p 5000:5000 \
  -e REDIS_URL=redis://redis:6379/0 \
  -e DATABASE_URL=postgresql://user:password@postgres/app \
  flask-microservice:prod

# Test the application
curl http://localhost:5000
curl http://localhost:5000/health
curl -X POST http://localhost:5000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com"}'
curl http://localhost:5000/api/users
```

## Part 2: Python Machine Learning API

### Step 1: Create ML Application

Create `python-ml/requirements.txt`:
```txt
Flask==2.3.2
scikit-learn==1.3.0
numpy==1.24.3
pandas==2.0.3
joblib==1.3.2
gunicorn==20.1.0
prometheus-client==0.17.1
```

Create `python-ml/ml_service.py`:
```python
from flask import Flask, request, jsonify
import numpy as np
import pandas as pd
import joblib
import os
from datetime import datetime
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.datasets import make_classification, make_regression
from sklearn.metrics import accuracy_score, mean_squared_error
from prometheus_client import Counter, Histogram, Gauge, generate_latest
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Metrics
PREDICTION_COUNTER = Counter('ml_predictions_total', 'Total predictions made')
PREDICTION_LATENCY = Histogram('ml_prediction_duration_seconds', 'Prediction latency')
MODEL_ACCURACY = Gauge('ml_model_accuracy', 'Current model accuracy')

class MLModelManager:
    def __init__(self):
        self.models = {}
        self.model_dir = '/app/models'
        self.ensure_model_dir()
        self.load_or_train_models()
    
    def ensure_model_dir(self):
        """Ensure model directory exists"""
        os.makedirs(self.model_dir, exist_ok=True)
    
    def load_or_train_models(self):
        """Load existing models or train new ones"""
        # Classification model
        clf_path = os.path.join(self.model_dir, 'classifier.pkl')
        if os.path.exists(clf_path):
            self.models['classifier'] = joblib.load(clf_path)
            logger.info("Classification model loaded from disk")
        else:
            self.train_classification_model()
        
        # Regression model
        reg_path = os.path.join(self.model_dir, 'regressor.pkl')
        if os.path.exists(reg_path):
            self.models['regressor'] = joblib.load(reg_path)
            logger.info("Regression model loaded from disk")
        else:
            self.train_regression_model()
    
    def train_classification_model(self):
        """Train classification model"""
        logger.info("Training classification model...")
        
        # Generate sample data
        X, y = make_classification(
            n_samples=2000,
            n_features=20,
            n_informative=15,
            n_redundant=5,
            n_classes=2,
            random_state=42
        )
        
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )
        
        # Train model
        model = RandomForestClassifier(n_estimators=100, random_state=42)
        model.fit(X_train, y_train)
        
        # Evaluate
        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        
        # Save model
        model_path = os.path.join(self.model_dir, 'classifier.pkl')
        joblib.dump(model, model_path)
        
        self.models['classifier'] = model
        MODEL_ACCURACY.set(accuracy)
        
        logger.info(f"Classification model trained with accuracy: {accuracy:.3f}")
        return accuracy
    
    def train_regression_model(self):
        """Train regression model"""
        logger.info("Training regression model...")
        
        # Generate sample data
        X, y = make_regression(
            n_samples=2000,
            n_features=15,
            n_informative=10,
            noise=0.1,
            random_state=42
        )
        
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )
        
        # Train model
        model = RandomForestRegressor(n_estimators=100, random_state=42)
        model.fit(X_train, y_train)
        
        # Evaluate
        y_pred = model.predict(X_test)
        mse = mean_squared_error(y_test, y_pred)
        
        # Save model
        model_path = os.path.join(self.model_dir, 'regressor.pkl')
        joblib.dump(model, model_path)
        
        self.models['regressor'] = model
        
        logger.info(f"Regression model trained with MSE: {mse:.3f}")
        return mse
    
    def predict_classification(self, features):
        """Make classification prediction"""
        if 'classifier' not in self.models:
            raise ValueError("Classification model not available")
        
        model = self.models['classifier']
        prediction = model.predict([features])
        probabilities = model.predict_proba([features])[0]
        
        return {
            'prediction': int(prediction[0]),
            'probabilities': {
                'class_0': float(probabilities[0]),
                'class_1': float(probabilities[1])
            },
            'confidence': float(max(probabilities))
        }
    
    def predict_regression(self, features):
        """Make regression prediction"""
        if 'regressor' not in self.models:
            raise ValueError("Regression model not available")
        
        model = self.models['regressor']
        prediction = model.predict([features])
        
        return {
            'prediction': float(prediction[0])
        }

# Initialize ML models
ml_manager = MLModelManager()

@app.route('/')
def index():
    """API information"""
    return jsonify({
        'name': 'ML Microservice',
        'version': '1.0.0',
        'description': 'Machine Learning API with classification and regression',
        'models': list(ml_manager.models.keys()),
        'endpoints': {
            'predict_classification': '/predict/classification (POST)',
            'predict_regression': '/predict/regression (POST)',
            'retrain': '/retrain/<model_type> (POST)',
            'model_info': '/models/<model_type> (GET)',
            'health': '/health (GET)',
            'metrics': '/metrics (GET)'
        }
    })

@app.route('/health')
def health():
    """Health check"""
    models_loaded = len(ml_manager.models)
    return jsonify({
        'status': 'healthy' if models_loaded > 0 else 'unhealthy',
        'models_loaded': models_loaded,
        'available_models': list(ml_manager.models.keys()),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/metrics')
def metrics():
    """Prometheus metrics"""
    return generate_latest()

@app.route('/predict/classification', methods=['POST'])
def predict_classification():
    """Classification prediction endpoint"""
    start_time = datetime.now()
    
    try:
        data = request.get_json()
        if not data or 'features' not in data:
            return jsonify({'error': 'Features array required'}), 400
        
        features = data['features']
        if len(features) != 20:
            return jsonify({'error': 'Exactly 20 features required'}), 400
        
        result = ml_manager.predict_classification(features)
        
        # Record metrics
        PREDICTION_COUNTER.inc()
        duration = (datetime.now() - start_time).total_seconds()
        PREDICTION_LATENCY.observe(duration)
        
        return jsonify({
            'model_type': 'classification',
            'result': result,
            'prediction_time': duration,
            'timestamp': datetime.now().isoformat()
        })
    
    except Exception as e:
        logger.error(f"Classification prediction failed: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/predict/regression', methods=['POST'])
def predict_regression():
    """Regression prediction endpoint"""
    start_time = datetime.now()
    
    try:
        data = request.get_json()
        if not data or 'features' not in data:
            return jsonify({'error': 'Features array required'}), 400
        
        features = data['features']
        if len(features) != 15:
            return jsonify({'error': 'Exactly 15 features required'}), 400
        
        result = ml_manager.predict_regression(features)
        
        # Record metrics
        PREDICTION_COUNTER.inc()
        duration = (datetime.now() - start_time).total_seconds()
        PREDICTION_LATENCY.observe(duration)
        
        return jsonify({
            'model_type': 'regression',
            'result': result,
            'prediction_time': duration,
            'timestamp': datetime.now().isoformat()
        })
    
    except Exception as e:
        logger.error(f"Regression prediction failed: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/retrain/<model_type>', methods=['POST'])
def retrain_model(model_type):
    """Retrain model endpoint"""
    try:
        if model_type == 'classification':
            accuracy = ml_manager.train_classification_model()
            return jsonify({
                'message': 'Classification model retrained successfully',
                'accuracy': accuracy,
                'timestamp': datetime.now().isoformat()
            })
        elif model_type == 'regression':
            mse = ml_manager.train_regression_model()
            return jsonify({
                'message': 'Regression model retrained successfully',
                'mse': mse,
                'timestamp': datetime.now().isoformat()
            })
        else:
            return jsonify({'error': 'Invalid model type'}), 400
    
    except Exception as e:
        logger.error(f"Model retraining failed: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/models/<model_type>')
def model_info(model_type):
    """Get model information"""
    if model_type not in ml_manager.models:
        return jsonify({'error': 'Model not found'}), 404
    
    model = ml_manager.models[model_type]
    
    # Get model parameters
    if hasattr(model, 'get_params'):
        params = model.get_params()
    else:
        params = {}
    
    return jsonify({
        'model_type': model_type,
        'model_class': model.__class__.__name__,
        'parameters': params,
        'feature_count': getattr(model, 'n_features_in_', 'unknown'),
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5001))
    debug = os.getenv('DEBUG', 'False').lower() == 'true'
    
    logger.info(f"Starting ML service on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug)
```

### Step 2: Create ML Dockerfile

Create `python-ml/Dockerfile`:
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
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

FROM base AS dependencies

WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Install ML dependencies (this takes time, so cache this layer)
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

FROM dependencies AS application

# Create model directory
RUN mkdir -p /app/models

# Copy application code
COPY ml_service.py .

# Create non-root user
RUN useradd -m -u 1001 mluser && \
    chown -R mluser:mluser /app

USER mluser

EXPOSE 5001

# Longer startup time for ML models
HEALTHCHECK --interval=30s --timeout=15s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:5001/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5001", "--workers", "2", "--timeout", "60", "ml_service:app"]
```

### Step 3: Test ML Service

```bash
cd ../python-ml

# Build ML image
docker build -t ml-microservice:latest .

# Run ML service
docker run -d --name ml-service \
  --network microservice-net \
  -p 5001:5001 \
  ml-microservice:latest

# Test classification
curl -X POST http://localhost:5001/predict/classification \
  -H "Content-Type: application/json" \
  -d '{"features": [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]}'

# Test regression
curl -X POST http://localhost:5001/predict/regression \
  -H "Content-Type: application/json" \
  -d '{"features": [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]}'

# Check model info
curl http://localhost:5001/models/classifier
curl http://localhost:5001/models/regressor
```

## Part 3: Image Optimization Challenge

### Step 1: Size Optimization

```bash
cd ../optimization

# Create a simple Python app for optimization testing
cat > simple_app.py << 'EOF'
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello():
    return "Hello, optimized world!"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

echo "Flask==2.3.2" > requirements.txt
```

Create multiple Dockerfiles to compare sizes:

**Dockerfile.bloated (what NOT to do):**
```dockerfile
FROM python:3.11
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    wget \
    vim \
    git \
    htop \
    tree \
    && pip install --upgrade pip
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
EXPOSE 5000
CMD ["python", "simple_app.py"]
```

**Dockerfile.optimized:**
```dockerfile
FROM python:3.11-alpine AS base
RUN apk add --no-cache gcc musl-dev
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
FROM python:3.11-alpine
WORKDIR /app
COPY --from=base /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY simple_app.py .
RUN adduser -D appuser
USER appuser
EXPOSE 5000
CMD ["python", "simple_app.py"]
```

**Dockerfile.distroless:**
```dockerfile
FROM python:3.11-alpine AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM gcr.io/distroless/python3
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY simple_app.py /app/
WORKDIR /app
EXPOSE 5000
CMD ["simple_app.py"]
```

### Step 2: Build and Compare

```bash
# Build different versions
docker build -f Dockerfile.bloated -t simple-app:bloated .
docker build -f Dockerfile.optimized -t simple-app:optimized .
docker build -f Dockerfile.distroless -t simple-app:distroless .

# Compare sizes
docker images simple-app --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Analyze layers
docker history simple-app:bloated
docker history simple-app:optimized
```

## Part 4: Security Scanning

### Step 1: Image Security

```bash
cd ../security

# Build a vulnerable image for testing
cat > Dockerfile.vulnerable << 'EOF'
FROM python:3.8
RUN pip install Flask==1.0.0
COPY app.py .
USER root
CMD ["python", "app.py"]
EOF

echo 'from flask import Flask; app = Flask(__name__); app.run(host="0.0.0.0")' > app.py

docker build -f Dockerfile.vulnerable -t vulnerable-app .
```

### Step 2: Scan for Vulnerabilities

```bash
# Using Docker Scout (if available)
docker scout quickview vulnerable-app

# Using Trivy
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image vulnerable-app

# Create secure version
cat > Dockerfile.secure << 'EOF'
FROM python:3.11-alpine
RUN apk add --no-cache dumb-init
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup
USER appuser
ENTRYPOINT ["dumb-init", "--"]
CMD ["python", "app.py"]
EOF

echo "Flask==2.3.2" > requirements.txt

docker build -f Dockerfile.secure -t secure-app .

# Compare vulnerability scans
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image secure-app
```

## Part 5: Private Registry Setup

### Step 1: Setup Private Registry

```bash
cd ../registry

# Create registry with authentication
mkdir -p auth certs

# Generate self-signed certificate
openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout certs/domain.key -x509 -days 365 \
  -out certs/domain.crt \
  -subj "/C=US/ST=CA/L=SF/O=Test/CN=localhost"

# Create password file
docker run --rm --entrypoint htpasswd \
  httpd:2 -Bbn testuser testpass > auth/htpasswd

# Run secure registry
docker run -d \
  --restart=always \
  --name registry \
  -v $(pwd)/auth:/auth \
  -v $(pwd)/certs:/certs \
  -v registry-data:/var/lib/registry \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_PRIVATE_KEY=/certs/domain.key \
  -p 5000:5000 \
  registry:2
```

### Step 2: Push Images to Private Registry

```bash
# Login to private registry (skip TLS verification for testing)
docker login localhost:5000 -u testuser -p testpass

# Tag and push Flask app
docker tag flask-microservice:prod localhost:5000/flask-microservice:prod
docker push localhost:5000/flask-microservice:prod

# Tag and push ML service
docker tag ml-microservice:latest localhost:5000/ml-microservice:latest
docker push localhost:5000/ml-microservice:latest

# List images in registry
curl -k -u testuser:testpass https://localhost:5000/v2/_catalog
curl -k -u testuser:testpass https://localhost:5000/v2/flask-microservice/tags/list
```

## 🎯 Advanced Challenges

### Challenge 1: Multi-Architecture Build

```bash
# Create multi-architecture build
docker buildx create --name multiarch --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t flask-microservice:multiarch \
  --push \
  python-flask/

# Inspect manifest
docker buildx imagetools inspect flask-microservice:multiarch
```

### Challenge 2: Image Signing

```bash
# Enable Docker Content Trust
export DOCKER_CONTENT_TRUST=1

# Sign and push image
docker tag flask-microservice:prod flask-microservice:signed
docker push flask-microservice:signed

# Verify signature
docker trust inspect --pretty flask-microservice:signed
```

### Challenge 3: Custom Base Image

Create a custom Python base image:

```bash
mkdir custom-base
cd custom-base

cat > Dockerfile << 'EOF'
FROM python:3.11-alpine

# Install common dependencies
RUN apk add --no-cache \
    gcc \
    musl-dev \
    linux-headers \
    curl \
    dumb-init

# Install common Python packages
RUN pip install --no-cache-dir \
    gunicorn \
    prometheus-client \
    structlog

# Create standard user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Set working directory
WORKDIR /app
RUN chown appuser:appgroup /app

# Default health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Switch to non-root user
USER appuser

# Default entrypoint
ENTRYPOINT ["dumb-init", "--"]
EOF

docker build -t my-python-base:latest .
```

Now use this base image in your applications:

```dockerfile
FROM my-python-base:latest

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
```

## 📝 Lab Report

Complete this comprehensive analysis:

### Part 1: Image Size Analysis

| Image | Size | Layers | Optimization Used |
|-------|------|--------|-------------------|
| flask-microservice:prod | | | |
| ml-microservice:latest | | | |
| simple-app:bloated | | | |
| simple-app:optimized | | | |
| simple-app:distroless | | | |

**Most effective optimization techniques:**
```
1. ________________________________________________
2. ________________________________________________
3. ________________________________________________
```

### Part 2: Security Assessment

**Vulnerabilities found in vulnerable-app:**
```
High: ____
Medium: ____
Low: ____
```

**Security improvements implemented:**
- [ ] Non-root user
- [ ] Latest base image
- [ ] Minimal attack surface
- [ ] Security scanning
- [ ] Image signing

### Part 3: Performance Analysis

**Build time comparison (seconds):**
- Single-stage build: ____
- Multi-stage build: ____
- With build cache: ____

**Registry operations:**
- Push time: ____
- Pull time: ____
- Authentication: ✅/❌

### Part 4: Python Application Assessment

**Flask Microservice features implemented:**
- [ ] Structured logging
- [ ] Prometheus metrics
- [ ] Health checks
- [ ] Database integration
- [ ] Redis caching
- [ ] Error handling

**ML Service capabilities:**
- [ ] Classification model
- [ ] Regression model
- [ ] Model retraining
- [ ] Metrics collection
- [ ] Model persistence

## ✅ Lab Completion Checklist

- [ ] Built optimized Flask microservice
- [ ] Created ML API with scikit-learn
- [ ] Implemented multi-stage builds
- [ ] Optimized image sizes (compare 3+ approaches)
- [ ] Performed security scanning
- [ ] Set up private registry with authentication
- [ ] Pushed and pulled images from private registry
- [ ] Created custom base image
- [ ] Implemented comprehensive Python applications
- [ ] Documented findings in lab report

## 🎉 Congratulations!

You've mastered advanced Docker image creation and optimization! Key achievements:

- ✅ **Multi-stage builds** for production-ready images
- ✅ **Security scanning** and vulnerability management
- ✅ **Private registry** setup and management
- ✅ **Image optimization** techniques
- ✅ **Python application** containerization
- ✅ **Custom base images** for standardization

## 🧹 Cleanup

```bash
# Stop all containers
docker stop $(docker ps -aq)

# Remove containers
docker rm $(docker ps -aq)

# Remove custom networks
docker network rm microservice-net

# Remove volumes
docker volume rm registry-data

# Remove images (optional)
docker rmi $(docker images -f "reference=*microservice*" -q)
```

## 🚀 Next Steps

1. Complete the [Chapter Checkpoint](../checkpoint.md)
2. Move on to [Chapter 03: Docker Containers](../../03-docker-containers/README.md)
3. Explore production deployment strategies

---

**Need Help?** Check the troubleshooting section or ask in the community forum! 