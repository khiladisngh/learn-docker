# 🎯 Chapter 05 Checkpoint: Advanced Docker Storage Management

Test your understanding of Docker storage concepts, volume management, backup strategies, and storage optimization.

## 📝 Knowledge Assessment

### Section A: Storage Architecture (25 points)

**Question 1 (5 points):** What are the three main types of Docker storage and their primary use cases?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Volumes:** Docker-managed persistent storage, best for production data that needs to persist
- **Bind Mounts:** Host filesystem access, good for development and configuration files
- **tmpfs Mounts:** Memory-based storage, ideal for temporary data and security-sensitive information
</details>

---

**Question 2 (5 points):** Explain the Docker Union File System (overlay2) and how it manages image layers.

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Layer Structure:** Images consist of multiple read-only layers stacked on top of each other
- **Copy-on-Write:** When files are modified, they're copied to the container's writable layer
- **Storage Efficiency:** Common layers are shared between images, reducing disk usage
- **overlay2:** Uses kernel overlay filesystem for efficient layer management
- **Performance:** Provides good performance for most workloads with minimal overhead
</details>

---

**Question 3 (5 points):** What is the difference between anonymous and named volumes?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Anonymous Volumes:** Docker generates random names, harder to manage and reference
  ```bash
  docker run -v /data nginx  # Creates anonymous volume
  ```
- **Named Volumes:** User-defined names, easier to manage and reuse
  ```bash
  docker volume create mydata
  docker run -v mydata:/data nginx
  ```
- **Management:** Named volumes are easier to backup, share, and maintain
- **Persistence:** Both persist data, but named volumes are more predictable
</details>

---

**Question 4 (5 points):** How do you configure volume drivers and what are the benefits of different drivers?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Local driver with options
docker volume create --driver local \
  --opt type=ext4 \
  --opt device=/dev/sdb1 \
  myvolume

# NFS driver
docker volume create --driver local \
  --opt type=nfs \
  --opt o=addr=nfs.server.com,rw \
  --opt device=:/exports/data \
  nfs-volume
```

**Benefits:**
- **local:** Simple, good performance, single-host
- **NFS:** Shared across hosts, network-based
- **Third-party:** Cloud storage, distributed filesystems
</details>

---

**Question 5 (5 points):** What are the security considerations for Docker storage?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Read-only mounts:** Use `:ro` to prevent modifications
- **User mapping:** Run containers as non-root users
- **SELinux labels:** Use `:Z` or `:z` for proper labeling
- **Encryption:** Encrypt sensitive data at rest
- **Access control:** Limit host filesystem access
- **Secrets management:** Use Docker secrets for sensitive data
</details>

---

### Section B: Volume Management (25 points)

**Question 6 (5 points):** Write commands to create a volume with specific configuration and use it in a container.

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Create volume with labels and driver options
docker volume create \
  --driver local \
  --label environment=production \
  --label backup=daily \
  --opt type=ext4 \
  --opt device=/dev/sdb1 \
  production-data

# Use volume in container
docker run -d --name myapp \
  -v production-data:/app/data \
  -v production-data:/app/uploads:ro \
  myapp:latest
```
</details>

---

**Question 7 (5 points):** How do you inspect volume usage and troubleshoot volume-related issues?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Inspect volume details
docker volume inspect myvolume

# Check volume usage
docker run --rm -v myvolume:/data alpine df -h /data

# List volume contents
docker run --rm -v myvolume:/data alpine ls -la /data

# Find containers using volume
docker ps --filter volume=myvolume

# Check volume mount points
docker inspect container --format='{{.Mounts}}'
```
</details>

---

**Question 8 (5 points):** What are the best practices for volume naming and labeling?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
- **Naming Convention:** Use descriptive names like `projectname-component-data`
- **Environment Prefixes:** `prod-db-data`, `dev-app-logs`
- **Labels for Organization:**
  ```bash
  docker volume create \
    --label project=myapp \
    --label environment=production \
    --label component=database \
    --label backup-schedule=daily \
    myapp-prod-db-data
  ```
- **Consistency:** Maintain consistent naming across environments
- **Documentation:** Label volumes with purpose and maintenance info
</details>

---

**Question 9 (5 points):** How do you share volumes between multiple containers safely?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Shared read-write volume
docker volume create shared-data

# Container 1 (writer)
docker run -d --name writer \
  -v shared-data:/app/output \
  myapp:writer

# Container 2 (reader)
docker run -d --name reader \
  -v shared-data:/app/input:ro \
  myapp:processor

# Container 3 (backup)
docker run -d --name backup \
  -v shared-data:/data:ro \
  -v backup-storage:/backups \
  myapp:backup
```

