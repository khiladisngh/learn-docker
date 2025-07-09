# 💾 Chapter 05: Docker Storage - Advanced Data Management & Persistence

Welcome to advanced Docker storage management! In this chapter, you'll master persistent data storage, volume management, storage drivers, and production-ready data strategies.

## 🎯 Learning Objectives

By the end of this chapter, you will:
- ✅ Understand Docker storage architecture and drivers
- ✅ Master volumes, bind mounts, and tmpfs mounts
- ✅ Implement persistent data strategies for production
- ✅ Optimize storage performance and security
- ✅ Manage data backup and restore procedures
- ✅ Configure storage for different use cases

## 🏗️ Docker Storage Architecture

### Storage Types Overview

```
┌─────────────────────────────────────────┐
│            Container Layer             │ ← Read/Write (ephemeral)
├─────────────────────────────────────────┤
│            Image Layers                │ ← Read-Only
│  ┌─────────────────────────────────────┐ │
│  │        Application Layer            │ │
│  ├─────────────────────────────────────┤ │
│  │        Dependencies Layer           │ │
│  ├─────────────────────────────────────┤ │
│  │        Base Image Layer             │ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘

External Storage Options:
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│     Volumes     │ │   Bind Mounts   │ │   tmpfs Mounts  │
│  (Docker-managed)│ │  (Host-managed) │ │   (Memory)      │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

### Storage Driver Architecture

Docker uses pluggable storage drivers to manage image layers:

- **overlay2** (recommended): Efficient union filesystem
- **aufs**: Legacy union filesystem
- **devicemapper**: Block-level storage
- **btrfs**: Advanced filesystem features
- **zfs**: Enterprise-grade filesystem
- **vfs**: Simple directory-based (testing only)

## 📦 Docker Volumes

### Volume Basics

```bash
# Create named volume
docker volume create myvolume

# List volumes
docker volume ls

# Inspect volume
docker volume inspect myvolume

# Remove volume
docker volume rm myvolume

# Prune unused volumes
docker volume prune
```

### Volume Types and Usage

**Anonymous volumes:**
```bash
# Docker creates random name
docker run -d -v /data nginx:alpine
```

**Named volumes:**
```bash
# Create and use named volume
docker volume create webapp-data
docker run -d -v webapp-data:/data nginx:alpine
```

**Volume with driver options:**
```bash
# Create volume with specific driver
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=192.168.1.100,rw \
  --opt device=:/path/to/share \
  nfs-volume
```

### Advanced Volume Configuration

```bash
# Volume with specific options
docker volume create \
  --driver local \
  --opt type=ext4 \
  --opt device=/dev/sdb1 \
  --label environment=production \
  --label backup=daily \
  production-data

# Volume with size limit (requires storage driver support)
docker volume create \
  --driver local \
  --opt type=tmpfs \
  --opt tmpfs-size=100m \
  temp-volume
```

## 🔗 Bind Mounts

### Bind Mount Basics

```bash
# Basic bind mount
docker run -d -v /host/path:/container/path nginx:alpine

# Bind mount with options
docker run -d \
  -v /host/data:/app/data:ro \
  -v /host/logs:/app/logs:rw \
  myapp:latest

# Bind mount with specific options
docker run -d \
  --mount type=bind,source=/host/data,target=/app/data,readonly \
  myapp:latest
```

### Bind Mount vs Volumes

| Feature | Volumes | Bind Mounts |
|---------|---------|-------------|
| Storage Location | Docker-managed | Host filesystem |
| Backup | Docker tools | Host tools |
| Performance | Optimized | Native |
| Portability | High | Low |
| Security | Isolated | Host access |
| Management | Docker CLI | Host OS |

## 💨 tmpfs Mounts

### Memory-based Storage

```bash
# Basic tmpfs mount
docker run -d --tmpfs /tmp nginx:alpine

# tmpfs with size limit
docker run -d \
  --tmpfs /tmp:size=100m,noexec \
  nginx:alpine

