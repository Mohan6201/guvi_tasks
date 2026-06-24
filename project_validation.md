# GUVI DevOps Projects — Requirements & Sanity Test Checklist

**Batch:** DO-C-WE-E-B19 | **Student:** U.Mohana Srinivasan | **Email:** mohandevopssme@gmail.com

---

## Table of Contents

- [Project 1 — MindTrack (Brain Tasks App)](#project-1--mindtrack-brain-tasks-app)
- [Project 2 — TrendStore](#project-2--trendstore)
- [Project 3 — React E-Commerce Application](#project-3--react-e-commerce-application)

---

---

# Project 1 — MindTrack (Brain Tasks App)

> **Type:** Application Deployment — Deploy the given React application to a production-ready state

## Official Requirements

### Application
- Clone the repository and deploy the application (Run on port **3000**)
- Repo URL: https://github.com/Vennilavanguvi/Brain-Tasks-App.git

### Docker
- Dockerize the application by creating a `Dockerfile`
- Build the application and check output using docker image

### Registry
- Create an **AWS ECR** or **DockerHub** repository for storing docker images

### Kubernetes
- Setup Kubernetes in **AWS EKS** and confirm EKS cluster is running
- Write `deployment.yaml` and `service.yaml` files
- Deploy using `kubectl` via CodeBuild or CodePipeline

### CodeBuild
- Create a CodeBuild project
  - Source: Connect to your repository
  - Environment: Use managed image (Amazon Linux / Ubuntu)
  - Write and define commands in `buildspec.yml`

### Version Control
- Push the codebase to GitHub
- Use CLI commands to push code

### CodePipeline
- Source: GitHub
- Build: AWS CodeBuild project
- Deploy: Deploy to EKS via CodePipeline EKS deploy stage

### Monitoring
- Use **CloudWatch Logs** to track build, deploy, and application logs

### Submission Guidelines
- GitHub Link: Submit full code repository
- README File: Include setup instructions, pipeline explanation, and screenshots
- Application deployed Kubernetes LoadBalancer ARN

---

## Sanity Test Checklist — Project 1

### Phase 1: Repository & Code

- [ ] GitHub repo URL is accessible and public
- [ ] Repo contains: `Dockerfile`, `buildspec.yml`, `k8s/deployment.yaml`, `k8s/service.yaml`, `README.md`
- [ ] `.dockerignore` and `.gitignore` are present
- [ ] **No hardcoded values** — AWS Account ID, Region, ECR URL, Cluster Name must all be environment variables

**Verify:**
```bash
# Check repo structure
git clone <your-repo-url>
ls -la
```

---

### Phase 2: Docker

- [ ] Dockerfile exposes port `3000`
- [ ] Docker build succeeds

```bash
docker build -t mindtrack .
# Expected: Successfully built <image-id>

docker run -p 3000:3000 mindtrack
# Expected: App loads on http://localhost:3000
```

---

### Phase 3: AWS ECR

- [ ] ECR repository exists
- [ ] Image is pushed with a proper tag (`latest` or git commit SHA)

```bash
aws ecr describe-images \
  --repository-name <repo-name> \
  --region <region>
# Expected: At least one image listed with imageTags
```

---

### Phase 4: EKS Cluster

- [ ] EKS cluster is running
- [ ] Nodes are in `Ready` state
- [ ] Pods are in `Running` state
- [ ] LoadBalancer service has an `EXTERNAL-IP`
- [ ] App is accessible via `EXTERNAL-IP:3000`

```bash
kubectl get nodes
# Expected: STATUS = Ready

kubectl get pods -n brain-tasks
# Expected: STATUS = Running

kubectl get svc -n brain-tasks
# Expected: EXTERNAL-IP is populated (not <pending>)

curl http://<EXTERNAL-IP>:3000
# Expected: HTML response from React app
```

---

### Phase 5: CodeBuild

- [ ] CodeBuild project exists
- [ ] `buildspec.yml` has all phases: `install` → `pre_build` (ECR login) → `build` (docker build) → `post_build` (docker push + kubectl apply)
- [ ] Environment variables in CodeBuild: `ECR_REPO`, `AWS_REGION`, `EKS_CLUSTER_NAME` — NOT hardcoded
- [ ] Last build status: **SUCCEEDED**

**Required `buildspec.yml` structure:**
```yaml
version: 0.2
env:
  variables:
    AWS_REGION: ""        # Set in CodeBuild env vars
    ECR_REPO: ""          # Set in CodeBuild env vars
    EKS_CLUSTER_NAME: ""  # Set in CodeBuild env vars
phases:
  pre_build:
    commands:
      - aws ecr get-login-password --region $AWS_REGION | docker login ...
  build:
    commands:
      - docker build -t $ECR_REPO:$CODEBUILD_RESOLVED_SOURCE_VERSION .
  post_build:
    commands:
      - docker push $ECR_REPO:$CODEBUILD_RESOLVED_SOURCE_VERSION
      - kubectl apply -f k8s/
```

---

### Phase 6: CodePipeline

- [ ] Pipeline exists with stages: `Source (GitHub)` → `Build (CodeBuild)` → `Deploy (EKS)`
- [ ] Last execution status: **Succeeded**
- [ ] A commit to GitHub **automatically triggers** the pipeline

```bash
# Test auto-trigger:
echo "test" >> README.md
git add README.md && git commit -m "trigger test" && git push origin main
# Expected: Pipeline starts within 1 minute in AWS Console
```

---

### Phase 7: Monitoring

- [ ] CloudWatch log group exists for CodeBuild
- [ ] Application logs are visible in CloudWatch

```bash
aws logs describe-log-groups \
  --log-group-name-prefix /aws/codebuild/<project-name>
```

---

### Phase 8: Submission Checklist

- [ ] GitHub repo URL submitted
- [ ] README has: setup steps + pipeline explanation + screenshots
- [ ] LoadBalancer EXTERNAL-IP / ARN documented
- [ ] ECR image name with tag documented
- [ ] Screenshots in repo:
  - [ ] ECR repository with image tags
  - [ ] EKS cluster nodes (`kubectl get nodes`)
  - [ ] CodePipeline execution (Succeeded)
  - [ ] Deployed app in browser
  - [ ] CloudWatch logs

---

---

# Project 2 — TrendStore

> **Type:** Application Deployment — Deploy the given React application to a production-ready state

## Official Requirements

### Application
- Clone the repository and deploy the application (Run on port **3000**)
- Repo URL: https://github.com/Vennilavanguvi/Trend.git

### Docker
- Dockerize the application by creating a `Dockerfile`
- Build the application and check output using docker image

### Terraform
- Define infrastructure in `main.tf` to create VPC, IAM, EC2 with Jenkins, etc.
- Use terraform commands to provision infrastructure

### DockerHub
- Create a DockerHub repository

### Kubernetes
- Setup Kubernetes in **AWS EKS** and confirm EKS cluster is running
- Write `deployment.yaml` and `service.yaml` files
- Deploy using `kubectl` via Jenkins

### Version Control
- Push the codebase to GitHub
- Add `.gitignore` and `.dockerignore` files
- Use CLI commands to push code

### Jenkins
- Install Jenkins and necessary plugins: Docker, Git, Kubernetes, Pipeline
- Setup GitHub and Jenkins integration using **GitHub Webhook** build trigger for auto build on every commit
- Create a **declarative pipeline script** and pipeline project to build, push & deploy using CI/CD

### Monitoring
- Setup a monitoring system to check health of the cluster or application (open-source) — highly appreciable

### Submission Guidelines
- GitHub Link: Submit full code repository
- README File: Include setup instructions, pipeline explanation, and screenshots
- Application deployed Kubernetes LoadBalancer ARN

---

## Sanity Test Checklist — Project 2

### Phase 1: Repository & Code

- [ ] GitHub repo URL is accessible
- [ ] Repo contains: `Dockerfile`, `Jenkinsfile`, `terraform/main.tf`, `terraform/variables.tf`, `k8s/deployment.yaml`, `k8s/service.yaml`, `README.md`
- [ ] `.dockerignore` and `.gitignore` are present
- [ ] **No hardcoded values** — DockerHub credentials, AWS keys, Jenkins URL must all be environment variables

---

### Phase 2: Docker

- [ ] Dockerfile exposes port `3000`
- [ ] Docker build succeeds

```bash
docker build -t trendstore .
# Expected: Successfully built <image-id>

docker run -p 3000:3000 trendstore
# Expected: App loads on http://localhost:3000
```

---

### Phase 3: Terraform

- [ ] `main.tf` defines: VPC, Subnets, Security Groups, EC2 (Jenkins), IAM roles
- [ ] All values are in `variables.tf` — NOT hardcoded in `main.tf`
- [ ] Terraform init, plan, apply all succeed
- [ ] Jenkins EC2 is running and accessible on port `8080`

```bash
terraform init
# Expected: Terraform has been successfully initialized

terraform plan
# Expected: No errors, shows resources to create

terraform apply -auto-approve
# Expected: Apply complete! Resources: X added

terraform show
# Expected: EC2 instance, VPC, SGs listed

# Verify Jenkins EC2
curl http://<EC2-public-ip>:8080
# Expected: Jenkins login page
```

---

### Phase 4: DockerHub

- [ ] DockerHub repository exists for TrendStore
- [ ] Image is pushed with a tag

```bash
docker login
# Expected: Login Succeeded

docker pull <dockerhub-username>/trendstore:latest
# Expected: Pull complete
```

---

### Phase 5: EKS Cluster

- [ ] EKS cluster is running
- [ ] Nodes are `Ready`
- [ ] Pods are `Running`
- [ ] LoadBalancer `EXTERNAL-IP` is populated
- [ ] App accessible at `EXTERNAL-IP:3000`

```bash
kubectl get nodes
kubectl get pods
kubectl get svc
curl http://<EXTERNAL-IP>:3000
```

---

### Phase 6: Jenkins

- [ ] Jenkins accessible at `http://<EC2-IP>:8080`
- [ ] Plugins installed: Docker, Git, Kubernetes, Pipeline
- [ ] GitHub Webhook configured: `http://<Jenkins-IP>:8080/github-webhook/`
- [ ] A commit to GitHub **auto-triggers** Jenkins pipeline

```bash
# Verify webhook in GitHub:
# Repo → Settings → Webhooks → Check payload URL and Last delivery (green tick)
```

- [ ] Jenkinsfile is a **Declarative Pipeline**
- [ ] Pipeline stages: `Checkout` → `Build Docker Image` → `Push to DockerHub` → `Deploy to EKS`
- [ ] DockerHub credentials stored in **Jenkins Credentials Manager** (not hardcoded in Jenkinsfile)
- [ ] Last build status: **SUCCESS**
- [ ] Console output shows `kubectl apply` ran successfully

**Required Jenkinsfile structure:**
```groovy
pipeline {
  agent any
  environment {
    DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')  // Jenkins credentials ID
    IMAGE_NAME = "${DOCKERHUB_USERNAME}/trendstore"
    EKS_CLUSTER = "${EKS_CLUSTER_NAME}"
  }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Build') { steps { sh 'docker build -t $IMAGE_NAME:$BUILD_NUMBER .' } }
    stage('Push') {
      steps {
        sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
        sh 'docker push $IMAGE_NAME:$BUILD_NUMBER'
      }
    }
    stage('Deploy') { steps { sh 'kubectl apply -f k8s/' } }
  }
}
```

---

### Phase 7: Monitoring

- [ ] Monitoring tool is set up (Prometheus+Grafana / Uptime Kuma / Netdata)
- [ ] EKS cluster health/metrics are visible on dashboard
- [ ] Alert configured for app down → sends notification

```bash
# If Prometheus+Grafana on EKS:
kubectl get pods -n monitoring
# Expected: prometheus and grafana pods Running

kubectl get svc -n monitoring
# Expected: Grafana service with EXTERNAL-IP
# Access Grafana at http://<EXTERNAL-IP>:3000
```

---

### Phase 8: Submission Checklist

- [ ] GitHub repo URL submitted
- [ ] README has: setup + pipeline + screenshots
- [ ] LoadBalancer EXTERNAL-IP / ARN documented
- [ ] DockerHub image name with tag documented
- [ ] Screenshots in repo:
  - [ ] Jenkins pipeline (Successful run + console output)
  - [ ] Terraform apply output / provisioned infra
  - [ ] EKS nodes and pods
  - [ ] DockerHub repo with image tags
  - [ ] Deployed app in browser
  - [ ] Monitoring dashboard

---

---

# Project 3 — React E-Commerce Application

> **Type:** Application Deployment — Deploy the given React application to a production-ready state

## Official Requirements

### Application
- Clone the repository and deploy the application (Run on port **80** HTTP)
- Repo URL: https://github.com/sriram-R-krishnan/devops-build

### Docker
- Dockerize the application by creating a `Dockerfile`
- Create a `docker-compose.yml` file to use the above image

### Bash Scripting
Write 2 scripts:
- `build.sh` — for building docker images
- `deploy.sh` — for deploying the image to server

### Version Control
- Push the code to GitHub to **`dev` branch**
- Use `.dockerignore` and `.gitignore` files
- Use only CLI for all git commands

### DockerHub
- Create 2 repos: **`dev`** (public) and **`prod`** (private) to push images
- `prod` repo must be **private**, `dev` repo can be **public**

### Jenkins
- Install and configure Jenkins build steps to build, push & deploy the application
- Connect Jenkins to the GitHub repo with **auto build trigger from both `dev` and `master` branches**
- If code pushed to `dev` branch → docker image must build and push to **`dev`** repo in DockerHub
- If `dev` is merged to `master` → docker image must push to **`prod`** repo in DockerHub

### AWS
- Launch **t2.micro** instance and deploy the application
- Configure Security Group:
  - **Port 80** — Whoever has the IP address can access the application (`0.0.0.0/0`)
  - **Port 22 (SSH)** — Login to server must be allowed **only from your IP address**

### Monitoring
- Setup a monitoring system to check the health status of the application (open-source)
- Sending notifications only if the application goes down is highly appreciable

### Submission Guidelines
- GitHub repo URL, deployed site URL, docker image names must be added in the submission
- Upload screenshots to GitHub repo:
  - Jenkins (login page, configuration settings, execute step commands)
  - AWS (EC2 Console, SG configs)
  - DockerHub repo with image tags
  - Deployed site page
  - Monitoring health check status

---

## Sanity Test Checklist — Project 3

### Phase 1: Repository & Code

- [ ] GitHub repo is your fork of `https://github.com/sriram-R-krishnan/devops-build`
- [ ] Both `dev` and `master` branches exist
- [ ] Repo contains: `Dockerfile`, `docker-compose.yml`, `build.sh`, `deploy.sh`, `Jenkinsfile`, `.dockerignore`, `.gitignore`
- [ ] **No hardcoded values** — DockerHub credentials, EC2 IP must all be environment variables

```bash
git branch -a
# Expected: dev and master (or main) branches visible
```

---

### Phase 2: Docker & Docker Compose

- [ ] Dockerfile exposes port `80`
- [ ] `docker-compose.yml` uses the built image and maps port 80

```bash
docker build -t ecommerce-app .
# Expected: Successfully built

docker-compose up -d
# Expected: Container starts, app loads on http://localhost:80
```

---

### Phase 3: Bash Scripts

- [ ] `build.sh` — builds, tags, and pushes image to DockerHub `dev` repo
- [ ] `deploy.sh` — pulls and runs container on port 80
- [ ] DockerHub username/password passed as **environment variables** in both scripts

```bash
# Test build script
export DOCKERHUB_USERNAME=<your-username>
export DOCKERHUB_PASSWORD=<your-token>
chmod +x build.sh && ./build.sh
# Expected: Image built and pushed to DockerHub dev repo

# Test deploy script
chmod +x deploy.sh && ./deploy.sh
# Expected: Container running, app accessible on port 80
```

**build.sh must look like:**
```bash
#!/bin/bash
IMAGE_NAME="${DOCKERHUB_USERNAME}/dev"
TAG="${BUILD_NUMBER:-latest}"
docker build -t $IMAGE_NAME:$TAG .
echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
docker push $IMAGE_NAME:$TAG
```

---

### Phase 4: DockerHub

- [ ] `dev` repo exists and is **public**
- [ ] `prod` repo exists and is **private**
- [ ] Both repos have images pushed with tags

```bash
# Verify on hub.docker.com
# <your-username>/dev → public, has image tags
# <your-username>/prod → private, has image tags
```

---

### Phase 5: AWS EC2

- [ ] EC2 instance type is `t2.micro`
- [ ] App is running and accessible at `http://<EC2-public-IP>`

```bash
curl http://<EC2-public-IP>
# Expected: HTML from React app
```

---

### Phase 6: Security Group Verification

- [ ] **Port 80 Inbound**: Source = `0.0.0.0/0` ✅ (public access)
- [ ] **Port 22 Inbound**: Source = `<YOUR-IP>/32` only ✅ (not 0.0.0.0/0)
- [ ] No other unnecessary ports open

```bash
# Verify via AWS CLI
aws ec2 describe-security-groups \
  --group-ids <sg-id> \
  --query 'SecurityGroups[0].IpPermissions'
```

---

### Phase 7: Jenkins Pipeline

- [ ] Jenkins running on EC2 port `8080`
- [ ] GitHub Webhook configured for both `dev` and `master` branches
- [ ] Pipeline logic verified:

**Test Flow 1 — Push to dev:**
```bash
# Make a small change
echo "# test" >> README.md
git add README.md
git commit -m "test dev trigger"
git push origin dev
# Expected:
# 1. Jenkins auto-triggers
# 2. Docker image built
# 3. Image pushed to DockerHub "dev" repo
# 4. New tag visible on hub.docker.com/<username>/dev
```

**Test Flow 2 — Merge dev to master:**
```bash
git checkout master
git merge dev
git push origin master
# Expected:
# 1. Jenkins auto-triggers
# 2. Docker image built
# 3. Image pushed to DockerHub "prod" repo (private)
# 4. New tag visible on hub.docker.com/<username>/prod
```

---

### Phase 8: Monitoring

- [ ] Monitoring tool installed (Prometheus+Grafana / Uptime Kuma / Netdata)
- [ ] Application health status visible on dashboard
- [ ] Alert configured: if app goes down → notification sent (email/Slack/webhook)

**Test alert:**
```bash
# Stop the app container
docker stop <container-name>
# Expected: Alert fires within configured interval
# Then restart:
docker start <container-name>
```

---

### Phase 9: Submission Checklist

- [ ] GitHub repo URL (with `dev` + `master` branches)
- [ ] Deployed site URL: `http://<EC2-public-IP>`
- [ ] DockerHub image names: `<username>/dev` and `<username>/prod`
- [ ] README with setup + pipeline explanation
- [ ] Screenshots uploaded to GitHub repo:
  - [ ] Jenkins login page
  - [ ] Jenkins pipeline configuration
  - [ ] Jenkins execute step / console output (Successful run)
  - [ ] AWS EC2 Console (instance running)
  - [ ] Security Group config (port 80 open, port 22 restricted)
  - [ ] DockerHub `dev` repo with image tags
  - [ ] DockerHub `prod` repo with image tags
  - [ ] Deployed site page (browser screenshot at EC2 IP)
  - [ ] Monitoring health check dashboard

---

---

## Quick Environment Variable Reference

> All projects must use environment variables for sensitive/configurable values. Never hardcode these.

| Variable | Used In | Example Value |
|----------|---------|---------------|
| `AWS_REGION` | Project 1, 2 | `ap-south-1` |
| `ECR_REPO` | Project 1 | `123456789.dkr.ecr.ap-south-1.amazonaws.com/mindtrack` |
| `EKS_CLUSTER_NAME` | Project 1, 2 | `brain-tasks-cluster` |
| `DOCKERHUB_USERNAME` | Project 2, 3 | `mohan6201` |
| `DOCKERHUB_PASSWORD` | Project 2, 3 | Store in Jenkins Credentials / Secrets Manager |
| `IMAGE_TAG` | Project 2, 3 | `$BUILD_NUMBER` or `$GIT_COMMIT` |
| `EC2_PUBLIC_IP` | Project 3 | `13.x.x.x` |

---

*Generated for GUVI Zen Class — DevOps Batch DO-C-WE-E-B19*