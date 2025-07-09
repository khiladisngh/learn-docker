# 🎯 Checkpoint: Docker Basics - Building Your First Application

Time to validate your Docker fundamentals! This checkpoint ensures you've mastered essential Docker skills before advancing to intermediate topics.

## 📝 Knowledge Assessment

### Part 1: Docker CLI Mastery (25 points)

#### Question 1 (5 points)
**Which command creates and runs a new container from an image?**

A) `docker create nginx`
B) `docker start nginx`
C) `docker run nginx`
D) `docker exec nginx`

**Your answer:** ___

#### Question 2 (5 points)
**What does the `-d` flag do in `docker run -d nginx`?**

A) Downloads the image
B) Runs the container in detached mode (background)
C) Deletes the container after exit
D) Enables debug mode

**Your answer:** ___

#### Question 3 (5 points)
**To map host port 8080 to container port 80, you would use:**

A) `docker run -p 80:8080 nginx`
B) `docker run -p 8080:80 nginx`
C) `docker run --port 8080:80 nginx`
D) `docker run -P 8080:80 nginx`

**Your answer:** ___

#### Question 4 (5 points)
**Which command shows running containers?**

A) `docker images`
B) `docker ps`
C) `docker containers`
D) `docker list`

**Your answer:** ___

#### Question 5 (5 points)
**To execute a command inside a running container, you use:**

A) `docker run container_name command`
B) `docker exec container_name command`
C) `docker attach container_name command`
D) `docker connect container_name command`

**Your answer:** ___

### Part 2: Dockerfile Understanding (30 points)

#### Question 6 (10 points)
**Arrange these Dockerfile instructions in the correct order for optimal caching:**

```
A) COPY . .
B) FROM node:16-alpine
C) RUN npm install
D) COPY package*.json ./
E) WORKDIR /app
```

**Your answer:** _____ → _____ → _____ → _____ → _____

#### Question 7 (10 points)
**What's wrong with this Dockerfile?**

```dockerfile
FROM node:16
COPY . /app
RUN npm install
WORKDIR /app
CMD ["npm", "start"]
```

A) Missing EXPOSE instruction
B) WORKDIR should come before COPY
C) Should copy package.json first for better caching
D) All of the above

**Your answer:** ___

#### Question 8 (10 points)
**In a multi-stage build, how do you copy files from a previous stage?**

A) `COPY /app/dist ./dist`
B) `COPY --from=build /app/dist ./dist`
C) `COPY --stage=build /app/dist ./dist`
D) `COPY build:/app/dist ./dist`

**Your answer:** ___

### Part 3: Security Best Practices (20 points)

#### Question 9 (10 points)
**Which security practices should you implement in Dockerfiles? (Select all that apply)**

A) Run as non-root user
B) Use specific image tags instead of 'latest'
C) Use multi-stage builds to reduce attack surface
D) Copy everything with `COPY . .`
E) Install only necessary packages

**Your answers:** _____ (list all correct letters)

#### Question 10 (10 points)
**Why should you avoid running containers as root?**

**Your answer (2-3 sentences):**
```
________________________________________________
________________________________________________
________________________________________________
```

### Part 4: Troubleshooting & Debugging (25 points)

#### Question 11 (10 points)
**A container exits immediately after starting. Which commands would help debug this? (Select all that apply)**

A) `docker logs container_name`
B) `docker ps -a`
C) `docker inspect container_name`
D) `docker run -it image_name /bin/bash`
E) `docker stats container_name`

**Your answers:** _____ (list all correct letters)

#### Question 12 (15 points)
**Scenario:** You built a Node.js application container, but it's not accessible on the expected port. List 5 debugging steps you would take:

1. ________________________________________________
2. ________________________________________________
3. ________________________________________________
4. ________________________________________________
5. ________________________________________________

## 🛠️ Practical Assessment

### Task 1: Dockerfile Creation (30 points)

**Create a Dockerfile for a Python Flask application with these requirements:**

- Use Python 3.11 Alpine base image
- Set working directory to `/app`
- Copy requirements.txt first, then install dependencies
- Copy application code
- Run as non-root user
- Expose port 5000
- Include health check
- Use proper layer caching

**Write your Dockerfile:**
```dockerfile
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
```

### Task 2: Container Management (20 points)

**Write the complete commands to:**

1. **Build an image** named `my-app:v1.0` from current directory:
   ```bash
   ________________________________________________
   ```

2. **Run the container** with:
   - Name: `flask-app`
   - Port mapping: host 8080 → container 5000
   - Environment variable: `ENV=production`
   - Run in background
   
   ```bash
   ________________________________________________
   ```

3. **Check container logs** with timestamps:
   ```bash
   ________________________________________________
   ```

4. **Execute interactive shell** in running container:
   ```bash
   ________________________________________________
   ```

5. **Stop and remove** the container:
   ```bash
   ________________________________________________
   ________________________________________________
   ```

### Task 3: Multi-Stage Build (25 points)

**Design a multi-stage Dockerfile for a React application:**

**Requirements:**
- Stage 1: Build the React app using Node.js
- Stage 2: Serve with nginx
- Copy only production build artifacts
- Security best practices

**Write your multi-stage Dockerfile:**
```dockerfile
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
```

## 🎯 Real-World Scenario

### Scenario: Production Deployment Issue (25 points)

