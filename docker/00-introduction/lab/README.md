# 🧪 Lab Exercise: Docker Environment Setup & First Container

Welcome to your first hands-on Docker experience! This lab will guide you through setting up Docker and running your first containers.

## 🎯 Lab Objectives

By completing this lab, you will:
- ✅ Verify Docker installation and configuration
- ✅ Run your first container
- ✅ Understand basic Docker commands
- ✅ Compare different container images
- ✅ Practice container management

## 🛠️ Prerequisites

- Docker Desktop installed on your machine
- Terminal/Command Prompt access
- Internet connection for downloading images

## 📝 Lab Instructions

### Part 1: Environment Verification

#### Step 1: Check Docker Installation
```bash
# Check Docker version
docker --version

# Expected output: Docker version 24.x.x, build xxxxx
```

#### Step 2: Verify Docker is Running
```bash
# Test Docker daemon
docker info

# This should show system information without errors
```

#### Step 3: Run the Classic Hello World
```bash
# Pull and run hello-world
docker run hello-world
```

**✅ Expected Output:**
```
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

**📝 What happened?**
1. Docker looked for the `hello-world` image locally
2. Didn't find it, so downloaded from Docker Hub
3. Created a container from the image
4. Ran the container and displayed the message
5. Container exited after completing its task

### Part 2: Exploring Different Containers

#### Step 4: Run an Interactive Container
```bash
# Run Ubuntu container with interactive shell
docker run -it ubuntu:20.04 /bin/bash
```

**Inside the container, try these commands:**
```bash
# Check the OS
cat /etc/os-release

# List files
ls -la

# Check running processes
ps aux

# Exit the container
exit
```

**🤔 Questions to Consider:**
- What OS version is running inside the container?
- How many processes are running?
- What happened when you typed `exit`?

#### Step 5: Run a Web Server
```bash
# Run nginx web server
docker run -d -p 8080:80 --name my-nginx nginx:alpine

# Check if it's running
docker ps
```

**Test the web server:**
- Open your browser
- Navigate to `http://localhost:8080`
- You should see the nginx welcome page!

#### Step 6: Explore the Running Container
```bash
# See container logs
docker logs my-nginx

# Execute commands inside running container
docker exec -it my-nginx /bin/sh
```

**Inside the nginx container:**
```bash
# Check nginx processes
ps aux | grep nginx

# Look at nginx configuration
cat /etc/nginx/nginx.conf

# Check the default webpage
cat /usr/share/nginx/html/index.html

# Exit
exit
```

### Part 3: Container Management

#### Step 7: Container Lifecycle Operations
```bash
# List all containers (running and stopped)
docker ps -a

# Stop the nginx container
docker stop my-nginx

# Check status
docker ps -a

# Start it again
docker start my-nginx

# Restart the container
docker restart my-nginx
```

#### Step 8: Container Inspection
```bash
# Get detailed information about the container
docker inspect my-nginx

# Get specific information using filters
docker inspect my-nginx --format '{{.NetworkSettings.IPAddress}}'
docker inspect my-nginx --format '{{.State.Status}}'
```

#### Step 9: Resource Usage
```bash
# Check resource usage
docker stats my-nginx

# Press Ctrl+C to exit stats view
```

### Part 4: Comparing Container Images

#### Step 10: Pull Different Versions
```bash
# Pull different nginx versions
docker pull nginx:latest
docker pull nginx:alpine
docker pull nginx:1.20-alpine

# List downloaded images
docker images
```

**📊 Compare the images:**
- Which image is smallest?
- Which is largest?
- What's the difference between `nginx:latest` and `nginx:alpine`?

#### Step 11: Run Multiple Containers
```bash
# Run nginx alpine on different port
docker run -d -p 8081:80 --name nginx-alpine nginx:alpine

# Run standard nginx on another port
docker run -d -p 8082:80 --name nginx-standard nginx:latest

# Check all running containers
docker ps
```

**Test both servers:**
- `http://localhost:8081` (alpine version)
- `http://localhost:8082` (standard version)

### Part 5: Cleanup

#### Step 12: Stop and Remove Containers
```bash
# Stop all running containers
docker stop my-nginx nginx-alpine nginx-standard

# Remove containers
docker rm my-nginx nginx-alpine nginx-standard

# Verify cleanup
docker ps -a
```

#### Step 13: Cleanup Images (Optional)
```bash
# Remove specific images
docker rmi nginx:alpine nginx:1.20-alpine

# See remaining images
docker images

# Remove unused images (be careful!)
docker image prune
```

