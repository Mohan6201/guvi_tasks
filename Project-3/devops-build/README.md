# React E-Commerce Application — DevOps Deployment

## Task Description

Dockerize and deploy a React application on **AWS EC2**, automate builds with **Jenkins CI/CD**, push images to **DockerHub** (`dev` and `prod` repos), and monitor the app with **Prometheus + Grafana**.

---

## Tech Stack

- **Docker** — Containerize the React app
- **DockerHub** — Store images (`dev` public repo, `prod` private repo)
- **Jenkins** — CI/CD pipeline with GitHub Webhook auto-trigger
- **AWS EC2** — t2.micro instance to host the app and Jenkins
- **Prometheus + Grafana + Alertmanager** — Monitoring and alerting

---

## Project Structure

```
devops-build/
├── Dockerfile                    # nginx:alpine image serving React on port 80
├── docker-compose.yml            # Run app locally with docker-compose
├── nginx.conf                    # Custom nginx config with /health and /metrics
├── build.sh                      # Build and push Docker image to DockerHub
├── deploy.sh                     # Pull and run container on port 80
├── Jenkinsfile                   # Declarative pipeline — build, push, deploy
├── scripts/
│   └── setup_ec2.sh              # Installs Docker + Jenkins on EC2 (user_data)
├── aws/
│   ├── deploy-ec2.sh             # Provisions EC2 via AWS CLI
│   └── cleanup.sh                # Terminates EC2 and deletes resources
├── monitoring/
│   ├── docker-compose.yml        # Prometheus + Grafana + Alertmanager + Node Exporter
│   ├── prometheus.yml            # Scrape config (app, node-exporter, prometheus)
│   ├── alert_rules.yml           # Alert rules (app down, high CPU/memory/disk)
│   └── alertmanager.yml          # Email notification config
├── .env                          # Your credentials — never commit this
├── .env.example                  # Safe template to commit
├── .dockerignore
├── .gitignore
└── README.md
```

---

## Branch Strategy

| Branch | DockerHub Repo | Visibility |
|--------|---------------|------------|
| `dev` | `<username>/dev` | Public |
| `master` | `<username>/prod` | Private |

Every push to either branch **automatically triggers** a Jenkins build via GitHub Webhook.

---

## Environment Variables

All credentials are driven through environment variables — **nothing is hardcoded**.

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key |
| `AWS_DEFAULT_REGION` | AWS region (e.g. `us-east-1`) |
| `EC2_KEY_NAME` | EC2 key pair name |
| `DOCKERHUB_USERNAME` | DockerHub username |
| `DOCKERHUB_PASSWORD` | DockerHub password or access token |
| `SMTP_HOST` | SMTP server (e.g. `smtp.gmail.com`) |
| `SMTP_PORT` | SMTP port (e.g. `587`) |
| `SMTP_USER` | SMTP email address |
| `SMTP_PASSWORD` | Gmail App Password |
| `ALERT_EMAIL` | Email to receive monitoring alerts |

---

## Prerequisites

1. **AWS Account** with EC2 permissions
2. **AWS CLI** installed and configured
3. **DockerHub account** with two repos created:
   - `<username>/dev` — set to **Public**
   - `<username>/prod` — set to **Private**
4. **EC2 Key Pair** in your target region
5. **Gmail App Password** for monitoring alerts

---

## Step-by-Step Setup

### Step 1 — Fork the Repository

Fork the source repo and clone your fork:

```bash
git clone https://github.com/<your-username>/devops-build.git
cd devops-build
```

Create the `dev` branch:

```bash
git checkout -b dev
git push origin dev
```

---

### Step 2 — Set Up `.env`

```bash
cp .env.example .env
```

Fill in all values in `.env`. Never commit this file.

---

### Step 3 — Load Environment Variables

**Linux / macOS:**
```bash
export $(cat .env | grep -v '#' | xargs)
```

**Windows (PowerShell):**
```powershell
Get-Content .env | Where-Object { $_ -notmatch '^#' -and $_ -ne '' } | ForEach-Object {
    $key, $value = $_ -split '=', 2
    [System.Environment]::SetEnvironmentVariable($key, $value, 'Process')
}
```

---

### Step 4 — Test Docker Build Locally

```bash
# Build the image
docker build -t ecommerce-app .

# Run it
docker run -p 80:80 ecommerce-app

# Verify
curl http://localhost/health
# Expected: healthy
```

---

### Step 5 — Create DockerHub Repositories

