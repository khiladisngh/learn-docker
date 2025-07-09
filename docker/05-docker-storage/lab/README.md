# 🧪 Lab 05: Advanced Docker Storage Management

In this lab, you'll practice advanced Docker storage concepts including volumes, bind mounts, backup strategies, and storage monitoring.

## 🎯 Lab Objectives

By completing this lab, you will:
- Create and manage different types of Docker storage
- Implement data persistence strategies
- Practice backup and restore procedures
- Monitor storage performance and usage
- Configure storage security and optimization

## 📋 Prerequisites

- Docker Engine installed and running
- Basic understanding of Docker containers
- Text editor (VS Code, nano, vim)
- Understanding of file systems and permissions

## 🚀 Lab Exercises

### Exercise 1: Docker Volume Management

**Goal:** Master Docker volume creation, configuration, and management.

#### Step 1: Basic Volume Operations

```bash
# Create named volumes
docker volume create webapp-data
docker volume create database-data
docker volume create logs-data

# List all volumes
docker volume ls

# Inspect volume details
docker volume inspect webapp-data

# View volume location on host
docker volume inspect webapp-data --format='{{.Mountpoint}}'
```

#### Step 2: Advanced Volume Configuration

```bash
# Create volume with labels
docker volume create \
  --label environment=production \
  --label backup=daily \
  --label team=backend \
  production-data

# Create volume with driver options
docker volume create \
  --driver local \
  --opt type=tmpfs \
  --opt tmpfs-size=100m \
  temp-storage

# Create NFS volume (if NFS server available)
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=nfs.example.com,rw \
  --opt device=:/exports/shared \
  nfs-storage
```

#### Step 3: Volume Usage Patterns

```bash
# Test webapp with persistent data
docker run -d --name webapp \
  -v webapp-data:/app/data \
  -v logs-data:/app/logs \
  -p 8080:80 \
  nginx:alpine

# Add some data to the volume
docker exec webapp sh -c "echo 'Hello from Volume!' > /app/data/test.txt"
docker exec webapp sh -c "echo 'Log entry 1' > /app/logs/app.log"

# Stop and remove container
docker stop webapp
docker rm webapp

# Start new container with same volumes
docker run -d --name webapp-new \
  -v webapp-data:/app/data \
  -v logs-data:/app/logs \
  -p 8080:80 \
  nginx:alpine

# Verify data persistence
docker exec webapp-new cat /app/data/test.txt
docker exec webapp-new cat /app/logs/app.log
```

### Exercise 2: Bind Mounts and tmpfs

**Goal:** Practice bind mounts and tmpfs for different storage scenarios.

#### Step 1: Bind Mount Configuration

```bash
# Create host directories
mkdir -p /tmp/docker-lab/{config,data,logs}

# Create configuration file
cat > /tmp/docker-lab/config/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
    
    location /api {
        return 200 "API endpoint from bind mount config\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Create custom index page
cat > /tmp/docker-lab/data/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Bind Mount Demo</title>
</head>
<body>
    <h1>Hello from Bind Mount!</h1>
    <p>This file is served from a bind mount.</p>
</body>
</html>
EOF

# Run container with bind mounts
docker run -d --name bindmount-demo \
  -v /tmp/docker-lab/config/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
  -v /tmp/docker-lab/data:/usr/share/nginx/html \
  -v /tmp/docker-lab/logs:/var/log/nginx \
  -p 8081:80 \
  nginx:alpine

# Test bind mount functionality
curl http://localhost:8081/
curl http://localhost:8081/api

# Modify file on host and see changes
echo "<p>Updated from host!</p>" >> /tmp/docker-lab/data/index.html
curl http://localhost:8081/
```

#### Step 2: tmpfs Mounts