# tmpfs using --mount syntax
docker run -d \
  --mount type=tmpfs,destination=/tmp,tmpfs-size=100m \
  nginx:alpine
```

### tmpfs Use Cases

- **Temporary files**: Cache, session data
- **Security**: Sensitive data that shouldn't persist
- **Performance**: Fast I/O for temporary operations
- **Memory constraints**: When disk I/O is bottleneck

## 🎛️ Storage Drivers

### Configuring Storage Drivers

**Check current driver:**
```bash
docker info | grep "Storage Driver"
```

**Configure overlay2 (recommended):**
```json
{
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
```

### Storage Driver Comparison

| Driver | Performance | Stability | Copy-on-Write | Use Case |
|--------|-------------|-----------|---------------|----------|
| overlay2 | Excellent | High | Efficient | Production (recommended) |
| aufs | Good | Medium | Good | Legacy systems |
| devicemapper | Good | High | Block-level | Enterprise storage |
| btrfs | Good | High | Advanced | Advanced features needed |
| zfs | Excellent | High | Advanced | Enterprise/high-performance |

## 🔒 Storage Security

### Volume Security Best Practices

```bash
# Read-only volumes
docker run -d -v mydata:/data:ro nginx:alpine

# Volume with specific user ownership
docker run -d \
  --user 1001:1001 \
  -v mydata:/data \
  nginx:alpine

# Encrypted volume (using device mapper)
docker volume create \
  --driver local \
  --opt type=ext4 \
  --opt device=/dev/mapper/encrypted-disk \
  encrypted-volume
```

### SELinux and Storage

```bash
# SELinux-compatible bind mount
docker run -d \
  -v /host/data:/container/data:Z \
  myapp:latest

# Shared SELinux label
docker run -d \
  -v /host/data:/container/data:z \
  myapp:latest
```

## 📊 Storage Performance Optimization

### Performance Monitoring

```bash
# Monitor container I/O
docker stats --format "table {{.Container}}\t{{.BlockIO}}"

# Container I/O statistics
docker exec mycontainer cat /proc/self/io

# Filesystem usage
docker exec mycontainer df -h
```

### Performance Tuning

```python
# I/O performance testing script
import os
import time
import threading

def write_test(filename, size_mb):
    """Test write performance"""
    data = os.urandom(1024)  # 1KB of random data
    start_time = time.time()
    
    with open(filename, 'wb') as f:
        for _ in range(size_mb * 1024):  # Write 1KB chunks
            f.write(data)
    
    end_time = time.time()
    duration = end_time - start_time
    throughput = size_mb / duration
    
    return {
        'duration': duration,
        'throughput_mb_s': throughput,
        'size_mb': size_mb
    }

def read_test(filename):
    """Test read performance"""
    start_time = time.time()
    size = 0
    
    with open(filename, 'rb') as f:
        while True:
            chunk = f.read(1024 * 1024)  # Read 1MB chunks
            if not chunk:
                break
            size += len(chunk)
    
    end_time = time.time()
    duration = end_time - start_time
    throughput = (size / 1024 / 1024) / duration
    
    return {
        'duration': duration,
        'throughput_mb_s': throughput,
        'size_mb': size / 1024 / 1024
    }

# Performance test example
if __name__ == "__main__":
    test_file = "/data/performance_test.bin"
    test_size = 100  # MB
    
    print("🚀 Storage Performance Test")
    print(f"File: {test_file}")
    print(f"Size: {test_size} MB")
    
    # Write test
    write_result = write_test(test_file, test_size)
    print(f"✍️  Write: {write_result['throughput_mb_s']:.2f} MB/s")
    
    # Read test
    read_result = read_test(test_file)
    print(f"📖 Read: {read_result['throughput_mb_s']:.2f} MB/s")
    
    # Cleanup
    os.remove(test_file)
```

## 🏗️ Storage Patterns & Use Cases

### Database Storage Patterns

**PostgreSQL with persistent volume:**
```bash
# Create database volume
docker volume create postgres-data

# Run PostgreSQL with persistent storage
docker run -d \
  --name postgres-db \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=myapp \
  -v postgres-data:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:13

# Backup database
docker exec postgres-db pg_dump -U postgres myapp > backup.sql

# Restore database
docker exec -i postgres-db psql -U postgres myapp < backup.sql
```

**MySQL with bind mount:**
```bash
# Create MySQL configuration
mkdir -p /host/mysql/{data,config,logs}

cat > /host/mysql/config/my.cnf << 'EOF'
[mysqld]
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
max_connections = 200
EOF

# Run MySQL with bind mounts
docker run -d \
  --name mysql-db \
  -e MYSQL_ROOT_PASSWORD=secret \
  -e MYSQL_DATABASE=myapp \
  -v /host/mysql/data:/var/lib/mysql \
  -v /host/mysql/config:/etc/mysql/conf.d:ro \
  -v /host/mysql/logs:/var/log/mysql \
  -p 3306:3306 \
  mysql:8.0
```

### Application Data Patterns

**Web application with shared uploads:**
```bash
# Create shared upload volume
docker volume create webapp-uploads

# Frontend container
docker run -d \
  --name frontend \
  -v webapp-uploads:/app/uploads \
  -p 80:80 \
  myapp:frontend

# Backend API container
docker run -d \
  --name backend \
  -v webapp-uploads:/app/uploads \
  -p 8080:8080 \
  myapp:backend

# File processor container
docker run -d \
  --name processor \
  -v webapp-uploads:/app/uploads \
  myapp:file-processor
```

### Log Management Patterns

**Centralized logging with volumes:**
```bash
# Create log volume
docker volume create app-logs

# Application containers writing to shared log volume
docker run -d \
  --name app1 \
  -v app-logs:/var/log/app \
  myapp:service1

docker run -d \
  --name app2 \
  -v app-logs:/var/log/app \
  myapp:service2

# Log collector (Fluentd/Logstash)
docker run -d \
  --name log-collector \
  -v app-logs:/var/log/app:ro \
  -v /host/fluent.conf:/fluentd/etc/fluent.conf:ro \
  fluent/fluentd:latest
```

## 💾 Data Backup & Restore

### Volume Backup Strategies

**Backup using tar:**
```bash
# Create backup of volume
docker run --rm \
  -v myvolume:/data \
  -v $(pwd):/backup \
  alpine \
  tar czf /backup/volume-backup-$(date +%Y%m%d).tar.gz -C /data .

# Restore from backup
docker run --rm \
  -v myvolume:/data \
  -v $(pwd):/backup \
  alpine \
  tar xzf /backup/volume-backup-20231201.tar.gz -C /data
```

**Automated backup script:**
```bash
#!/bin/bash
# backup-volumes.sh

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

backup_volume() {
    local volume_name=$1
    local backup_file="${BACKUP_DIR}/${volume_name}_${DATE}.tar.gz"
    
    echo "📦 Backing up volume: $volume_name"
    
    docker run --rm \
        -v ${volume_name}:/data:ro \
        -v ${BACKUP_DIR}:/backup \
        alpine \
        tar czf /backup/$(basename $backup_file) -C /data .
    
    if [ $? -eq 0 ]; then
        echo "✅ Backup completed: $backup_file"
    else
        echo "❌ Backup failed: $volume_name"
        return 1
    fi
}

cleanup_old_backups() {
    echo "🧹 Cleaning up backups older than $RETENTION_DAYS days"
    find $BACKUP_DIR -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
}

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup all volumes
for volume in $(docker volume ls -q); do
    backup_volume $volume
done

# Cleanup old backups
cleanup_old_backups

echo "🎉 Backup process completed"
```

### Database-Specific Backup

**PostgreSQL backup:**
```python
#!/usr/bin/env python3
import subprocess
import datetime
import os
import gzip

class PostgreSQLBackup:
    def __init__(self, container_name, database, username="postgres"):
        self.container_name = container_name
        self.database = database
        self.username = username
        self.backup_dir = "/backups/postgresql"
        
        # Create backup directory
        os.makedirs(self.backup_dir, exist_ok=True)
    
    def create_backup(self, compress=True):
        """Create database backup"""
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = f"{self.backup_dir}/{self.database}_{timestamp}.sql"
        
        try:
            # Create SQL dump
            cmd = [
                "docker", "exec", self.container_name,
                "pg_dump", "-U", self.username, "-d", self.database
            ]
            
            with open(backup_file, 'w') as f:
                result = subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, text=True)
            
            if result.returncode != 0:
                raise Exception(f"pg_dump failed: {result.stderr}")
            
            # Compress if requested
            if compress:
                compressed_file = f"{backup_file}.gz"
                with open(backup_file, 'rb') as f_in:
                    with gzip.open(compressed_file, 'wb') as f_out:
                        f_out.writelines(f_in)
                os.remove(backup_file)
                backup_file = compressed_file
            
            print(f"✅ Backup created: {backup_file}")
            return backup_file
            
        except Exception as e:
            print(f"❌ Backup failed: {e}")
            return None
    
    def restore_backup(self, backup_file):
        """Restore database from backup"""
        try:
            # Handle compressed files
            if backup_file.endswith('.gz'):
                cmd = ["gunzip", "-c", backup_file]
                decompress = subprocess.Popen(cmd, stdout=subprocess.PIPE)
                
                restore_cmd = [
                    "docker", "exec", "-i", self.container_name,
                    "psql", "-U", self.username, "-d", self.database
                ]
                
                subprocess.run(restore_cmd, stdin=decompress.stdout, check=True)
                decompress.wait()
            else:
                cmd = [
                    "docker", "exec", "-i", self.container_name,
                    "psql", "-U", self.username, "-d", self.database
                ]
                
                with open(backup_file, 'r') as f:
                    subprocess.run(cmd, stdin=f, check=True)
            
            print(f"✅ Restore completed from: {backup_file}")
            
        except Exception as e:
            print(f"❌ Restore failed: {e}")