You're deploying a microservice to production and encounter these issues:

1. **Container won't start** - exits with code 1
2. **Application not accessible** - can't reach the service
3. **Performance issues** - slow response times
4. **Security concerns** - running as root user

**For each issue, provide:**
- **Diagnosis steps** (what commands/tools to use)
- **Likely causes** (what might be wrong)
- **Solutions** (how to fix it)

#### Issue 1: Container Won't Start
**Diagnosis steps:**
```
________________________________________________
________________________________________________
```

**Likely causes:**
```
________________________________________________
________________________________________________
```

**Solutions:**
```
________________________________________________
________________________________________________
```

#### Issue 2: Application Not Accessible
**Diagnosis steps:**
```
________________________________________________
________________________________________________
```

**Likely causes:**
```
________________________________________________
________________________________________________
```

**Solutions:**
```
________________________________________________
________________________________________________
```

#### Issue 3: Performance Issues
**Diagnosis steps:**
```
________________________________________________
________________________________________________
```

**Likely causes:**
```
________________________________________________
________________________________________________
```

**Solutions:**
```
________________________________________________
________________________________________________
```

#### Issue 4: Security Concerns
**Diagnosis steps:**
```
________________________________________________
________________________________________________
```

**Likely causes:**
```
________________________________________________
________________________________________________
```

**Solutions:**
```
________________________________________________
________________________________________________
```

## 🏆 Bonus Challenge: Docker Compose Preview (15 points)

**Write a docker-compose.yml for a simple web application with:**
- Web service (your Node.js app)
- Database service (PostgreSQL)
- Proper networking
- Environment variables
- Volume for database persistence

```yaml
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
________________________________________________
```

## 📊 Self-Assessment Rubric

| Criteria | Excellent (4) | Good (3) | Fair (2) | Needs Improvement (1) |
|----------|---------------|----------|----------|-----------------------|
| **CLI Commands** | Knows all essential commands and options | Knows most commands with minor gaps | Basic command knowledge | Limited command knowledge |
| **Dockerfile Skills** | Writes optimized, secure Dockerfiles | Good Dockerfile structure with minor issues | Basic Dockerfile creation | Struggles with Dockerfile syntax |
| **Security Awareness** | Implements comprehensive security practices | Good security understanding | Basic security awareness | Minimal security consideration |
| **Troubleshooting** | Systematic debugging approach | Good problem-solving skills | Basic troubleshooting ability | Limited debugging skills |
| **Best Practices** | Consistently applies Docker best practices | Usually follows best practices | Some best practice awareness | Needs guidance on best practices |

**Your self-assessment scores:**
- CLI Commands: ___/4
- Dockerfile Skills: ___/4
- Security Awareness: ___/4
- Troubleshooting: ___/4
- Best Practices: ___/4

**Total Score: ___/20**

## ✅ Checkpoint Results

### Scoring Guide:
- **180-200 points**: Outstanding! Ready for advanced Docker topics
- **160-179 points**: Excellent understanding, minor review recommended
- **140-159 points**: Good grasp, practice recommended
- **120-139 points**: Fair understanding, review key concepts
- **Below 120 points**: Review chapter and complete additional practice

### Your Score: ___/200

### Areas for Improvement:
```
________________________________________________
________________________________________________
________________________________________________
```

### Strengths Demonstrated:
```
________________________________________________
________________________________________________
________________________________________________
```

## 🚀 Ready for Next Chapter?

**Prerequisites for Chapter 02: Docker Images**

Before proceeding, ensure you can:
- [ ] Build efficient Dockerfiles with proper layer caching
- [ ] Implement security best practices in containers
- [ ] Debug container startup and runtime issues
- [ ] Use multi-stage builds effectively
- [ ] Manage container lifecycle confidently
- [ ] Understand when and how to use different base images

### If you scored below 160 points:
1. **Review** the [main chapter](README.md) content
2. **Redo** the [lab exercises](lab/README.md) focusing on weak areas
3. **Practice** writing Dockerfiles for different application types
4. **Study** the troubleshooting section again
5. **Retake** this checkpoint

### If you scored 160+ points:
**Congratulations!** 🎉 You're ready to advance to [Chapter 02: Docker Images](../02-docker-images/README.md)

## 📚 Additional Practice

If you need more hands-on experience:

### Quick Exercises:
1. **Containerize a new language**: Try Go, Ruby, or Java
2. **Optimize for size**: Create the smallest possible image for a simple app
3. **Security hardening**: Implement all security best practices in one Dockerfile
4. **Debugging challenge**: Intentionally break containers and practice fixing them

### Study Resources:
- [Docker Official Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/)
- [Docker Security Guide](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)

## 🤝 Get Help

**Need support?**
- Review the [lab troubleshooting guide](lab/README.md#-troubleshooting)
- Join our [Discord community](https://discord.gg/docker-k8s)
- Attend virtual office hours (Tuesdays 6 PM EST)
- Check the [FAQ](../../../resources/faq.md)

---

**Answer Key Available:** After completing the checkpoint, ask your instructor for the answer key or check the solutions in the instructor resources.

**Remember:** Mastering Docker is about understanding concepts and applying them practically. Focus on hands-on practice!

<div align="center">

**[⬅️ Back to Chapter](README.md)** | **[Next: Docker Images ➡️](../02-docker-images/README.md)**

</div> 