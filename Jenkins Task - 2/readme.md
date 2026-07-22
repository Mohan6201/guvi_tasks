# Jenkins Task - 2

## Task Description

Create a simple script, push it to GitHub, connect Jenkins to the repo, and configure it so that every GitHub commit **automatically triggers a Jenkins build** — with the build output sent via **email**.

---

## Tech Stack

- **AWS EC2** — Ubuntu 22.04 server to host Jenkins
- **Jenkins** — CI/CD automation with GitHub integration and email notifications
- **GitHub** — Source code repository + webhook to trigger builds
- **Java 21** — Required runtime for current Jenkins LTS
- **Terraform** — Provisions the EC2 instance and security group

---

## Project Structure

```
Jenkins Task - 2/
├── terraform/
│   ├── main.tf               # Provider, security group, EC2 instance
│   ├── variables.tf          # Input variable declarations
│   └── outputs.tf            # Jenkins URL, SSH command
├── scripts/
│   ├── setup_jenkins.sh      # Installs Java 21 + Jenkins on EC2 first boot
│   └── hello.sh              # Simple script that Jenkins builds
├── Jenkinsfile               # Declarative pipeline — runs script + sends email
├── .env                      # Your credentials and config — never commit this
├── .env.example               # Safe-to-commit template
├── .gitignore                # Excludes .env and Terraform state
└── readme.md                 # This file
```

> **Note:** this project lives inside the `guvi_tasks` monorepo, not its own repo root. The Jenkins job and Jenkinsfile are configured to account for that (see Step 13 and the `Jenkinsfile` details below).

---

## How It Works

```
Developer pushes commit to GitHub
         │
         ▼
GitHub Webhook  →  POST to http://<jenkins_ip>:8080/github-webhook/
         │
         ▼
Jenkins detects trigger  →  pulls latest code from GitHub (whole guvi_tasks repo)
         │
         ▼
Jenkinsfile runs (from Jenkins Task - 2/Jenkinsfile):
  Stage 1: Checkout        →  clones repo
  Stage 2: Run Script      →  cd's into "Jenkins Task - 2/", then executes scripts/hello.sh
         │
         ▼
Post-build: emailext sends HTML build report to EMAIL_RECIPIENT
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` | Your AWS Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | Your AWS Secret Access Key |
| `TF_VAR_region` | AWS region (e.g. `ap-south-1`) |
| `TF_VAR_instance_type` | EC2 instance type (e.g. `t2.medium`) |
| `TF_VAR_key_name` | Key pair name for SSH |
| `EMAIL_RECIPIENT` | Email address to receive build notifications |
| `SMTP_HOST` | SMTP server (e.g. `smtp.gmail.com`) |
| `SMTP_PORT` | SMTP port (e.g. `465`) |
| `SMTP_USER` | SMTP login email |
| `SMTP_PASSWORD` | Gmail App Password (not your main password) |

---

## Prerequisites

