# 🛒 Project: Microservices E-Commerce Platform

Build a complete microservices-based e-commerce platform using Docker, showcasing real-world patterns and best practices with Python, Node.js, and modern technologies.

## 🎯 Project Overview

This project demonstrates a production-ready microservices architecture with:
- **Frontend**: React SPA
- **API Gateway**: Node.js with Express
- **Microservices**: Python Flask services
- **Databases**: PostgreSQL, Redis, MongoDB
- **Message Queue**: RabbitMQ
- **Monitoring**: Prometheus + Grafana
- **Service Discovery**: Consul (optional)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Load Balancer                           │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                   Frontend (React)                             │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                API Gateway (Node.js)                           │
└─────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┘
      │         │         │         │         │         │
   ┌──▼──┐   ┌─▼─┐   ┌───▼───┐   ┌─▼───┐   ┌─▼──┐   ┌─▼─────┐
   │Auth │   │User│   │Product│   │Order│   │Cart│   │Payment│
   │Service│ │Svc │   │Service│   │ Svc │   │Svc │   │Service│
   │Python│  │Py │   │ Python│   │ Py  │   │Py  │   │ Python│
   └──┬──┘   └─┬─┘   └───┬───┘   └─┬───┘   └─┬──┘   └─┬─────┘
      │        │         │         │         │         │
┌─────▼────────▼─────────▼─────────▼─────────▼─────────▼─────┐
│          Message Queue (RabbitMQ)                         │
└─────────────────────────────────────────────────────────────┘
      │        │         │         │         │         │
   ┌──▼──┐   ┌─▼─┐   ┌───▼───┐   ┌─▼───┐   ┌─▼──┐   ┌─▼─────┐
   │Redis│   │PG │   │MongoDB│   │ PG  │   │Redis  │ Stripe │
   │Cache│   │DB │   │Product│   │Orders│  │Cache│   │ API   │
   └─────┘   └───┘   └───────┘   └─────┘   └────┘   └───────┘
```

## 🚀 Quick Start

```bash
# Clone and setup
git clone <repository>
cd projects/microservices-ecommerce

# Build and start all services
docker-compose up --build

# Access the application
open http://localhost:3000
```

## 📁 Project Structure

```
microservices-ecommerce/
├── frontend/                 # React frontend
├── api-gateway/             # Node.js API Gateway  
├── services/                # Python microservices
│   ├── auth-service/        # Authentication & JWT
│   ├── user-service/        # User management
│   ├── product-service/     # Product catalog
│   ├── order-service/       # Order processing
│   ├── cart-service/        # Shopping cart
│   ├── payment-service/     # Payment processing
│   └── notification-service/ # Email/SMS notifications
├── infrastructure/          # Databases, queues, monitoring
├── docker-compose.yml       # Local development
├── docker-compose.prod.yml  # Production setup
└── k8s/                     # Kubernetes manifests
```

## 🐍 Python Microservices

### 1. Authentication Service

**services/auth-service/app.py:**
```python
from flask import Flask, request, jsonify
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from werkzeug.security import generate_password_hash, check_password_hash
import redis
import psycopg2
from datetime import datetime, timedelta
import os
import logging

app = Flask(__name__)

# Configuration
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'your-secret-key')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=24)

jwt = JWTManager(app)

# Database and Redis connections
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://user:pass@postgres/auth')
REDIS_URL = os.getenv('REDIS_URL', 'redis://redis:6379/0')

redis_client = redis.from_url(REDIS_URL, decode_responses=True)

