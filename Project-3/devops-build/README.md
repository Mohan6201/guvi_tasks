# devops-build — DevOps Deployment

## Task Description

Dockerize and deploy the [sriram-R-krishnan/devops-build](https://github.com/sriram-R-krishnan/devops-build) React app (ships as a pre-built `build/` folder) on **AWS EC2**, automate builds with **Jenkins CI/CD**, push images to **DockerHub** (`dev` and `prod` repos), and monitor the app with **Prometheus + Grafana**.

---

## Tech Stack

- **Docker** — Containerize the React app
- **DockerHub** — Store images (`dev` public repo, `prod` private repo)
- **Jenkins** — Multibranch Pipeline, `dev`/`main` tracked and auto-triggered independently via GitHub Webhook
- **AWS EC2** — two `t2.micro` instances: one runs the app, a separate one runs Jenkins
- **Prometheus + Grafana + Alertmanager** — Monitoring and alerting, running on the app instance

---

## Project Structure

```
devops-build/
├── Dockerfile                    # nginx:alpine image serving React on port 80
├── docker-compose.yml            # Run app locally with docker-compose
├── nginx.conf                    # Custom nginx config with /health and /metrics
├── build.sh                      # Build and push Docker image to DockerHub
├── deploy.sh                     # SSH to the app server, pull and run the container
├── Jenkinsfile                   # Declarative pipeline — build, push, deploy
├── scripts/
│   ├── setup_app.sh              # Installs Docker only (app instance user_data)
│   └── setup_jenkins.sh          # Installs Docker + Jenkins (Jenkins instance user_data)
├── aws/
│   ├── provision-app.sh          # Provisions the app EC2 instance via AWS CLI
│   ├── provision-jenkins.sh      # Provisions the Jenkins EC2 instance via AWS CLI
│   └── cleanup.sh                # Terminates EC2 instance(s) and deletes resources
├── monitoring/
│   ├── docker-compose.yml        # Prometheus + Grafana + Alertmanager + Node Exporter
│   ├── prometheus.yml            # Scrape config (app, node-exporter, prometheus)
│   ├── alert_rules.yml           # Alert rules (app down, high CPU/memory/disk)
│   ├── alertmanager.yml.template # Email notification config (placeholders, tracked)
│   └── render-config.sh          # Renders alertmanager.yml from the template + .env
├── .env                          # Your credentials — never commit this
├── .env.example                  # Safe template to commit
├── .dockerignore
├── .gitignore
└── README.md
```

---

## Why two EC2 instances

The spec only names one `t2.micro` for the app. Jenkins gets its own separate `t2.micro`
because building Docker images, running Jenkins, and running the live app container on a
single `t2.micro` (1 vCPU / 1 GB RAM) is too tight in practice. The monitoring stack runs
on the **app** instance, so the total stays at two instances.

---

## Branch Strategy

| Branch | DockerHub Repo | Visibility |
|--------|---------------|------------|
| `dev` | `<username>/dev` | Public |
| `master`/`main` | `<username>/prod` | Private |

Every push to either branch **automatically triggers** a Jenkins build via GitHub Webhook.
`build.sh`/`deploy.sh` treat `main` the same as `master`, since this app lives in a monorepo
whose default branch is `main`.

---

## Environment Variables

All credentials are driven through environment variables — **nothing is hardcoded**.

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key |
| `AWS_DEFAULT_REGION` | AWS region (e.g. `us-east-1`) |
| `EC2_KEY_NAME` | EC2 key pair name (shared by both instances) |
| `DOCKERHUB_USERNAME` | DockerHub username |
| `DOCKERHUB_PASSWORD` | DockerHub password or access token |
| `APP_SERVER_HOST` | Public IP/DNS of the app EC2 instance — `deploy.sh` SSHes here |
| `APP_SERVER_SSH_USER` | SSH user for the app instance (default `ubuntu`) |
| `APP_SERVER_SSH_KEY_PATH` | Local path to the `.pem` key used to SSH into the app instance |
| `SMTP_HOST` | SMTP server (e.g. `smtp.gmail.com`) |
| `SMTP_PORT` | SMTP port (e.g. `587`) |
| `SMTP_USER` | SMTP email address |
| `SMTP_PASSWORD` | Gmail App Password |
| `ALERT_EMAIL` | Email to receive monitoring alerts |

In Jenkins, `APP_SERVER_HOST` and the SSH key/user come from Jenkins credentials
(`app-server-host`, `app-server-ssh-key`) instead of `.env` — see Step 9.

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

**Quoting passwords that contain `#`, spaces, or other special characters:** wrap the
value in single quotes, e.g. `DOCKERHUB_PASSWORD='abc#123'`. Use single quotes, not
double — double quotes still let bash expand `$` and backticks inside the value, which
a real password could easily contain. (If a password itself contains a single quote,
ask and we'll handle that one specially.)

---

### Step 3 — Load Environment Variables

**Linux / macOS / Git Bash:**
```bash
set -a
source .env
set +a
```
Don't use `export $(cat .env | grep -v '#' | xargs)` — it breaks on any value containing
`#` (grep treats the whole line as a comment and silently drops it, even inside quotes)
or spaces (xargs word-splits it). `source` parses the file as real shell syntax instead,
so quoted values with `#`/spaces load correctly.

**Windows (PowerShell):**
```powershell
Get-Content .env | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' } | ForEach-Object {
    $key, $value = $_ -split '=', 2
    $value = $value.Trim().Trim("'").Trim('"')
    [System.Environment]::SetEnvironmentVariable($key, $value, 'Process')
}
```

---

### Step 4 — Test Docker Build Locally

```bash
docker build -t devops-build-app .
docker run -p 80:80 devops-build-app

curl http://localhost/health
# Expected: healthy
```

---

### Step 5 — Create DockerHub Repositories

1. Log in to [hub.docker.com](https://hub.docker.com)
2. Create repository `<username>/dev` → set to **Public**
3. Create repository `<username>/prod` → set to **Private**

Use exactly these two names — `dev` and `prod` — not a variant like `<project>-dev`. Docker Hub
auto-creates a repository on the first `docker push` to a name that doesn't exist yet, and
`build.sh`/`deploy.sh`/the Jenkinsfile always push to `<username>/dev` and `<username>/prod`
literally. If you skip this step, both get created automatically on first push anyway — but
**auto-created repositories always default to Public**, so if you let `prod` auto-create you
must go back afterward (repo → Settings → Visibility) and switch it to Private by hand, or the
"prod must be private" requirement silently fails even though everything else works.

---

### Step 6 — Provision the App EC2 Instance

```bash
cd aws
chmod +x provision-app.sh
./provision-app.sh
```

This will:
1. Detect your current IP automatically
2. Create a Security Group:
   - Port 80: open to `0.0.0.0/0` (public app access)
   - Port 22: open to **your IP only**
3. Launch a `t2.micro` Ubuntu EC2 instance and install Docker via `scripts/setup_app.sh`

Note the public IP in `app-instance-info.txt` — set it as `APP_SERVER_HOST` in `.env`, and
`APP_SERVER_SSH_KEY_PATH` to the generated `<EC2_KEY_NAME>.pem`.

---

### Step 7 — Provision the Jenkins EC2 Instance

```bash
./provision-jenkins.sh
```

This will:
1. Create a Security Group:
   - Port 8080: open to `0.0.0.0/0` (Jenkins UI + GitHub webhook delivery)
   - Port 22: open to **your IP only**
2. Launch a second `t2.micro` Ubuntu EC2 instance and install Docker + Jenkins via
   `scripts/setup_jenkins.sh`

Wait **3-5 minutes** for the instance to boot, then:

```bash
ssh -i <your-key>.pem ubuntu@<jenkins_public_ip>
./get_jenkins_password.sh
```

Open `http://<jenkins_public_ip>:8080` and unlock Jenkins with the password.
Install **suggested plugins**, then create your admin user.

---

### Step 8 — Install Additional Jenkins Plugins

Go to **Manage Jenkins > Plugins > Available plugins** and install:

| Plugin | Purpose |
|--------|---------|
| **Docker Pipeline** | Run Docker commands in pipeline |
| **GitHub** | GitHub webhook integration |
| **GitHub Branch Source** | Powers the Multibranch Pipeline job in Step 10 — discovers `dev`/`main` independently and lets the same webhook trigger just the branch that changed |
| **Pipeline** | Declarative Jenkinsfile support |
| **SSH Agent** | Provides the `sshUserPrivateKey` credential binding used to deploy |

Restart Jenkins after installation.

---

### Step 9 — Add Credentials to Jenkins

Go to **Manage Jenkins > Credentials > System > Global credentials** and add three:

1. **DockerHub** — Kind: `Username with password`, ID: `dockerhub-creds` ← must match the Jenkinsfile
2. **App server SSH key** — Kind: `SSH Username with private key`, Username: `ubuntu`,
   Private key: paste the contents of `<EC2_KEY_NAME>.pem`, ID: `app-server-ssh-key`
3. **App server host** — Kind: `Secret text`, Secret: the app instance's **private** IP
   (not public — Jenkins and the app share a VPC/subnet, and connecting to the app's
   public IP from another instance in the same VPC hits AWS's Internet Gateway round-trip
   and doesn't reliably match security-group-referenced ingress rules, causing SSH to hang
   and time out even though the rule looks correct), ID: `app-server-host`. Your local
   `.env`'s `APP_SERVER_HOST` stays the public IP — your laptop isn't in that VPC.

---

### Step 10 — Create Jenkins Pipeline Job (Multibranch Pipeline)

Use a **Multibranch Pipeline**, not a plain "Pipeline" job — this matters, not just a naming
preference. A plain "Pipeline script from SCM" job with two hardcoded branch specs
(`*/dev` and `*/main`) plus a GitHub push trigger looks like it should auto-build both branches,
but it doesn't reliably: Jenkins' lightweight-checkout polling only tracks change-detection for
one branch spec at a time, so pushes to whichever branch it isn't currently tracking silently
never trigger a build — confirmed live, where GitHub's own webhook log showed a `main` push
delivered successfully (`200 OK`) while zero builds were ever created for it. A Multibranch
Pipeline discovers and tracks each branch independently and doesn't have this problem.

1. Click **New Item** → name it `devops-build-pipeline` → select **Multibranch Pipeline** → OK
2. Under **Branch Sources**, click **Add source** → **GitHub**
   - Credentials: leave as `- none -` first (a public repo doesn't need one). Only add a
     Personal Access Token credential here if a later scan fails with a rate-limit error —
     anonymous GitHub API access is capped at 60 requests/hour, and Jenkins' own rate limiter
     will visibly sleep for minutes at a time on that budget; a PAT raises it to 5,000/hour and
     removes the throttling entirely.
   - Owner: `<your-github-username>`, Repository: `<your-repo-name>` (select from the dropdown
     once it loads)
3. Under **Build Configuration**, Mode: `by Jenkinsfile`, Script Path:
   `Project-3/devops-build/Jenkinsfile` (or `Jenkinsfile` if the repo root already is the app
   directory)
4. Leave **Scan Multibranch Pipeline Triggers** at its default (unchecked) — you don't need
   periodic polling, the webhook (Step 11) handles instant triggering once this job type is in
   place
5. Click **Save**

Saving immediately runs a first-time branch scan, which discovers `dev` and `main` as separate
sub-jobs and schedules an initial build for each — this is expected and is itself a useful first
test of both branches.

---

### Step 11 — Set Up GitHub Webhook

Same webhook endpoint regardless of job type — the GitHub Branch Source plugin listens on the
same URL the classic trigger would have used, it just resolves which specific branch changed
instead of firing one shared trigger for the whole job.

1. Go to your GitHub repo → **Settings > Webhooks > Add webhook**
2. Fill in:
   - **Payload URL:** `http://<jenkins_public_ip>:8080/github-webhook/`
   - **Content type:** `application/json`
   - **Events:** Just the **push** event
3. Click **Add webhook** — verify the green tick

---

### Step 12 — Test the Full Pipeline

This is separate from Step 10's initial scan-triggered builds — it specifically proves the
webhook-driven auto-trigger works for a *new* push on each branch, not just the one-time
discovery scan.

**Test 1 — Push to `dev` branch:**
```bash
git checkout dev
echo "# test" >> README.md
git add README.md
git commit -m "trigger dev build"
git push origin dev
```

Expected:
- Jenkins auto-triggers a build on the `dev` sub-job specifically
- Docker image built and pushed to `<username>/dev`
- `deploy.sh` SSHes into the app instance and the app updates on port 80

**Test 2 — Merge `dev` to `main`** (this repo's default branch — use `main`, not `master`,
unless you actually renamed your default branch):
```bash
git checkout main
git merge dev
git push origin main
```

Expected:
- Jenkins auto-triggers a build on the `main` sub-job specifically
- Docker image built and pushed to `<username>/prod` (private)
- App updates on port 80

---

### Step 13 — Start Monitoring Stack

Monitoring runs alongside the app on the **app** EC2 instance, not on Jenkins — but the
`monitoring/` folder isn't part of the Docker image, so it needs to be copied over separately
before it can run there.

**Copy the monitoring folder to the app instance** (run from `devops-build/`, not `aws/`):
```bash
scp -i aws/<EC2_KEY_NAME>.pem -r monitoring ubuntu@<app_public_ip>:~/monitoring
```

**SSH in and start it:**
```bash
ssh -i aws/<EC2_KEY_NAME>.pem ubuntu@<app_public_ip>
```
The remote instance doesn't have your `.env` file, so export the SMTP values directly (quote
any value containing `#`, spaces, or `$` — see Step 2):
```bash
export SMTP_HOST=smtp.gmail.com
export SMTP_PORT=587
export SMTP_USER=your-gmail@gmail.com
export SMTP_PASSWORD='your app password'
export ALERT_EMAIL=your-alert-email@example.com

cd monitoring
chmod +x render-config.sh
./render-config.sh   # writes alertmanager.yml (gitignored) from alertmanager.yml.template
docker compose up -d
```
Use `docker compose` (a space, no hyphen) — the standalone `docker-compose` binary isn't
installed by this project's Docker setup; modern Docker ships Compose as a plugin instead, and
`docker-compose` (the old hyphenated command) isn't found.

**Viewing Grafana/Prometheus/Alertmanager:** their ports (3001, 9090, 9093) are deliberately
**not** opened on the app instance's security group — only 80 and 22 are (see Security Group
Configuration below), so opening more ports just to view dashboards would go beyond what the
spec asks for. Instead, tunnel them through the SSH port you already have access to. From your
own machine, in a **separate** terminal you leave open:
```bash
ssh -i aws/<EC2_KEY_NAME>.pem -L 3001:localhost:3001 -L 9090:localhost:9090 -L 9093:localhost:9093 ubuntu@<app_public_ip>
```
Now `http://localhost:3001`, `http://localhost:9090`, `http://localhost:9093` on your own
machine reach Grafana, Prometheus, and Alertmanager respectively, for as long as that SSH
session stays open.

In Grafana (`http://localhost:3001`, admin/admin):
1. Go to **Connections > Data Sources > Add** → Select **Prometheus**
2. URL: `http://prometheus:9090` — **not** `localhost:9090`. Grafana itself runs inside a
   container on the compose network, so `localhost` from its point of view means "myself," not
   Prometheus; `prometheus` is the other container's service name on that same network, which
   Docker Compose resolves automatically → **Save & Test** (expect "Successfully queried the
   Prometheus API")
3. Go to **Dashboards > New > Import** → Enter ID `1860` (community "Node Exporter Full"
   dashboard) → **Load** → select the Prometheus data source → **Import**

---

### Step 14 — Verify App and Monitoring

```bash
curl http://<app_public_ip>/health
# Expected: healthy

curl http://<app_public_ip>/metrics
# Expected: application_up 1
```

Test alert by stopping the container:
```bash
docker stop devops-build-app
# Wait ~1 minute — Alertmanager sends email alert
docker start devops-build-app
```
You can also watch the alert transition from nothing to **firing** in real time at
`http://localhost:9090/alerts` (through the SSH tunnel from Step 13) — refresh after about a
minute (the rule requires 1 minute of continuous downtime before it fires) and
`ApplicationDown` should turn red.

---

### Step 15 — Cleanup

```bash
cd aws
chmod +x cleanup.sh
./cleanup.sh all      # or: ./cleanup.sh app  /  ./cleanup.sh jenkins
```

---

## Security Group Configuration

**App instance:**

| Port | Source | Purpose |
|------|--------|---------|
| `80` | `0.0.0.0/0` | Public app access |
| `22` | `<YOUR-IP>/32` | SSH — your IP only |
| `22` | Jenkins security group | Deploy stage SSHes in from Jenkins — added automatically by `provision-jenkins.sh` once both instances exist, not opened to the internet |

**Jenkins instance:**

| Port | Source | Purpose |
|------|--------|---------|
| `8080` | `0.0.0.0/0` | Jenkins UI + GitHub webhook delivery |
| `22` | `<YOUR-IP>/32` | SSH — your IP only |

---

## Submission

- GitHub repo URL (with `dev` and `master`/`main` branches)
- Deployed site URL: `http://<app-instance-public-IP>`
- DockerHub images: `<username>/dev` and `<username>/prod`
- Screenshots in repo:
  - Jenkins pipeline — successful build console output
  - Jenkins pipeline configuration page
  - AWS EC2 console — both instances running
  - Security Group — showing port 22 restricted to your IP (both instances)
  - DockerHub `dev` repo with image tags
  - DockerHub `prod` repo with image tags
  - Deployed app in browser at the app instance's IP
  - Monitoring dashboard (Grafana)