# Usage example
if __name__ == "__main__":
    backup = PostgreSQLBackup("postgres-db", "myapp")
    backup_file = backup.create_backup(compress=True)
    
    if backup_file:
        print(f"Backup saved to: {backup_file}")
```

## 🚀 Production Storage Examples

### 1. High-Availability Database Setup

```yaml
# docker-compose.yml for HA PostgreSQL
version: '3.8'

services:
  postgres-master:
    image: postgres:13
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: secret
      POSTGRES_REPLICATION_MODE: master
      POSTGRES_REPLICATION_USER: replicator
      POSTGRES_REPLICATION_PASSWORD: reppass
    volumes:
      - postgres_master_data:/var/lib/postgresql/data
      - ./postgresql.conf:/etc/postgresql/postgresql.conf:ro
    ports:
      - "5432:5432"
    networks:
      - db-network

  postgres-slave:
    image: postgres:13
    environment:
      PGUSER: postgres
      POSTGRES_PASSWORD: secret
      POSTGRES_MASTER_HOST: postgres-master
      POSTGRES_REPLICATION_MODE: slave
      POSTGRES_REPLICATION_USER: replicator
      POSTGRES_REPLICATION_PASSWORD: reppass
    volumes:
      - postgres_slave_data:/var/lib/postgresql/data
    depends_on:
      - postgres-master
    networks:
      - db-network

  postgres-backup:
    image: postgres:13
    environment:
      PGPASSWORD: secret
    volumes:
      - postgres_backups:/backups
      - ./backup-script.sh:/backup-script.sh:ro
    command: |
      sh -c '
        while true; do
          /backup-script.sh
          sleep 3600  # Backup every hour
        done
      '
    depends_on:
      - postgres-master
    networks:
      - db-network