def get_db_connection():
    return psycopg2.connect(DATABASE_URL)

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'auth'})

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    
    if not data or not data.get('email') or not data.get('password'):
        return jsonify({'error': 'Email and password required'}), 400
    
    email = data['email']
    password = data['password']
    name = data.get('name', '')
    
    # Hash password
    password_hash = generate_password_hash(password)
    
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Check if user exists
        cur.execute("SELECT id FROM users WHERE email = %s", (email,))
        if cur.fetchone():
            return jsonify({'error': 'User already exists'}), 409
        
        # Create user
        cur.execute(
            "INSERT INTO users (email, password_hash, name, created_at) VALUES (%s, %s, %s, %s) RETURNING id",
            (email, password_hash, name, datetime.now())
        )
        user_id = cur.fetchone()[0]
        conn.commit()
        
        # Create JWT token
        access_token = create_access_token(identity=user_id)
        
        # Cache user session
        redis_client.setex(f"user:{user_id}", 86400, email)
        
        return jsonify({
            'access_token': access_token,
            'user_id': user_id,
            'email': email,
            'name': name
        }), 201
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    
    if not data or not data.get('email') or not data.get('password'):
        return jsonify({'error': 'Email and password required'}), 400
    
    email = data['email']
    password = data['password']
    
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Get user
        cur.execute("SELECT id, password_hash, name FROM users WHERE email = %s", (email,))
        user = cur.fetchone()
        
        if not user or not check_password_hash(user[1], password):
            return jsonify({'error': 'Invalid credentials'}), 401
        
        user_id, _, name = user
        
        # Create JWT token
        access_token = create_access_token(identity=user_id)
        
        # Cache user session
        redis_client.setex(f"user:{user_id}", 86400, email)
        
        return jsonify({
            'access_token': access_token,
            'user_id': user_id,
            'email': email,
            'name': name
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/verify', methods=['POST'])
@jwt_required()
def verify_token():
    current_user_id = get_jwt_identity()
    
    # Check if session exists in Redis
    cached_email = redis_client.get(f"user:{current_user_id}")
    if not cached_email:
        return jsonify({'error': 'Session expired'}), 401
    
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT email, name FROM users WHERE id = %s", (current_user_id,))
        user = cur.fetchone()
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        return jsonify({
            'user_id': current_user_id,
            'email': user[0],
            'name': user[1],
            'valid': True
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/logout', methods=['POST'])
@jwt_required()
def logout():
    current_user_id = get_jwt_identity()
    
    # Remove from Redis cache
    redis_client.delete(f"user:{current_user_id}")
    
    return jsonify({'message': 'Logged out successfully'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
```

**services/auth-service/Dockerfile:**
```dockerfile
FROM python:3.11-alpine

RUN apk add --no-cache gcc musl-dev linux-headers postgresql-dev

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN adduser -D -s /bin/sh appuser
USER appuser

EXPOSE 5001

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5001/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5001", "--workers", "2", "app:app"]
```

### 2. Product Service

**services/product-service/app.py:**
```python
from flask import Flask, request, jsonify
import pymongo
import os
from datetime import datetime
from bson import ObjectId
import logging

app = Flask(__name__)

# MongoDB connection
MONGODB_URL = os.getenv('MONGODB_URL', 'mongodb://mongo:27017/products')
client = pymongo.MongoClient(MONGODB_URL)
db = client.products
products_collection = db.products

class JSONEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, ObjectId):
            return str(o)
        return json.JSONEncoder.default(self, o)

app.json_encoder = JSONEncoder

@app.route('/health')
def health():
    try:
        # Test MongoDB connection
        db.command('ping')
        return jsonify({'status': 'healthy', 'service': 'product'})
    except:
        return jsonify({'status': 'unhealthy', 'service': 'product'}), 503

@app.route('/products', methods=['GET'])
def get_products():
    try:
        # Query parameters
        page = int(request.args.get('page', 1))
        limit = int(request.args.get('limit', 20))
        category = request.args.get('category')
        search = request.args.get('search')
        
        # Build query
        query = {}
        if category:
            query['category'] = category
        if search:
            query['$or'] = [
                {'name': {'$regex': search, '$options': 'i'}},
                {'description': {'$regex': search, '$options': 'i'}}
            ]
        
        # Execute query with pagination
        skip = (page - 1) * limit
        products = list(products_collection.find(query).skip(skip).limit(limit))
        total = products_collection.count_documents(query)
        
        return jsonify({
            'products': products,
            'pagination': {
                'page': page,
                'limit': limit,
                'total': total,
                'pages': (total + limit - 1) // limit
            }
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/products/<product_id>')
def get_product(product_id):
    try:
        product = products_collection.find_one({'_id': ObjectId(product_id)})
        if not product:
            return jsonify({'error': 'Product not found'}), 404
        
        return jsonify(product)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/products', methods=['POST'])
def create_product():
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['name', 'price', 'category']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'{field} is required'}), 400
        
        # Add metadata
        data['created_at'] = datetime.now()
        data['updated_at'] = datetime.now()
        data['stock'] = data.get('stock', 0)
        data['active'] = data.get('active', True)
        
        # Insert product
        result = products_collection.insert_one(data)
        
        # Return created product
        product = products_collection.find_one({'_id': result.inserted_id})
        
        return jsonify(product), 201
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/products/<product_id>', methods=['PUT'])
def update_product(product_id):
    try:
        data = request.get_json()
        data['updated_at'] = datetime.now()
        
        result = products_collection.update_one(
            {'_id': ObjectId(product_id)},
            {'$set': data}
        )
        
        if result.matched_count == 0:
            return jsonify({'error': 'Product not found'}), 404
        
        # Return updated product
        product = products_collection.find_one({'_id': ObjectId(product_id)})
        return jsonify(product)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/products/<product_id>/stock', methods=['PATCH'])
def update_stock(product_id):
    try:
        data = request.get_json()
        stock_change = data.get('change', 0)
        
        result = products_collection.update_one(
            {'_id': ObjectId(product_id)},
            {
                '$inc': {'stock': stock_change},
                '$set': {'updated_at': datetime.now()}
            }
        )
        
        if result.matched_count == 0:
            return jsonify({'error': 'Product not found'}), 404
        
        # Return updated product
        product = products_collection.find_one({'_id': ObjectId(product_id)})
        return jsonify(product)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/categories')
def get_categories():
    try:
        categories = products_collection.distinct('category')
        return jsonify({'categories': categories})
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5002, debug=True)
```

### 3. Order Service

**services/order-service/app.py:**
```python
from flask import Flask, request, jsonify
import psycopg2
import pika
import json
import os
from datetime import datetime
from enum import Enum

app = Flask(__name__)

# Configuration
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://user:pass@postgres/orders')
RABBITMQ_URL = os.getenv('RABBITMQ_URL', 'amqp://guest:guest@rabbitmq:5672/')

class OrderStatus(Enum):
    PENDING = 'pending'
    CONFIRMED = 'confirmed'
    SHIPPED = 'shipped'
    DELIVERED = 'delivered'
    CANCELLED = 'cancelled'

def get_db_connection():
    return psycopg2.connect(DATABASE_URL)

def publish_message(queue, message):
    try:
        connection = pika.BlockingConnection(pika.URLParameters(RABBITMQ_URL))
        channel = connection.channel()
        channel.queue_declare(queue=queue, durable=True)
        channel.basic_publish(
            exchange='',
            routing_key=queue,
            body=json.dumps(message),
            properties=pika.BasicProperties(delivery_mode=2)  # Make message persistent
        )
        connection.close()
    except Exception as e:
        app.logger.error(f"Failed to publish message: {e}")

@app.route('/health')
def health():
    try:
        conn = get_db_connection()
        conn.close()
        return jsonify({'status': 'healthy', 'service': 'order'})
    except:
        return jsonify({'status': 'unhealthy', 'service': 'order'}), 503

@app.route('/orders', methods=['POST'])
def create_order():
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['user_id', 'items', 'shipping_address']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'{field} is required'}), 400
        
        user_id = data['user_id']
        items = data['items']
        shipping_address = data['shipping_address']
        
        # Calculate total
        total_amount = sum(item['price'] * item['quantity'] for item in items)
        
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Create order
        cur.execute("""
            INSERT INTO orders (user_id, total_amount, status, shipping_address, created_at)
            VALUES (%s, %s, %s, %s, %s) RETURNING id
        """, (user_id, total_amount, OrderStatus.PENDING.value, json.dumps(shipping_address), datetime.now()))
        
        order_id = cur.fetchone()[0]
        
        # Add order items
        for item in items:
            cur.execute("""
                INSERT INTO order_items (order_id, product_id, quantity, price)
                VALUES (%s, %s, %s, %s)
            """, (order_id, item['product_id'], item['quantity'], item['price']))
        
        conn.commit()
        
        # Publish order created event
        order_event = {
            'event_type': 'order_created',
            'order_id': order_id,
            'user_id': user_id,
            'total_amount': float(total_amount),
            'items': items
        }
        publish_message('order_events', order_event)
        
        # Get complete order
        order = get_order_by_id(order_id)
        
        return jsonify(order), 201
        
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/orders/<int:order_id>')
def get_order(order_id):
    try:
        order = get_order_by_id(order_id)
        if not order:
            return jsonify({'error': 'Order not found'}), 404
        
        return jsonify(order)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/orders/user/<int:user_id>')
def get_user_orders(user_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        cur.execute("""
            SELECT o.*, 
                   json_agg(json_build_object(
                       'product_id', oi.product_id,
                       'quantity', oi.quantity,
                       'price', oi.price
                   )) as items
            FROM orders o
            LEFT JOIN order_items oi ON o.id = oi.order_id
            WHERE o.user_id = %s
            GROUP BY o.id
            ORDER BY o.created_at DESC
        """, (user_id,))
        
        orders = []
        for row in cur.fetchall():
            order = {
                'id': row[0],
                'user_id': row[1],
                'total_amount': float(row[2]),
                'status': row[3],
                'shipping_address': json.loads(row[4]),
                'created_at': row[5].isoformat(),
                'items': row[6] if row[6] else []
            }
            orders.append(order)
        
        return jsonify({'orders': orders})
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

@app.route('/orders/<int:order_id>/status', methods=['PATCH'])
def update_order_status(order_id):
    try:
        data = request.get_json()
        new_status = data.get('status')
        
        if new_status not in [status.value for status in OrderStatus]:
            return jsonify({'error': 'Invalid status'}), 400
        
        conn = get_db_connection()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE orders SET status = %s, updated_at = %s
            WHERE id = %s RETURNING user_id
        """, (new_status, datetime.now(), order_id))
        
        result = cur.fetchone()
        if not result:
            return jsonify({'error': 'Order not found'}), 404
        
        user_id = result[0]
        conn.commit()
        
        # Publish status change event
        status_event = {
            'event_type': 'order_status_changed',
            'order_id': order_id,
            'user_id': user_id,
            'new_status': new_status
        }
        publish_message('order_events', status_event)
        
        # Return updated order
        order = get_order_by_id(order_id)
        return jsonify(order)
        
    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({'error': str(e)}), 500
    finally:
        if conn:
            conn.close()

def get_order_by_id(order_id):
    conn = get_db_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT o.*,
               json_agg(json_build_object(
                   'product_id', oi.product_id,
                   'quantity', oi.quantity,
                   'price', oi.price
               )) as items
        FROM orders o
        LEFT JOIN order_items oi ON o.id = oi.order_id
        WHERE o.id = %s
        GROUP BY o.id
    """, (order_id,))
    
    row = cur.fetchone()
    conn.close()
    
    if not row:
        return None
    
    return {
        'id': row[0],
        'user_id': row[1],
        'total_amount': float(row[2]),
        'status': row[3],
        'shipping_address': json.loads(row[4]),
        'created_at': row[5].isoformat(),
        'updated_at': row[6].isoformat() if row[6] else None,
        'items': row[7] if row[7] else []
    }

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5003, debug=True)
```

## 🐳 Docker Compose Setup

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  # Frontend
  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      - REACT_APP_API_URL=http://localhost:4000
    depends_on:
      - api-gateway

  # API Gateway
  api-gateway:
    build: ./api-gateway
    ports:
      - "4000:4000"
    environment:
      - AUTH_SERVICE_URL=http://auth-service:5001
      - USER_SERVICE_URL=http://user-service:5002
      - PRODUCT_SERVICE_URL=http://product-service:5003
      - ORDER_SERVICE_URL=http://order-service:5004
      - CART_SERVICE_URL=http://cart-service:5005
    depends_on:
      - auth-service
      - user-service
      - product-service
      - order-service
      - cart-service

  # Python Microservices
  auth-service:
    build: ./services/auth-service
    environment:
      - DATABASE_URL=postgresql://auth_user:auth_pass@auth-db/auth
      - REDIS_URL=redis://redis:6379/0
      - JWT_SECRET_KEY=your-super-secret-jwt-key
    depends_on:
      - auth-db
      - redis

  user-service:
    build: ./services/user-service
    environment:
      - DATABASE_URL=postgresql://user_user:user_pass@user-db/users
      - REDIS_URL=redis://redis:6379/1
    depends_on:
      - user-db
      - redis

  product-service:
    build: ./services/product-service
    environment:
      - MONGODB_URL=mongodb://mongo:27017/products
    depends_on:
      - mongo

  order-service:
    build: ./services/order-service
    environment:
      - DATABASE_URL=postgresql://order_user:order_pass@order-db/orders
      - RABBITMQ_URL=amqp://guest:guest@rabbitmq:5672/
    depends_on:
      - order-db
      - rabbitmq

  cart-service:
    build: ./services/cart-service
    environment:
      - REDIS_URL=redis://redis:6379/2
    depends_on:
      - redis

  payment-service:
    build: ./services/payment-service
    environment:
      - DATABASE_URL=postgresql://payment_user:payment_pass@payment-db/payments
      - STRIPE_SECRET_KEY=sk_test_your_stripe_key
      - RABBITMQ_URL=amqp://guest:guest@rabbitmq:5672/
    depends_on:
      - payment-db
      - rabbitmq

  notification-service:
    build: ./services/notification-service
    environment:
      - RABBITMQ_URL=amqp://guest:guest@rabbitmq:5672/
      - SMTP_HOST=smtp.gmail.com
      - SMTP_PORT=587
      - SMTP_USER=your-email@gmail.com
      - SMTP_PASS=your-app-password
    depends_on:
      - rabbitmq

  # Databases
  auth-db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=auth_user
      - POSTGRES_PASSWORD=auth_pass
      - POSTGRES_DB=auth
    volumes:
      - auth_db_data:/var/lib/postgresql/data

  user-db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=user_user
      - POSTGRES_PASSWORD=user_pass
      - POSTGRES_DB=users
    volumes:
      - user_db_data:/var/lib/postgresql/data

  order-db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=order_user
      - POSTGRES_PASSWORD=order_pass
      - POSTGRES_DB=orders
    volumes:
      - order_db_data:/var/lib/postgresql/data

  payment-db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=payment_user
      - POSTGRES_PASSWORD=payment_pass
      - POSTGRES_DB=payments
    volumes:
      - payment_db_data:/var/lib/postgresql/data

  mongo:
    image: mongo:6
    volumes:
      - mongo_data:/data/db

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

  rabbitmq:
    image: rabbitmq:3-management-alpine
    ports:
      - "15672:15672"  # Management UI
    environment:
      - RABBITMQ_DEFAULT_USER=admin
      - RABBITMQ_DEFAULT_PASS=admin
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq

  # Monitoring
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./infrastructure/prometheus:/etc/prometheus
      - prometheus_data:/prometheus

  grafana:
    image: grafana/grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  auth_db_data:
  user_db_data:
  order_db_data:
  payment_db_data:
  mongo_data:
  redis_data:
  rabbitmq_data:
  prometheus_data:
  grafana_data:

networks:
  default:
    driver: bridge
```

## 🚀 Getting Started

### 1. Setup Project Structure

```bash
# Create project structure
./scripts/setup-project.sh

# Initialize databases
./scripts/init-databases.sh

# Seed sample data
./scripts/seed-data.sh
```

### 2. Development Mode

```bash
# Start infrastructure first
docker-compose up -d postgres mongo redis rabbitmq

# Start services
docker-compose up --build

# View logs
docker-compose logs -f auth-service
```

### 3. Production Deployment

```bash
# Build production images
docker-compose -f docker-compose.prod.yml build

# Deploy to production
docker-compose -f docker-compose.prod.yml up -d

# Scale services
docker-compose -f docker-compose.prod.yml up -d --scale product-service=3
```

## 📊 Monitoring & Observability

### Prometheus Metrics
- Service health and performance
- Request rates and latencies  
- Business metrics (orders, revenue)

### Grafana Dashboards
- System overview
- Service-specific metrics
- Business intelligence

### Logging
- Structured JSON logging
- Centralized log aggregation
- Error tracking and alerts

## 🔒 Security Features

- JWT-based authentication
- Service-to-service encryption
- Database connection security
- Input validation and sanitization
- Rate limiting
- CORS protection

## 🧪 Testing Strategy

### Unit Tests
```bash
# Run service tests
cd services/auth-service
python -m pytest tests/

# Run all service tests
./scripts/run-tests.sh
```

### Integration Tests
```bash
# Test service interactions
docker-compose -f docker-compose.test.yml up --abort-on-container-exit
```

### Load Testing
```bash
# Apache Bench
ab -n 1000 -c 10 http://localhost:4000/api/products

# Artillery.js
artillery run load-tests/products-load-test.yml
```

## 📚 Key Learning Outcomes

After completing this project, you'll understand:

✅ **Microservices Architecture** - Service decomposition and communication
✅ **Docker Multi-Service Applications** - Complex container orchestration  
✅ **Python Flask APIs** - RESTful service development
✅ **Database Design** - Multi-database strategies
✅ **Message Queues** - Asynchronous communication patterns
✅ **API Gateway Patterns** - Request routing and aggregation
✅ **Monitoring & Observability** - Production-ready monitoring
✅ **Security** - Authentication and authorization
✅ **Testing** - Comprehensive testing strategies
✅ **CI/CD** - Automated deployment pipelines

## 🔄 Extension Ideas

- **Service Mesh**: Implement Istio or Linkerd
- **Event Sourcing**: Add event-driven architecture
- **CQRS**: Separate read/write models
- **Kubernetes**: Deploy to K8s cluster
- **Serverless**: Convert to Lambda functions
- **GraphQL**: Add GraphQL API gateway
- **Machine Learning**: Add recommendation service

---

This project demonstrates real-world microservices patterns and provides a solid foundation for building scalable, maintainable applications with Docker and Python! 