```bash
# Run container with tmpfs for temporary data
docker run -d --name tmpfs-demo \
  --tmpfs /tmp:size=100m,noexec \
  --tmpfs /var/cache:size=50m \
  -v webapp-data:/app/data \
  alpine:latest sleep 3600

# Test tmpfs behavior
docker exec tmpfs-demo sh -c "echo 'Temporary data' > /tmp/temp.txt"
docker exec tmpfs-demo sh -c "echo 'Cache data' > /var/cache/cache.txt"
docker exec tmpfs-demo sh -c "echo 'Persistent data' > /app/data/persistent.txt"

# Check tmpfs usage
docker exec tmpfs-demo df -h

# Restart container and check data persistence
docker restart tmpfs-demo
sleep 5

# Check what survived restart
docker exec tmpfs-demo ls -la /tmp/          # Should be empty
docker exec tmpfs-demo ls -la /var/cache/    # Should be empty
docker exec tmpfs-demo ls -la /app/data/     # Should contain persistent.txt
```

### Exercise 3: Database Storage Patterns

**Goal:** Implement proper storage strategies for database containers.

#### Step 1: PostgreSQL with Volume

```bash
# Create PostgreSQL data volume
docker volume create postgres-data

# Create PostgreSQL container with persistent storage
docker run -d --name postgres-db \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=testuser \
  -e POSTGRES_PASSWORD=testpass \
  -v postgres-data:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:13

# Wait for database to initialize
sleep 10

# Create test data
docker exec postgres-db psql -U testuser -d testdb -c "
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (name, email) VALUES 
('Alice', 'alice@example.com'),
('Bob', 'bob@example.com'),
('Charlie', 'charlie@example.com');
"

# Verify data
docker exec postgres-db psql -U testuser -d testdb -c "SELECT * FROM users;"
```

#### Step 2: MySQL with Bind Mounts

```bash
# Create MySQL directories
mkdir -p /tmp/mysql/{data,config,logs}

# Create MySQL configuration
cat > /tmp/mysql/config/my.cnf << 'EOF'
[mysqld]
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
max_connections = 100
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
EOF

# Run MySQL with bind mounts
docker run -d --name mysql-db \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=testdb \
  -e MYSQL_USER=testuser \
  -e MYSQL_PASSWORD=testpass \
  -v /tmp/mysql/data:/var/lib/mysql \
  -v /tmp/mysql/config:/etc/mysql/conf.d:ro \
  -v /tmp/mysql/logs:/var/log/mysql \
  -p 3306:3306 \
  mysql:8.0

# Wait for MySQL to initialize
sleep 30

# Create test data
docker exec mysql-db mysql -u testuser -ptestpass testdb -e "
CREATE TABLE products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    price DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO products (name, price) VALUES 
('Widget A', 19.99),
('Widget B', 29.99),
('Widget C', 39.99);
"

# Verify data
docker exec mysql-db mysql -u testuser -ptestpass testdb -e "SELECT * FROM products;"
```

### Exercise 4: Backup and Restore Procedures

**Goal:** Implement comprehensive backup and restore strategies.

#### Step 1: Volume Backup

```bash
# Create backup directory
mkdir -p /tmp/backups

# Backup PostgreSQL volume using tar
docker run --rm \
  -v postgres-data:/data:ro \
  -v /tmp/backups:/backup \
  alpine:latest \
  tar czf /backup/postgres-volume-$(date +%Y%m%d_%H%M%S).tar.gz -C /data .

# Backup MySQL bind mount data
tar czf /tmp/backups/mysql-data-$(date +%Y%m%d_%H%M%S).tar.gz -C /tmp/mysql/data .

# List backups
ls -la /tmp/backups/
```

#### Step 2: Database Logical Backup

```bash
# PostgreSQL database dump
docker exec postgres-db pg_dump -U testuser testdb > /tmp/backups/postgres-dump-$(date +%Y%m%d_%H%M%S).sql

# MySQL database dump
docker exec mysql-db mysqldump -u testuser -ptestpass testdb > /tmp/backups/mysql-dump-$(date +%Y%m%d_%H%M%S).sql

# Verify backup files
ls -la /tmp/backups/*.sql
```

#### Step 3: Automated Backup Script