1. **AWS Account** with EC2 permissions
2. **Terraform** >= 1.3.0 — [Download](https://developer.hashicorp.com/terraform/downloads)
3. **AWS CLI** — [Download](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
4. **EC2 Key Pair** in your target region
5. **Gmail Account** with 2-Step Verification enabled (needed for App Password)
6. **This repo pushed to GitHub** before setting up the Jenkins job

---

## Step-by-Step Setup (as executed)

### Step 1 — Install prerequisites (one-time)

```powershell
# Verify installs
terraform -version
aws --version
```
If missing: [Terraform](https://developer.hashicorp.com/terraform/downloads), [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html).

---

### Step 2 — Configure AWS credentials

```powershell
aws configure
# AWS Access Key ID: <your key>
# AWS Secret Access Key: <your secret>
# Default region: ap-south-1
# Default output format: json
```

---

### Step 3 — Create an EC2 key pair (if you don't have one)

```powershell
aws ec2 create-key-pair --key-name my-key-pair --query 'KeyMaterial' --output text > "$env:USERPROFILE\.ssh\my-key-pair.pem"
```

---

### Step 4 — Generate a Gmail App Password

1. Go to `myaccount.google.com` → **Security** → enable **2-Step Verification**.
2. **Security → App Passwords** → app: Mail, device: Other → name it `Jenkins`.
3. Click **Generate** — copy the 16-character password.

---

### Step 5 — Set up the `.env` file

```powershell
Copy-Item .env.example .env
notepad .env
```
Fill in: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `TF_VAR_region`, `TF_VAR_instance_type`, `TF_VAR_key_name`, `EMAIL_RECIPIENT`, `SMTP_*` (with the Gmail App Password).

> **Never commit `.env` to git.** It is already in `.gitignore`.

---

### Step 6 — Load environment variables into the session

```powershell
Get-Content .env | Where-Object { $_ -notmatch '^#' -and $_ -ne '' } | ForEach-Object {
    $key, $value = $_ -split '=', 2
    [System.Environment]::SetEnvironmentVariable($key, $value, 'Process')
}
```

---

### Step 7 — Provision the EC2 instance with Terraform

```powershell
cd terraform
terraform init
terraform plan
terraform apply
```
Type `yes` when prompted. Note the output:
```
jenkins_url = "http://<public_ip>:8080"
ssh_command = "ssh -i ~/.ssh/my-key-pair.pem ubuntu@<public_ip>"
```

> If `terraform apply` fails with a DNS/network error (e.g. `dial tcp: lookup ec2.<region>.amazonaws.com: no such host`), it's almost always a transient network blip, not a config issue. Run `ipconfig /flushdns` and re-apply with `terraform apply "tfplan"`.

---

### Step 8 — Retrieve the Jenkins initial admin password

Wait **2-3 minutes** for `user_data` to finish installing Jenkins, then:

```powershell
ssh -i "$env:USERPROFILE\.ssh\my-key-pair.pem" ubuntu@<public_ip>
```
Inside the SSH session:
```bash
ls jenkins_setup_done          # confirms setup_jenkins.sh finished successfully
./get_jenkins_password.sh
exit
```

> If `jenkins_setup_done` is missing or Jenkins isn't reachable, check `sudo cat /var/log/cloud-init-output.log` on the instance for the real error before assuming Jenkins is broken.

---

### Step 9 — Unlock Jenkins (browser)

1. Open `http://<public_ip>:8080`.
2. Paste the initial admin password.
3. Choose **Install suggested plugins**.
4. Create your admin user (username/password).

📸 **Screenshot**: Jenkins dashboard after login.

---

### Step 10 — Install required plugins

**Manage Jenkins → Plugins → Available plugins** → install: `Git`, `GitHub`, `Pipeline`, `Email Extension Plugin` → restart Jenkins if prompted.

---

### Step 11 — Configure SMTP for email

**Manage Jenkins → System → Extended E-mail Notification**:
- SMTP server: `smtp.gmail.com`
- SMTP Port: `465` → **Advanced** → check **Use SSL**
- Credentials → **Add → Jenkins** → Kind: Username with password → your Gmail address / App Password → select it
- Default user e-mail suffix: `@gmail.com`
- Default Recipients: your email
- Click **Test configuration by sending test e-mail** → confirm it arrives

📸 **Screenshot**: SMTP config screen + test email success.

---

### Step 12 — Set `EMAIL_RECIPIENT` as a global Jenkins env var

**Manage Jenkins → System → Global Properties** → check **Environment variables** → Add: `EMAIL_RECIPIENT` = your email → **Save**.

---

### Step 13 — Create the Pipeline job

1. Dashboard → **New Item** → name `jenkins-task-2-pipeline` → type **Pipeline** → OK.
2. **Build Triggers** → check **GitHub hook trigger for GITScm polling**.
3. **Pipeline** section → Definition: **Pipeline script from SCM** → SCM: **Git**.
   - Repository URL: `https://github.com/Mohan6201/guvi_tasks.git`
   - Branch: `*/main`
   - Script Path: `Jenkins Task - 2/Jenkinsfile`

   > This repo is a monorepo — `Jenkins Task - 2` is a subdirectory, not the repo root. The Script Path above tells Jenkins where to find the Jenkinsfile after cloning the whole repo.
4. **Save**.

📸 **Screenshot**: pipeline job configuration page.

---

### Step 14 — Set up the GitHub webhook

1. GitHub repo → **Settings → Webhooks → Add webhook**.
2. Payload URL: `http://<public_ip>:8080/github-webhook/`
3. Content type: `application/json`
4. Events: **Just the push event** → **Add webhook**.
5. Confirm the green checkmark appears (successful ping).

📸 **Screenshot**: webhook with green tick.

---

### Step 15 — Trigger a build with a real commit

```powershell
cd "..\Jenkins Task - 2"
Add-Content scripts\hello.sh "`n# trigger build $(Get-Date)"
git add .
git commit -m "Trigger Jenkins build"
git push origin main
```

---

### Step 16 — Verify the build ran automatically

In Jenkins, open the job → confirm a new build started within seconds of the push (console shows `Started by GitHub push by <username>`) → click into **Console Output**.

📸 **Screenshot**: build console output showing SUCCESS.

---

### Step 17 — Check your inbox

Look for subject `Jenkins Build SUCCESS: jenkins-task-2-pipeline #<n>`.

📸 **Screenshot**: the received email.

---

### Step 18 — Add screenshots to the repo and push

```powershell
mkdir screenshots
# move/save the screenshots into this folder
git add screenshots
git commit -m "Add Jenkins Task 2 output screenshots"
git push origin main
```

---

### Step 19 — Clean up AWS resources (after submission, to avoid charges)

```powershell
cd terraform
terraform destroy
```
Type `yes` to confirm.

---

## Issues Hit During Setup and Fixes Applied

| Issue | Cause | Fix |
|---|---|---|
| `terraform apply` failed with `dial tcp: lookup ec2.ap-south-1.amazonaws.com: no such host` | Transient DNS/network blip on the local machine at the moment of the API call | Flushed DNS (`ipconfig /flushdns`) and re-ran `terraform apply "tfplan"` — succeeded on retry |
| Jenkins installed but wouldn't start reliably | `setup_jenkins.sh` used `openjdk-17-jre`, but current Jenkins LTS requires Java 21 | Switched to `openjdk-21-jre` |
| `apt-get install` intermittently failed with `Could not get lock /var/lib/dpkg/lock-frontend` | Ubuntu's background `unattended-upgrades`/`apt-daily` service races with `user_data` for the dpkg lock on first boot | Added a `wait_for_apt_lock` retry loop before every apt command, plus `set -euo pipefail` |
| Jenkins apt repo failed GPG verification | Signing key file `jenkins.io-2023.key` is outdated/rotated | Updated to the current `jenkins.io-2026.key`, moved keyring to the now-standard `/etc/apt/keyrings` path |
| Pipeline failed: `chmod: cannot access 'scripts/hello.sh': No such file or directory` | The GitHub repo is a monorepo — `checkout scm` clones the full `guvi_tasks` repo, so `scripts/hello.sh` actually lives under `Jenkins Task - 2/scripts/hello.sh`, not at the workspace root | Wrapped the `Run Script` stage in `dir('Jenkins Task - 2') { ... }` so relative paths resolve correctly |

---

## File Details

### `scripts/hello.sh`
The simple script Jenkins executes. Prints build timestamp, hostname, git branch, commit hash, and system info.

### `Jenkinsfile`
Declarative pipeline with two stages:
- **Checkout** — pulls code from GitHub
- **Run Script** — `cd`s into `Jenkins Task - 2/` (since the repo is a monorepo) and executes `scripts/hello.sh`

The `post { always { } }` block sends an HTML email after every build regardless of result (success or failure).

### `scripts/setup_jenkins.sh`
Runs on EC2 first boot via Terraform `user_data`. Waits out any background apt lock, installs Java 21, adds the official Jenkins apt repo (current signing key), installs and starts Jenkins, and writes a `jenkins_setup_done` marker file on completion for easy verification.

---

## Ports Reference

| Port | Purpose |
|------|---------|
| `22` | SSH access to EC2 |
| `8080` | Jenkins web UI and webhook endpoint |

---

## Submission

- Push all files (including `.env.example` and output screenshots) to GitHub
- **Do not push `.env`** — it is gitignored
- Screenshots to include: Jenkins pipeline job, webhook trigger log, successful build console output, and the email received in inbox
- Submit the GitHub repository URL in the portal