## 🎯 Challenges & Experiments

### Challenge 1: Container Exploration
Try running these different containers and explore what they do:

```bash
# Python environment
docker run -it python:3.9-alpine python

# Node.js environment  
docker run -it node:16-alpine node

# Redis database
docker run -d --name redis-test redis:alpine

# Check Redis logs
docker logs redis-test
```

### Challenge 2: Port Mapping Experiment
```bash
# Run nginx on different ports
docker run -d -p 3000:80 --name web1 nginx:alpine
docker run -d -p 4000:80 --name web2 nginx:alpine
docker run -d -p 5000:80 --name web3 nginx:alpine

# Test all three:
# http://localhost:3000
# http://localhost:4000  
# http://localhost:5000
```

### Challenge 3: Environment Variables
```bash
# Run container with environment variables
docker run -d \
  --name mysql-test \
  -e MYSQL_ROOT_PASSWORD=mypassword \
  -e MYSQL_DATABASE=testdb \
  mysql:8.0

# Check if it started successfully
docker logs mysql-test
```

## 📝 Lab Report

Answer these questions to complete your lab:

### Basic Understanding
1. **What is a Docker image?**
   - Your answer: ________________________________

2. **What is a Docker container?**
   - Your answer: ________________________________

3. **What's the difference between `docker run` and `docker start`?**
   - Your answer: ________________________________

### Practical Questions
4. **How many nginx containers did you run in this lab?**
   - Answer: ________________________________

5. **Which nginx image was smallest in size?**
   - Answer: ________________________________

6. **What ports did you map containers to?**
   - Answer: ________________________________

### Reflection Questions
7. **What surprised you most about containers?**
   - Your answer: ________________________________

8. **How could containers be useful in your development work?**
   - Your answer: ________________________________

9. **What questions do you still have about Docker?**
   - Your answer: ________________________________

## 🏆 Bonus Challenges

If you finished early, try these advanced exercises:

### Bonus 1: Container Networking
```bash
# Create a custom network
docker network create my-network

# Run containers on the custom network
docker run -d --network my-network --name app1 nginx:alpine
docker run -d --network my-network --name app2 nginx:alpine

# Test network connectivity
docker exec app1 ping app2
```

### Bonus 2: Volume Mounting
```bash
# Create a directory with HTML file
mkdir ~/my-website
echo "<h1>My Custom Page!</h1>" > ~/my-website/index.html

# Mount it into nginx container
docker run -d -p 8080:80 \
  --name custom-nginx \
  -v ~/my-website:/usr/share/nginx/html \
  nginx:alpine

# Visit http://localhost:8080
```

### Bonus 3: Container Monitoring
```bash
# Monitor resource usage in real-time
docker stats

# Get container processes
docker exec my-nginx ps aux

# Check container filesystem changes
docker diff my-nginx
```

## ✅ Lab Completion Checklist

Mark off each item as you complete it:

- [ ] Successfully ran `docker run hello-world`
- [ ] Ran an interactive Ubuntu container
- [ ] Started and accessed an nginx web server
- [ ] Used `docker ps`, `docker logs`, and `docker exec`
- [ ] Compared different image sizes
- [ ] Ran multiple containers simultaneously
- [ ] Stopped and removed containers
- [ ] Completed at least one bonus challenge
- [ ] Answered all lab report questions

## 🎉 Congratulations!

You've completed your first Docker lab! You now have hands-on experience with:
- Running containers
- Managing container lifecycle
- Working with images
- Basic troubleshooting

**Next Steps:**
1. Complete the [Chapter Checkpoint](../checkpoint.md)
2. Move on to [Chapter 01: Docker Basics](../../01-docker-basics/README.md)

## 🆘 Troubleshooting

### Common Issues:

**Docker not starting:**
- Windows: Ensure WSL 2 is enabled and Docker Desktop is running
- Mac: Check if Docker Desktop is running (whale icon in menu bar)
- Linux: Check if docker service is running: `sudo systemctl status docker`

**Permission denied errors (Linux):**
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

**Port already in use:**
```bash
# Find what's using the port
netstat -tulpn | grep :8080

# Use a different port
docker run -d -p 8090:80 nginx:alpine
```

**Container won't start:**
```bash
# Check logs for errors
docker logs container-name

# Check if image exists
docker images
```

---

**Need Help?** Check the [troubleshooting guide](../../../resources/troubleshooting.md) or ask in the community forum! 