```python
# Create backup automation script
cat > backup_script.py << 'EOF'
#!/usr/bin/env python3
import subprocess
import datetime
import os
import shutil
import gzip

class DockerBackupManager:
    def __init__(self, backup_dir="/tmp/backups"):
        self.backup_dir = backup_dir
        self.timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        os.makedirs(backup_dir, exist_ok=True)
    
    def backup_volume(self, volume_name, compress=True):
        """Backup Docker volume"""
        backup_file = f"{self.backup_dir}/{volume_name}_{self.timestamp}.tar"
        
        try:
            cmd = [
                "docker", "run", "--rm",
                "-v", f"{volume_name}:/data:ro",
                "-v", f"{self.backup_dir}:/backup",
                "alpine:latest",
                "tar", "cf", f"/backup/{os.path.basename(backup_file)}", "-C", "/data", "."
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                if compress:
                    with open(backup_file, 'rb') as f_in:
                        with gzip.open(f"{backup_file}.gz", 'wb') as f_out:
                            shutil.copyfileobj(f_in, f_out)
                    os.remove(backup_file)
                    backup_file = f"{backup_file}.gz"
                
                print(f"✅ Volume backup completed: {backup_file}")
                return backup_file
            else:
                print(f"❌ Volume backup failed: {result.stderr}")
                return None
                
        except Exception as e:
            print(f"❌ Backup error: {e}")
            return None
    
    def backup_database(self, container_name, db_type, database, username, password=None):
        """Backup database"""
        backup_file = f"{self.backup_dir}/{container_name}_{database}_{self.timestamp}.sql"
        
        try:
            if db_type.lower() == "postgresql":
                cmd = [
                    "docker", "exec", container_name,
                    "pg_dump", "-U", username, "-d", database
                ]
            elif db_type.lower() == "mysql":
                cmd = [
                    "docker", "exec", container_name,
                    "mysqldump", "-u", username, f"-p{password}", database
                ]
            else:
                raise ValueError(f"Unsupported database type: {db_type}")
            
            with open(backup_file, 'w') as f:
                result = subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, text=True)
            
            if result.returncode == 0:
                # Compress SQL backup
                with open(backup_file, 'rb') as f_in:
                    with gzip.open(f"{backup_file}.gz", 'wb') as f_out:
                        shutil.copyfileobj(f_in, f_out)
                os.remove(backup_file)
                
                print(f"✅ Database backup completed: {backup_file}.gz")
                return f"{backup_file}.gz"
            else:
                print(f"❌ Database backup failed: {result.stderr}")
                return None
                
        except Exception as e:
            print(f"❌ Database backup error: {e}")
            return None
    
    def restore_volume(self, volume_name, backup_file):
        """Restore Docker volume from backup"""
        try:
            # Handle compressed files
            if backup_file.endswith('.gz'):
                cmd = [
                    "docker", "run", "--rm",
                    "-v", f"{volume_name}:/data",
                    "-v", f"{os.path.dirname(backup_file)}:/backup",
                    "alpine:latest",
                    "sh", "-c", f"cd /data && tar xzf /backup/{os.path.basename(backup_file)}"
                ]
            else:
                cmd = [
                    "docker", "run", "--rm",
                    "-v", f"{volume_name}:/data",
                    "-v", f"{os.path.dirname(backup_file)}:/backup",
                    "alpine:latest",
                    "sh", "-c", f"cd /data && tar xf /backup/{os.path.basename(backup_file)}"
                ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                print(f"✅ Volume restore completed: {volume_name}")
                return True
            else:
                print(f"❌ Volume restore failed: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"❌ Restore error: {e}")
            return False

if __name__ == "__main__":
    backup_manager = DockerBackupManager()
    
    print("🚀 Starting backup process...")
    
    # Backup volumes
    backup_manager.backup_volume("postgres-data")
    backup_manager.backup_volume("webapp-data")
    backup_manager.backup_volume("logs-data")
    
    # Backup databases
    backup_manager.backup_database("postgres-db", "postgresql", "testdb", "testuser")
    backup_manager.backup_database("mysql-db", "mysql", "testdb", "testuser", "testpass")
    
    print("🎉 Backup process completed!")
EOF

# Run backup script
python3 backup_script.py
```