1. Log in to [hub.docker.com](https://hub.docker.com)
2. Create repository `<username>/dev` → set to **Public**
3. Create repository `<username>/prod` → set to **Private**

---

### Step 6 — Provision EC2 with AWS CLI

```bash
cd aws
chmod +x deploy-ec2.sh
./deploy-ec2.sh prod
```

This will:
1. Detect your current IP automatically
2. Create a Security Group:
   - Port 80: open to `0.0.0.0/0` (public)
   - Port 8080: open to `0.0.0.0/0` (Jenkins)
   - Port 22: open to **your IP only**
3. Launch a `t2.micro` Ubuntu EC2 instance
4. Run `scripts/setup_ec2.sh` on boot — installs Docker and Jenkins automatically

Note the output — you need the public IP for the next steps.

---

### Step 7 — Unlock Jenkins

Wait **3-5 minutes** for the instance to boot, then:

```bash
ssh -i <your-key>.pem ubuntu@<public_ip>
./get_jenkins_password.sh
```

Open `http://<public_ip>:8080` and unlock Jenkins with the password.

Install **suggested plugins**, then create your admin user.

---

### Step 8 — Install Additional Jenkins Plugins

Go to **Manage Jenkins > Plugins > Available plugins** and install:

| Plugin | Purpose |
|--------|---------|
| **Docker Pipeline** | Run Docker commands in pipeline |
| **GitHub** | GitHub webhook integration |
| **Pipeline** | Declarative Jenkinsfile support |

Restart Jenkins after installation.

---

### Step 9 — Add DockerHub Credentials to Jenkins

1. Go to **Manage Jenkins > Credentials > System > Global credentials**
2. Click **Add Credentials**
   - Kind: **Username with password**
   - Username: your DockerHub username
   - Password: your DockerHub password or access token
   - ID: `dockerhub-creds` ← must match the Jenkinsfile exactly
3. Click **Save**

---

### Step 10 — Create Jenkins Pipeline Job

1. Click **New Item** → name it `ecommerce-pipeline` → select **Pipeline** → OK
2. Under **Build Triggers**, check **GitHub hook trigger for GITScm polling**
3. Under **Pipeline**, select **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: your GitHub repo URL
   - Branches to build: `*/dev` and `*/master` (click Add Branch)
   - Script Path: `Jenkinsfile`
4. Click **Save**

---

### Step 11 — Set Up GitHub Webhook

1. Go to your GitHub repo → **Settings > Webhooks > Add webhook**
2. Fill in:
   - **Payload URL:** `http://<jenkins_public_ip>:8080/github-webhook/`
   - **Content type:** `application/json`
   - **Events:** Just the **push** event
3. Click **Add webhook** — verify the green tick

---

### Step 12 — Test the Full Pipeline

**Test 1 — Push to `dev` branch:**
```bash
echo "# test" >> README.md
git add README.md
git commit -m "trigger dev build"
git push origin dev
```

Expected:
- Jenkins auto-triggers
- Docker image built and pushed to `<username>/dev`
- App deployed on port 80

**Test 2 — Merge `dev` to `master`:**
```bash
git checkout master
git merge dev
git push origin master
```

Expected:
- Jenkins auto-triggers
- Docker image built and pushed to `<username>/prod` (private)
- App deployed on port 80

---

### Step 13 — Start Monitoring Stack

SSH into the EC2 instance:

```bash
ssh -i <your-key>.pem ubuntu@<public_ip>
```

Update `monitoring/alertmanager.yml` with your SMTP credentials, then start:

```bash
cd monitoring
docker-compose up -d
```

Access monitoring:
- **Grafana:** `http://<public_ip>:3001` (admin / admin)
- **Prometheus:** `http://<public_ip>:9090`
- **Alertmanager:** `http://<public_ip>:9093`

In Grafana:
1. Go to **Connections > Data Sources > Add** → Select **Prometheus**
2. URL: `http://localhost:9090` → **Save & Test**
3. Go to **Dashboards > Import** → Enter ID `1860` → **Import**

---

### Step 14 — Verify App and Monitoring

```bash
# App health check
curl http://<public_ip>/health
# Expected: healthy

# App metrics
curl http://<public_ip>/metrics
# Expected: application_up 1
```

Test alert by stopping the container:
```bash
docker stop ecommerce-prod
# Wait ~1 minute — Alertmanager sends email alert
docker start ecommerce-prod
```

---

### Step 15 — Cleanup

```bash
cd aws
chmod +x cleanup.sh
./cleanup.sh prod
```

---

## Security Group Configuration

| Port | Source | Purpose |
|------|--------|---------|
| `80` | `0.0.0.0/0` | Public app access |
| `8080` | `0.0.0.0/0` | Jenkins UI |
| `22` | `<YOUR-IP>/32` | SSH — your IP only |

---

## Submission

- GitHub repo URL (with `dev` and `master` branches)
- Deployed site URL: `http://<EC2-public-IP>`
- DockerHub images: `<username>/dev` and `<username>/prod`
- Screenshots in repo:
  - Jenkins pipeline — successful build console output
  - Jenkins pipeline configuration page
  - AWS EC2 console — instance running
  - Security Group — showing port 22 restricted to your IP
  - DockerHub `dev` repo with image tags
  - DockerHub `prod` repo with image tags
  - Deployed app in browser at EC2 IP
  - Monitoring dashboard (Grafana)