**Safety considerations:**
- Use read-only mounts where possible
- Implement file locking for concurrent writes
- Use proper file permissions and ownership
</details>

---

**Question 10 (5 points):** Explain the difference between bind mounts and volumes in terms of performance and use cases.

<details>
<summary>Click to reveal answer</summary>

**Answer:**
| Aspect | Volumes | Bind Mounts |
|--------|---------|-------------|
| **Performance** | Optimized by Docker | Native filesystem |
| **Portability** | High (Docker-managed) | Low (host-dependent) |
| **Security** | Isolated | Direct host access |
| **Backup** | Docker tools | Host tools |
| **Use Cases** | Production data | Development, configs |

**When to use:**
- **Volumes:** Production databases, persistent app data
- **Bind Mounts:** Source code, configuration files, logs
</details>

---

### Section C: Backup & Restore (25 points)

**Question 11 (5 points):** Design a comprehensive backup strategy for a multi-container application with database.

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Backup strategy components:

# 1. Volume backups (filesystem level)
docker run --rm \
  -v app-data:/source:ro \
  -v /backups:/dest \
  alpine tar czf /dest/app-data-$(date +%Y%m%d).tar.gz -C /source .

# 2. Database logical backups
docker exec postgres-db pg_dump -U user dbname > /backups/db-$(date +%Y%m%d).sql

# 3. Configuration backups
tar czf /backups/configs-$(date +%Y%m%d).tar.gz /etc/docker/

# 4. Automated scheduling (cron)
0 2 * * * /scripts/backup-volumes.sh
0 3 * * * /scripts/backup-databases.sh

# 5. Retention policy
find /backups -name "*.tar.gz" -mtime +7 -delete
```
</details>

---

**Question 12 (5 points):** How do you implement point-in-time recovery for containerized databases?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# PostgreSQL PITR setup
# 1. Enable WAL archiving
postgresql.conf:
  wal_level = replica
  archive_mode = on
  archive_command = 'cp %p /wal_archive/%f'

# 2. Base backup
docker exec postgres-db pg_basebackup -D /backups/base -Ft -z

# 3. Recovery procedure
# - Restore base backup
# - Apply WAL files up to desired point
# - Create recovery.conf with target time

# MySQL PITR with binary logs
my.cnf:
  log-bin = mysql-bin
  binlog-format = ROW

# Recovery:
# - Restore from full backup
# - Apply binary logs: mysqlbinlog --start-datetime="..." mysql-bin.* | mysql
```
</details>

---

