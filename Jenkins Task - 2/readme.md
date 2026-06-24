# Jenkins Task - 2

## Task Description

Create a simple script, push it to GitHub, connect Jenkins to the repo, and configure it so that every GitHub commit **automatically triggers a Jenkins build** — with the build output sent via **email**.

---

## Tech Stack

- **AWS EC2** — Ubuntu 22.04 server to host Jenkins
- **Jenkins** — CI/CD automation with GitHub integration and email notifications
- **GitHub** — Source code repository + webhook to trigger builds
- **Java 17** — Required runtime for Jenkins LTS
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
│   ├── setup_jenkins.sh      # Installs Java 17 + Jenkins on EC2 first boot
│   └── hello.sh              # Simple script that Jenkins builds
├── Jenkinsfile               # Declarative pipeline — runs script + sends email
├── .env                      # Your credentials and config — never commit this
├── .env.example              # Safe-to-commit template
├── .gitignore                # Excludes .env and Terraform state
└── readme.md                 # This file
```

---

## How It Works

```
Developer pushes commit to GitHub
         │
         ▼
GitHub Webhook  →  POST to http://<jenkins_ip>:8080/github-webhook/
         │
         ▼
Jenkins detects trigger  →  pulls latest code from GitHub
         │
         ▼
Jenkinsfile runs:
  Stage 1: Checkout  →  clones repo
  Stage 2: Run Script  →  executes scripts/hello.sh
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
| `TF_VAR_region` | AWS region (e.g. `us-east-1`) |
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

## Step-by-Step Setup

### Step 1 — Set Up the `.env` File

```bash
cp .env.example .env
```

Fill in your values:

```env
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

TF_VAR_region=us-east-1
TF_VAR_instance_type=t2.medium
TF_VAR_key_name=my-key-pair

EMAIL_RECIPIENT=your-email@example.com
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_USER=your-gmail@gmail.com
SMTP_PASSWORD=your_gmail_app_password
```

> **Never commit `.env` to git.** It is already in `.gitignore`.

---

### Step 2 — Generate a Gmail App Password

Jenkins needs an App Password to send emails via Gmail:

1. Go to your **Google Account > Security**
2. Enable **2-Step Verification** if not already enabled
3. Go to **Security > App Passwords**
4. Select app: **Mail**, device: **Other** → type `Jenkins`
5. Click **Generate** — copy the 16-character password
6. Paste it as `SMTP_PASSWORD` in `.env`

---

### Step 3 — Load Environment Variables and Deploy EC2

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

Then deploy:
```bash
cd terraform
terraform init
terraform apply
```

Note the output:
```
jenkins_url = "http://3.x.x.x:8080"
ssh_command = "ssh -i ~/.ssh/my-key-pair.pem ubuntu@3.x.x.x"
```

---

### Step 4 — Unlock Jenkins

Wait **2-3 minutes**, then SSH in to get the initial admin password:

```bash
ssh -i ~/.ssh/<your-key>.pem ubuntu@<public_ip>
./get_jenkins_password.sh
```

Open `http://<public_ip>:8080`, paste the password, install suggested plugins, and create your admin user.

---

### Step 5 — Install Required Jenkins Plugins

Go to **Manage Jenkins > Plugins > Available plugins** and install:

| Plugin | Purpose |
|--------|---------|
| **Git** | Clone GitHub repositories |
| **GitHub** | GitHub webhook integration |
| **Pipeline** | Run Jenkinsfile pipelines |
| **Email Extension (emailext)** | Rich HTML email notifications |

Restart Jenkins after installation.

---

### Step 6 — Configure SMTP Email in Jenkins

1. Go to **Manage Jenkins > System**
2. Scroll to **Extended E-mail Notification**
3. Fill in:
   - **SMTP server:** `smtp.gmail.com`
   - **SMTP Port:** `465`
   - Click **Advanced**
   - Check **Use SSL**
   - **Credentials:** click **Add** → **Jenkins** → Kind: **Username with password**
     - Username: your Gmail address
     - Password: your Gmail App Password
   - Select the credential you just added
   - **Default user e-mail suffix:** `@gmail.com`
4. Scroll to **Default Recipients** → enter your email
5. Click **Test configuration by sending test e-mail** to verify
6. Click **Save**

---

### Step 7 — Set EMAIL_RECIPIENT as a Jenkins Global Environment Variable

1. Go to **Manage Jenkins > System**
2. Scroll to **Global Properties**
3. Check **Environment variables**
4. Click **Add**:
   - Name: `EMAIL_RECIPIENT`
   - Value: your email address
5. Click **Save**

---

### Step 8 — Create a Pipeline Job

1. From Jenkins dashboard → **New Item**
2. Name: `jenkins-task-2-pipeline`
3. Select **Pipeline** → click **OK**
4. Under **Build Triggers**, check **GitHub hook trigger for GITScm polling**
5. Under **Pipeline**, select **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: your GitHub repo URL (e.g. `https://github.com/<username>/<repo>.git`)
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
6. Click **Save**

---

### Step 9 — Set Up GitHub Webhook

1. Go to your GitHub repository → **Settings > Webhooks > Add webhook**
2. Fill in:
   - **Payload URL:** `http://<jenkins_public_ip>:8080/github-webhook/`
   - **Content type:** `application/json`
   - **Which events:** select **Just the push event**
3. Click **Add webhook**
4. GitHub will send a test ping — you should see a green tick next to the webhook

---

### Step 10 — Test the Full Pipeline

Make a change to `scripts/hello.sh` or any file and push to GitHub:

```bash
echo "# trigger build" >> scripts/hello.sh
git add .
git commit -m "Trigger Jenkins build"
git push origin main
```

Within seconds, Jenkins should:
1. Detect the webhook trigger
2. Pull the latest code
3. Run `scripts/hello.sh`
4. Send an HTML email with the build result

---

### Step 11 — Verify the Email

Check your inbox for an email with subject:
```
Jenkins Build SUCCESS: jenkins-task-2-pipeline #1
```

The email contains:
- Build status
- Job name and build number
- Git branch and commit hash
- Build duration
- Direct link to the build console output

---

### Step 12 — Destroy Resources (Cleanup)

```bash
cd terraform
terraform destroy
```

---

## File Details

### `scripts/hello.sh`
The simple script Jenkins executes. Prints build timestamp, hostname, git branch, commit hash, and system info.

### `Jenkinsfile`
Declarative pipeline with two stages:
- **Checkout** — pulls code from GitHub
- **Run Script** — executes `scripts/hello.sh`

The `post { always { } }` block sends an HTML email after every build regardless of result (success or failure).

### `scripts/setup_jenkins.sh`
Runs on EC2 first boot via Terraform `user_data`. Installs Java 17, adds the official Jenkins apt repo, installs and starts Jenkins.

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
- Screenshots to include: Jenkins pipeline job, successful build console output, and the email received in inbox
- Submit the GitHub repository URL in the portal