#### Step 4: Disaster Recovery Testing

```bash
# Test disaster recovery by simulating data loss
echo "🧪 Testing disaster recovery..."

# Stop and remove database containers
docker stop postgres-db mysql-db
docker rm postgres-db mysql-db

# Remove volumes (simulate data loss)
docker volume rm postgres-data

# Recreate volume
docker volume create postgres-data

# Restore PostgreSQL from volume backup
POSTGRES_BACKUP=$(ls -t /tmp/backups/postgres-data_*.tar.gz | head -1)
docker run --rm \
  -v postgres-data:/data \
  -v /tmp/backups:/backup \
  alpine:latest \
  tar xzf /backup/$(basename $POSTGRES_BACKUP) -C /data

# Restart PostgreSQL container
docker run -d --name postgres-db \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=testuser \
  -e POSTGRES_PASSWORD=testpass \
  -v postgres-data:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:13

# Wait for database to start
sleep 15

# Verify data recovery
docker exec postgres-db psql -U testuser -d testdb -c "SELECT * FROM users;" || echo "Data not found, trying SQL restore..."

# If volume restore didn't work, try SQL restore
if [ $? -ne 0 ]; then
    POSTGRES_SQL_BACKUP=$(ls -t /tmp/backups/postgres-db_testdb_*.sql.gz | head -1)
    gunzip -c $POSTGRES_SQL_BACKUP | docker exec -i postgres-db psql -U testuser -d testdb
    
    # Verify again
    docker exec postgres-db psql -U testuser -d testdb -c "SELECT * FROM users;"
fi

echo "✅ Disaster recovery test completed!"
```

### Exercise 5: Storage Monitoring and Performance

**Goal:** Monitor storage usage and optimize performance.

#### Step 1: Storage Usage Monitoring