**Question 13 (10 points):** Write a Python script that implements automated backup with rotation and verification.

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```python
#!/usr/bin/env python3
import subprocess
import datetime
import os
import gzip
import hashlib
import json

class DockerBackupManager:
    def __init__(self, backup_dir="/backups", retention_days=7):
        self.backup_dir = backup_dir
        self.retention_days = retention_days
        self.timestamp = datetime.datetime.now()
        
    def backup_volume(self, volume_name):
        """Backup volume with verification"""
        backup_path = f"{self.backup_dir}/{volume_name}_{self.timestamp.strftime('%Y%m%d_%H%M%S')}.tar.gz"
        
        # Create backup
        cmd = [
            "docker", "run", "--rm",
            "-v", f"{volume_name}:/data:ro",
            "-v", f"{self.backup_dir}:/backup",
            "alpine",
            "tar", "czf", f"/backup/{os.path.basename(backup_path)}", "-C", "/data", "."
        ]
        
        result = subprocess.run(cmd, capture_output=True)
        if result.returncode != 0:
            raise Exception(f"Backup failed: {result.stderr}")
        
        # Verify backup
        if self.verify_backup(backup_path):
            # Calculate checksum
            checksum = self.calculate_checksum(backup_path)
            
            # Save metadata
            metadata = {
                'volume': volume_name,
                'backup_file': backup_path,
                'timestamp': self.timestamp.isoformat(),
                'size': os.path.getsize(backup_path),
                'checksum': checksum
            }
            
            with open(f"{backup_path}.meta", 'w') as f:
                json.dump(metadata, f, indent=2)
            
            return backup_path
        else:
            os.remove(backup_path)
            raise Exception("Backup verification failed")
    
    def verify_backup(self, backup_path):
        """Verify backup integrity"""
        try:
            cmd = ["tar", "tzf", backup_path]
            result = subprocess.run(cmd, capture_output=True)
            return result.returncode == 0
        except:
            return False
    
    def calculate_checksum(self, file_path):
        """Calculate SHA256 checksum"""
        sha256_hash = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                sha256_hash.update(chunk)
        return sha256_hash.hexdigest()
    
    def cleanup_old_backups(self):
        """Remove backups older than retention period"""
        cutoff_date = self.timestamp - datetime.timedelta(days=self.retention_days)
        
        for file in os.listdir(self.backup_dir):
            if file.endswith('.tar.gz'):
                file_path = os.path.join(self.backup_dir, file)
                file_time = datetime.datetime.fromtimestamp(os.path.getmtime(file_path))
                
                if file_time < cutoff_date:
                    os.remove(file_path)
                    # Remove metadata file if exists
                    meta_file = f"{file_path}.meta"
                    if os.path.exists(meta_file):
                        os.remove(meta_file)

# Usage
if __name__ == "__main__":
    backup_manager = DockerBackupManager()
    
    volumes = ['app-data', 'db-data', 'logs']
    for volume in volumes:
        try:
            backup_file = backup_manager.backup_volume(volume)
            print(f"✅ Backed up {volume} to {backup_file}")
        except Exception as e:
            print(f"❌ Failed to backup {volume}: {e}")
    
    backup_manager.cleanup_old_backups()
```
</details>

---

**Question 14 (5 points):** How do you test backup and restore procedures to ensure they work reliably?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Backup testing procedure:

# 1. Create test data
docker exec myapp sh -c "echo 'test data' > /app/data/test.txt"

# 2. Perform backup
./backup-script.sh

# 3. Simulate disaster (remove original data)
docker volume rm app-data
docker volume create app-data

# 4. Restore from backup
./restore-script.sh latest

# 5. Verify data integrity
docker exec myapp cat /app/data/test.txt

# 6. Automated testing script
#!/bin/bash
create_test_data() { ... }
backup_data() { ... }
destroy_data() { ... }
restore_data() { ... }
verify_data() { ... }

# Run full test cycle
create_test_data && backup_data && destroy_data && restore_data && verify_data
```
</details>

---

### Section D: Performance & Monitoring (25 points)

**Question 15 (5 points):** What factors affect Docker storage performance and how do you optimize them?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
**Performance Factors:**
- **Storage Driver:** overlay2 is fastest for most workloads
- **Filesystem:** ext4, xfs for good performance
- **I/O Scheduler:** Use `deadline` or `noop` for SSDs
- **Volume Type:** Volumes > bind mounts > tmpfs for different use cases

**Optimization:**
```bash
# Use appropriate storage driver
/etc/docker/daemon.json:
{
  "storage-driver": "overlay2",
  "storage-opts": ["overlay2.override_kernel_check=true"]
}

# Mount with performance options
docker run -v myvolume:/data:rw,delegated myapp

# Use tmpfs for temporary data
docker run --tmpfs /tmp:size=100m,noexec myapp
```
</details>

---

**Question 16 (5 points):** How do you monitor Docker storage usage and set up alerts?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```bash
# Monitor volume usage
docker system df -v

# Container storage stats
docker stats --format "table {{.Container}}\t{{.BlockIO}}"

# Host filesystem monitoring
df -h | grep docker

# Automated monitoring script
#!/bin/bash
THRESHOLD=80