volumes:
  postgres_master_data:
    driver: local
    driver_opts:
      type: ext4
      device: /dev/sdb1
  postgres_slave_data:
    driver: local
  postgres_backups:
    driver: local

networks:
  db-network:
    driver: bridge
```

### 2. Distributed Storage with NFS

```bash
# Setup NFS-backed volumes for shared storage
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=nfs.example.com,rw,nfsvers=4 \
  --opt device=:/exports/app-data \
  nfs-app-data

docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=nfs.example.com,rw,nfsvers=4 \
  --opt device=:/exports/app-uploads \
  nfs-uploads

# Deploy application with shared NFS storage
docker run -d \
  --name app-server-1 \
  -v nfs-app-data:/app/data \
  -v nfs-uploads:/app/uploads \
  myapp:latest

docker run -d \
  --name app-server-2 \
  -v nfs-app-data:/app/data \
  -v nfs-uploads:/app/uploads \
  myapp:latest
```

### 3. Storage Monitoring & Alerting

```python
#!/usr/bin/env python3
# storage-monitor.py

import docker
import psutil
import time
import json
import smtplib
from email.mime.text import MIMEText
from datetime import datetime

class StorageMonitor:
    def __init__(self, alert_threshold=80):
        self.client = docker.from_env()
        self.alert_threshold = alert_threshold
        self.alerted_volumes = set()
    
    def get_volume_usage(self, volume_name):
        """Get volume usage statistics"""
        try:
            # Create temporary container to check volume usage
            container = self.client.containers.run(
                "alpine",
                command="df -h /data",
                volumes={volume_name: {'bind': '/data', 'mode': 'ro'}},
                remove=True,
                detach=False
            )
            
            output = container.decode().strip()
            lines = output.split('\n')
            
            if len(lines) >= 2:
                parts = lines[1].split()
                if len(parts) >= 5:
                    return {
                        'volume': volume_name,
                        'size': parts[1],
                        'used': parts[2],
                        'available': parts[3],
                        'use_percent': int(parts[4].rstrip('%')),
                        'mount_point': parts[5] if len(parts) > 5 else '/data'
                    }
        except Exception as e:
            return {'volume': volume_name, 'error': str(e)}
        
        return None
    
    def get_container_storage_stats(self):
        """Get storage statistics for all containers"""
        stats = []
        
        for container in self.client.containers.list():
            try:
                container_stats = container.stats(stream=False)
                
                # Calculate storage I/O
                blkio_stats = container_stats.get('blkio_stats', {})
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
    
    def send_alert(self, volume_name, usage_percent):
        """Send alert for high volume usage"""
        message = f"""
        🚨 STORAGE ALERT 🚨
        
        Volume: {volume_name}
        Usage: {usage_percent}%
        Threshold: {self.alert_threshold}%
        Time: {datetime.now()}
        
        Please check and clean up the volume or expand storage capacity.
        """
        
        print(message)
        # Add email/Slack notification here
    
    def monitor_storage(self, interval=300):
        """Monitor storage usage continuously"""
        print(f"🔍 Starting storage monitoring (interval: {interval}s)")
        
        while True:
            try:
                print(f"\n📊 Storage Report - {datetime.now().strftime('%H:%M:%S')}")
                print("-" * 60)
                
                # Monitor volumes
                volumes = self.client.volumes.list()
                for volume in volumes:
                    usage = self.get_volume_usage(volume.name)
                    
                    if usage and 'error' not in usage:
                        use_percent = usage['use_percent']
                        status = "⚠️" if use_percent >= self.alert_threshold else "✅"
                        
                        print(f"{status} Volume: {volume.name}")
                        print(f"   Usage: {usage['used']}/{usage['size']} ({use_percent}%)")
                        print(f"   Available: {usage['available']}")
                        
                        # Send alert if threshold exceeded
                        if use_percent >= self.alert_threshold:
                            if volume.name not in self.alerted_volumes:
                                self.send_alert(volume.name, use_percent)
                                self.alerted_volumes.add(volume.name)
                        else:
                            self.alerted_volumes.discard(volume.name)
                    
                    elif usage and 'error' in usage:
                        print(f"❌ Volume: {volume.name} - Error: {usage['error']}")
                
                # Monitor container I/O
                print("\n📈 Container I/O Statistics:")
                container_stats = self.get_container_storage_stats()
                
                for stat in container_stats:
                    if 'error' not in stat:
                        print(f"📦 {stat['container']}: "
                              f"Read {stat['read_mb']}MB, Write {stat['write_mb']}MB")
                    else:
                        print(f"❌ {stat['container']}: {stat['error']}")
                
                # Host storage info
                print("\n🖥️ Host Storage:")
                for partition in psutil.disk_partitions():
                    try:
                        usage = psutil.disk_usage(partition.mountpoint)
                        percent = (usage.used / usage.total) * 100
                        status = "⚠️" if percent >= self.alert_threshold else "✅"
                        
                        print(f"{status} {partition.mountpoint}: "
                              f"{usage.used // (1024**3)}GB/"
                              f"{usage.total // (1024**3)}GB "
                              f"({percent:.1f}%)")
                    except:
                        pass
                
                time.sleep(interval)
                
            except KeyboardInterrupt:
                print("\n👋 Storage monitoring stopped")
                break
            except Exception as e:
                print(f"❌ Monitoring error: {e}")
                time.sleep(interval)