```python
# Create storage monitoring script
cat > storage_monitor.py << 'EOF'
#!/usr/bin/env python3
import docker
import psutil
import time
import json
from datetime import datetime

class StorageMonitor:
    def __init__(self):
        self.client = docker.from_env()
    
    def get_volume_usage(self, volume_name):
        """Get volume usage statistics"""
        try:
            container = self.client.containers.run(
                "alpine:latest",
                command="df -h /data",
                volumes={volume_name: {'bind': '/data', 'mode': 'ro'}},
                remove=True,
                detach=False,
                stdout=True,
                stderr=True
            )
            
            output = container.decode().strip()
            lines = output.split('\n')
            
            if len(lines) >= 2:
                parts = lines[1].split()
                if len(parts) >= 5:
                    return {
                        'volume': volume_name,
                        'filesystem': parts[0],
                        'size': parts[1],
                        'used': parts[2],
                        'available': parts[3],
                        'use_percent': int(parts[4].rstrip('%')),
                        'mount_point': parts[5] if len(parts) > 5 else '/data'
                    }
        except Exception as e:
            return {'volume': volume_name, 'error': str(e)}
        
        return None
    
    def get_container_io_stats(self):
        """Get container I/O statistics"""
        stats = []
        
        for container in self.client.containers.list():
            try:
                container_stats = container.stats(stream=False)
                blkio_stats = container_stats.get('blkio_stats', {})
                
                # Parse block I/O statistics
                io_service_bytes = blkio_stats.get('io_service_bytes_recursive', [])
                read_bytes = 0
                write_bytes = 0
                
                for item in io_service_bytes:
                    if item['op'] == 'Read':
                        read_bytes += item['value']
                    elif item['op'] == 'Write':
                        write_bytes += item['value']
                
                stats.append({
                    'container': container.name,
                    'read_bytes': read_bytes,
                    'write_bytes': write_bytes,
                    'read_mb': round(read_bytes / (1024 * 1024), 2),
                    'write_mb': round(write_bytes / (1024 * 1024), 2)
                })
                
            except Exception as e:
                stats.append({
                    'container': container.name,
                    'error': str(e)
                })
        
        return stats
    
    def generate_report(self):
        """Generate comprehensive storage report"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'volumes': [],
            'containers': [],
            'host_disks': []
        }
        
        # Volume usage
        for volume in self.client.volumes.list():
            usage = self.get_volume_usage(volume.name)
            if usage:
                report['volumes'].append(usage)
        
        # Container I/O
        report['containers'] = self.get_container_io_stats()
        
        # Host disk usage
        for partition in psutil.disk_partitions():
            try:
                usage = psutil.disk_usage(partition.mountpoint)
                report['host_disks'].append({
                    'device': partition.device,
                    'mountpoint': partition.mountpoint,
                    'fstype': partition.fstype,
                    'total_gb': round(usage.total / (1024**3), 2),
                    'used_gb': round(usage.used / (1024**3), 2),
                    'free_gb': round(usage.free / (1024**3), 2),
                    'percent_used': round((usage.used / usage.total) * 100, 1)
                })
            except:
                pass
        
        return report
    
    def print_report(self, report):
        """Print formatted storage report"""
        print(f"\n📊 Storage Report - {report['timestamp']}")
        print("=" * 60)
        
        # Volumes
        print("\n💾 Docker Volumes:")
        for volume in report['volumes']:
            if 'error' not in volume:
                status = "⚠️" if volume['use_percent'] > 80 else "✅"
                print(f"{status} {volume['volume']}: {volume['used']}/{volume['size']} ({volume['use_percent']}%)")
            else:
                print(f"❌ {volume['volume']}: {volume['error']}")
        
        # Container I/O
        print("\n📈 Container I/O:")
        for container in report['containers']:
            if 'error' not in container:
                print(f"📦 {container['container']}: R:{container['read_mb']}MB W:{container['write_mb']}MB")
            else:
                print(f"❌ {container['container']}: {container['error']}")
        
        # Host disks
        print("\n🖥️ Host Storage:")
        for disk in report['host_disks']:
            status = "⚠️" if disk['percent_used'] > 80 else "✅"
            print(f"{status} {disk['mountpoint']}: {disk['used_gb']}GB/{disk['total_gb']}GB ({disk['percent_used']}%)")

if __name__ == "__main__":
    monitor = StorageMonitor()
    report = monitor.generate_report()
    monitor.print_report(report)
    
    # Save detailed report
    with open(f"/tmp/storage-report-{int(time.time())}.json", 'w') as f:
        json.dump(report, f, indent=2)
    
    print("\n✅ Detailed report saved to /tmp/")
EOF

# Run storage monitoring
python3 storage_monitor.py
```

#### Step 2: Performance Testing

```bash
# Create performance test script
cat > storage_performance_test.sh << 'EOF'
#!/bin/bash

echo "🚀 Docker Storage Performance Test"
echo "================================="

# Test function
test_storage_performance() {
    local storage_type=$1
    local mount_spec=$2
    local container_name="perf-test-$storage_type"
    
    echo ""
    echo "Testing $storage_type storage..."
    
    # Start container with specific storage
    docker run -d --name $container_name \
        $mount_spec \
        alpine:latest sleep 3600
    
    # Write test
    echo "  📝 Write test (100MB):"
    docker exec $container_name time sh -c "dd if=/dev/zero of=/test/write_test.dat bs=1M count=100 oflag=dsync 2>&1" | grep -E "(copied|real)"
    
    # Read test
    echo "  📖 Read test:"
    docker exec $container_name time sh -c "dd if=/test/write_test.dat of=/dev/null bs=1M 2>&1" | grep -E "(copied|real)"
    
    # Random I/O test
    echo "  🔀 Random I/O test:"
    docker exec $container_name time sh -c "for i in \$(seq 1 1000); do dd if=/dev/urandom of=/test/random_\$i.dat bs=1K count=1 2>/dev/null; done" | grep real
    
    # Cleanup
    docker stop $container_name >/dev/null 2>&1
    docker rm $container_name >/dev/null 2>&1
    
    echo "  ✅ $storage_type test completed"
}

# Create test volume and directory
docker volume create perf-test-volume >/dev/null 2>&1
mkdir -p /tmp/perf-test

# Test different storage types
test_storage_performance "volume" "-v perf-test-volume:/test"
test_storage_performance "bind-mount" "-v /tmp/perf-test:/test"
test_storage_performance "tmpfs" "--tmpfs /test:size=200m"

# Cleanup
docker volume rm perf-test-volume >/dev/null 2>&1
rm -rf /tmp/perf-test

echo ""
echo "🎉 Performance testing completed!"
EOF

chmod +x storage_performance_test.sh
./storage_performance_test.sh
```