for volume in $(docker volume ls -q); do
  usage=$(docker run --rm -v $volume:/data alpine df /data | awk 'NR==2 {print $5}' | sed 's/%//')
  if [ $usage -gt $THRESHOLD ]; then
    echo "ALERT: Volume $volume is ${usage}% full"
    # Send notification
  fi
done
```
</details>

---

**Question 17 (10 points):** Design a comprehensive storage monitoring solution with alerting and reporting.

<details>
<summary>Click to reveal answer</summary>

**Answer:**
```python
#!/usr/bin/env python3
import docker
import psutil
import time
import json
from datetime import datetime
import smtplib
from email.mime.text import MIMEText

class StorageMonitor:
    def __init__(self, thresholds={'warning': 80, 'critical': 90}):
        self.client = docker.from_env()
        self.thresholds = thresholds
        self.alerts_sent = set()
    
    def get_volume_usage(self, volume_name):
        """Get detailed volume usage"""
        try:
            result = self.client.containers.run(
                "alpine", f"df -h /data",
                volumes={volume_name: {'bind': '/data', 'mode': 'ro'}},
                remove=True, capture_output=True, text=True
            )
            
            lines = result.split('\n')
            if len(lines) >= 2:
                parts = lines[1].split()
                return {
                    'volume': volume_name,
                    'size': parts[1],
                    'used': parts[2],
                    'available': parts[3],
                    'use_percent': int(parts[4].rstrip('%'))
                }
        except Exception as e:
            return {'volume': volume_name, 'error': str(e)}
    
    def check_thresholds(self, usage):
        """Check if usage exceeds thresholds"""
        if 'use_percent' not in usage:
            return None
            
        percent = usage['use_percent']
        volume = usage['volume']
        
        if percent >= self.thresholds['critical']:
            if f"{volume}-critical" not in self.alerts_sent:
                self.send_alert(volume, percent, 'CRITICAL')
                self.alerts_sent.add(f"{volume}-critical")
            return 'critical'
        elif percent >= self.thresholds['warning']:
            if f"{volume}-warning" not in self.alerts_sent:
                self.send_alert(volume, percent, 'WARNING')
                self.alerts_sent.add(f"{volume}-warning")
            return 'warning'
        else:
            # Clear alerts when usage drops
            self.alerts_sent.discard(f"{volume}-warning")
            self.alerts_sent.discard(f"{volume}-critical")
            return 'ok'
    
    def send_alert(self, volume, usage, level):
        """Send alert notification"""
        message = f"{level}: Volume {volume} is {usage}% full"
        print(f"🚨 {message}")
        # Implement email/Slack notification here
    
    def generate_report(self):
        """Generate comprehensive storage report"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'volumes': [],
            'containers': [],
            'host_storage': [],
            'summary': {'total_volumes': 0, 'warning': 0, 'critical': 0}
        }
        
        # Check all volumes
        for volume in self.client.volumes.list():
            usage = self.get_volume_usage(volume.name)
            if usage:
                status = self.check_thresholds(usage)
                usage['status'] = status
                report['volumes'].append(usage)
                
                report['summary']['total_volumes'] += 1
                if status == 'warning':
                    report['summary']['warning'] += 1
                elif status == 'critical':
                    report['summary']['critical'] += 1
        
        return report
    
    def monitor_continuously(self, interval=300):
        """Run continuous monitoring"""
        while True:
            try:
                report = self.generate_report()
                
                # Save report
                timestamp = int(time.time())
                with open(f'/var/log/storage-report-{timestamp}.json', 'w') as f:
                    json.dump(report, f, indent=2)
                
                # Print summary
                summary = report['summary']
                print(f"📊 {datetime.now()}: {summary['total_volumes']} volumes, "
                      f"{summary['warning']} warnings, {summary['critical']} critical")
                
                time.sleep(interval)
                
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"❌ Monitoring error: {e}")
                time.sleep(60)

if __name__ == "__main__":
    monitor = StorageMonitor()
    monitor.monitor_continuously()
```
</details>

---

**Question 18 (5 points):** How do you troubleshoot common Docker storage issues?

<details>
<summary>Click to reveal answer</summary>

**Answer:**
**Common Issues & Solutions:**

1. **Volume not mounting:**
   ```bash
   # Check volume exists
   docker volume ls | grep myvolume
   
   # Inspect volume
   docker volume inspect myvolume
   
   # Check permissions
   docker run --rm -v myvolume:/data alpine ls -la /data
   ```

2. **Permission denied:**
   ```bash
   # Fix ownership
   docker run --rm -v myvolume:/data alpine chown -R 1000:1000 /data
   
   # Use user mapping
   docker run --user 1000:1000 -v myvolume:/data myapp
   ```

3. **Storage space issues:**
   ```bash
   # Check Docker space usage
   docker system df
   
   # Clean up
   docker system prune -a
   docker volume prune
   ```

4. **Performance issues:**
   ```bash
   # Check I/O stats
   docker stats --format "table {{.Container}}\t{{.BlockIO}}"
   
   # Use appropriate mount options
   docker run -v myvolume:/data:delegated myapp
   ```
</details>

---

## 🛠️ Practical Exercises

### Exercise 1: Storage Architecture Design (20 points)

Design storage solution for an e-commerce application:

1. **Database Storage (5 points):** PostgreSQL with master-slave replication
2. **Application Data (5 points):** User uploads and product images
3. **Log Management (5 points):** Centralized logging with retention
4. **Backup Strategy (5 points):** Automated backups with PITR

### Exercise 2: Backup & Recovery Implementation (20 points)

1. **Volume Backup (5 points):** Implement automated volume backup with verification
2. **Database Backup (5 points):** PostgreSQL logical and physical backups
3. **Disaster Recovery (5 points):** Complete disaster recovery procedure
4. **Testing (5 points):** Automated backup testing and validation

### Exercise 3: Performance Optimization (20 points)

1. **Storage Driver Optimization (5 points):** Configure optimal storage driver settings
2. **Volume Performance (5 points):** Benchmark different volume configurations
3. **I/O Optimization (5 points):** Optimize container I/O patterns
4. **Monitoring (5 points):** Implement comprehensive performance monitoring

### Exercise 4: Storage Security (20 points)

1. **Access Control (5 points):** Implement proper volume permissions and access control
2. **Encryption (5 points):** Set up encrypted storage for sensitive data
3. **Security Monitoring (5 points):** Monitor for security-related storage events
4. **Compliance (5 points):** Implement storage compliance for regulatory requirements

## 🎯 Scoring Rubric

| Score Range | Level | Description |
|-------------|-------|-------------|
| 90-100 | Expert | Advanced storage mastery, production-ready solutions |
| 80-89 | Advanced | Strong storage skills with minor gaps |
| 70-79 | Intermediate | Good understanding, needs practice |
| 60-69 | Beginner | Basic concepts understood, significant practice needed |
| Below 60 | Needs Review | Review chapter material and retry |

## ✅ Self-Assessment Checklist

Before proceeding to Chapter 6, ensure you can:

- [ ] Create and manage different types of Docker storage
- [ ] Design appropriate storage strategies for applications
- [ ] Implement comprehensive backup and restore procedures
- [ ] Monitor storage performance and usage effectively
- [ ] Troubleshoot common storage issues
- [ ] Configure storage security and optimization
- [ ] Implement automated storage management solutions

## 🚀 Preparation for Next Chapter

Chapter 6 (Docker Compose) builds on these concepts:
- Multi-container applications with shared storage
- Volume management across services
- Environment-specific storage configurations
- Production deployment patterns

## 📚 Additional Resources

- [Docker Storage Documentation](https://docs.docker.com/storage/)
- [Docker Volume Drivers](https://docs.docker.com/engine/extend/plugins_volume/)
- [Storage Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Performance Tuning](https://docs.docker.com/config/containers/resource_constraints/)

---

**🎉 Checkpoint Complete!** 

**Score: ___/100**

If you scored 80+, you're ready for [Chapter 06: Docker Compose](../06-docker-compose/README.md).
If you scored below 80, review the chapter materials and retry the assessment.

---

**[⬅️ Back to Chapter 05](../README.md)** | **[Next: Docker Compose ➡️](../06-docker-compose/README.md)** 