if __name__ == "__main__":
    monitor = StorageMonitor(alert_threshold=80)
    monitor.monitor_storage(300)  # Check every 5 minutes
```

## 🎯 Chapter Checkpoint

### Questions

1. **What are the three main types of Docker storage and when would you use each?**
   - Volumes: Docker-managed persistent storage
   - Bind mounts: Host filesystem access
   - tmpfs: Memory-based temporary storage

2. **How do you backup and restore a Docker volume?**
   - Use `tar` with temporary container to create/restore archives

3. **What is the recommended storage driver for production?**
   - overlay2 for most use cases

4. **How do you configure a read-only volume mount?**
   - Add `:ro` suffix: `-v myvolume:/data:ro`

### Tasks

- [ ] Create and manage Docker volumes
- [ ] Implement data backup and restore procedures
- [ ] Configure storage monitoring and alerting
- [ ] Optimize storage performance for production

---

## 🚀 What's Next?

In [Chapter 06: Docker Compose](../06-docker-compose/README.md), you'll learn:
- Multi-container application orchestration
- Docker Compose file syntax and best practices
- Service scaling and load balancing
- Environment management and secrets
- Production deployment with Compose

## 📚 Key Takeaways

✅ **Volumes** provide Docker-managed persistent storage
✅ **Bind mounts** offer direct host filesystem access
✅ **tmpfs mounts** provide fast memory-based storage
✅ **Storage drivers** affect performance and compatibility
✅ **Backup strategies** are essential for data protection
✅ **Monitoring** helps prevent storage-related issues

## 📝 Practice Checklist

Before moving on, ensure you can:
- [ ] Create and manage different types of Docker storage
- [ ] Design appropriate storage strategies for applications
- [ ] Implement backup and restore procedures
- [ ] Monitor storage usage and performance
- [ ] Configure storage security and optimization
- [ ] Troubleshoot storage-related issues

---

**🎉 Congratulations!** You now have advanced Docker storage management skills. Complete the [lab exercise](lab/README.md) to practice these concepts, then validate your knowledge with the [checkpoint](checkpoint.md)!

---

<div align="center">

**[⬅️ Previous: Docker Networking](../04-docker-networking/README.md)** | **[Next: Docker Compose ➡️](../06-docker-compose/README.md)**

</div> 