## ✅ Lab Verification

### Verification Steps

1. **Volume Management Verification:**
   ```bash
   # Check volumes exist
   docker volume ls | grep -E "(webapp-data|database-data|logs-data)"
   
   # Verify data persistence
   docker exec webapp-new cat /app/data/test.txt
   ```

2. **Bind Mount Verification:**
   ```bash
   # Test bind mount functionality
   curl http://localhost:8081/ | grep "Bind Mount"
   ```

3. **Database Storage Verification:**
   ```bash
   # Verify PostgreSQL data
   docker exec postgres-db psql -U testuser -d testdb -c "SELECT count(*) FROM users;"
   
   # Verify MySQL data
   docker exec mysql-db mysql -u testuser -ptestpass testdb -e "SELECT count(*) FROM products;"
   ```

4. **Backup Verification:**
   ```bash
   # Check backup files exist
   ls -la /tmp/backups/
   
   # Verify backup script functionality
   python3 backup_script.py
   ```

### Expected Outcomes

- Named volumes should provide persistent storage across container restarts
- Bind mounts should allow real-time file system access from host
- tmpfs mounts should provide fast memory-based storage
- Database containers should maintain data consistency
- Backup and restore procedures should work reliably
- Monitoring tools should provide accurate storage statistics

## 🧹 Cleanup

```bash
# Stop and remove all containers
docker stop $(docker ps -aq --filter "name=*-demo") 2>/dev/null || true
docker stop $(docker ps -aq --filter "name=*-db") 2>/dev/null || true
docker stop $(docker ps -aq --filter "name=webapp") 2>/dev/null || true
docker stop $(docker ps -aq --filter "name=perf-test") 2>/dev/null || true

docker rm $(docker ps -aq --filter "name=*-demo") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=*-db") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=webapp") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=perf-test") 2>/dev/null || true

# Remove volumes
docker volume rm webapp-data database-data logs-data 2>/dev/null || true
docker volume rm postgres-data production-data temp-storage 2>/dev/null || true
docker volume rm perf-test-volume 2>/dev/null || true

# Remove host directories
rm -rf /tmp/docker-lab /tmp/mysql /tmp/backups /tmp/perf-test

# Remove lab files
rm -f backup_script.py storage_monitor.py storage_performance_test.sh

echo "🧹 Lab cleanup completed!"
```

## 📚 Additional Challenges

1. **Implement automated backup rotation** with retention policies
2. **Create a storage monitoring dashboard** using Prometheus and Grafana
3. **Set up distributed storage** using Docker Swarm and shared filesystems
4. **Implement encrypted volume** using dm-crypt or similar technologies
5. **Create storage performance optimization** guides for different workloads

## 🎯 Lab Summary

In this lab, you:
- ✅ Created and managed different types of Docker storage
- ✅ Implemented persistent data strategies for databases
- ✅ Built comprehensive backup and restore procedures
- ✅ Developed storage monitoring and alerting systems
- ✅ Tested storage performance across different configurations

**🎉 Congratulations!** You've mastered Docker storage management essential for production environments.

---

**[⬅️ Back to Chapter 05](../README.md)** | **[Next: Checkpoint ➡️](../checkpoint.md)** 