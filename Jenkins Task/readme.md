# Jenkins Task

## Task Description

Launch **Jenkins** on an AWS EC2 instance, then explore creating **projects (jobs)** and **users** in the Jenkins UI.

---

## Tech Stack

- **AWS EC2** — Ubuntu 22.04 Linux server to host Jenkins
- **Jenkins** — CI/CD automation server
- **Java 17** — Required runtime for Jenkins LTS
- **Terraform** — Provisions the EC2 instance and security group

---

## Project Structure

```
Jenkins Task/
├── terraform/
│   ├── main.tf           # Provider, security group, EC2 instance
│   ├── variables.tf      # Input variable declarations (no hardcoded values)
│   └── outputs.tf        # Outputs public IP, Jenkins URL, SSH command
├── scripts/
│   └── setup_jenkins.sh  # Installs Java 17 and Jenkins on first boot
├── .env                  # Your actual credentials and config — never commit this
├── .env.example          # Safe-to-commit template showing all required variables
├── .gitignore            # Excludes .env and Terraform state from git
└── readme.md             # This file
```

---

## Environment Variables

All credentials and configuration are driven through environment variables — **nothing is hardcoded**.

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` | Your AWS Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | Your AWS Secret Access Key |
| `TF_VAR_region` | AWS region to deploy (e.g. `us-east-1`) |
| `TF_VAR_instance_type` | EC2 instance type (e.g. `t2.medium`) |
| `TF_VAR_key_name` | Key pair name for SSH access |

---

## Prerequisites

1. **AWS Account** — Active account with EC2 and IAM permissions
2. **AWS CLI** — [Download here](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
3. **Terraform** — [Download here](https://developer.hashicorp.com/terraform/downloads) (version >= 1.3.0)
4. **EC2 Key Pair** — Create one in your target region:
   - Go to **AWS Console > EC2 > Key Pairs**
   - Create a key pair, download the `.pem` file, and note the name

---

## Step-by-Step Setup

### Step 1 — Set Up the `.env` File

Copy the example file and fill in your actual values:

```bash
cp .env.example .env
```

Open `.env` and replace the placeholder values:

```env
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

TF_VAR_region=us-east-1
TF_VAR_instance_type=t2.medium
TF_VAR_key_name=my-key-pair
```

> **Never commit `.env` to git.** It is already listed in `.gitignore`.

---

### Step 2 — Load the Environment Variables

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

### Step 3 — Initialize Terraform

```bash
cd terraform
terraform init
```

---

### Step 4 — Preview the Plan

```bash
terraform plan
```

Expected resources:
- 1 Security Group (ports 22 and 8080)
- 1 EC2 instance (Ubuntu 22.04)

---

### Step 5 — Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted. Terraform will:
1. Launch an Ubuntu 22.04 EC2 instance
2. Open port `22` (SSH) and port `8080` (Jenkins UI)
3. Run `setup_jenkins.sh` via `user_data` on first boot — installs Java 17 and Jenkins automatically

Note the outputs:
```
Outputs:

instance_public_ip = "3.x.x.x"
jenkins_url        = "http://3.x.x.x:8080"
ssh_command        = "ssh -i ~/.ssh/my-key-pair.pem ubuntu@3.x.x.x"
```

---

### Step 6 — Get the Jenkins Initial Admin Password

Wait **2-3 minutes** for the instance to boot and Jenkins to start, then SSH in:

```bash
ssh -i ~/.ssh/<your-key>.pem ubuntu@<public_ip>
```

Once inside the instance, retrieve the initial admin password:

```bash
./get_jenkins_password.sh
```

Or directly:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Copy the password — you will need it in the next step.

---

### Step 7 — Unlock Jenkins

1. Open `http://<public_ip>:8080` in your browser
2. Paste the **initial admin password** from Step 6
3. Click **Continue**
4. On the next screen, select **Install suggested plugins** and wait for installation
5. Create your **first admin user** (username, password, email)
6. Click **Save and Finish** → **Start using Jenkins**

---

### Step 8 — Create a Jenkins Project (Job)

1. From the Jenkins dashboard, click **New Item**
2. Enter a name (e.g. `my-first-job`)
3. Select **Freestyle project** → click **OK**
4. Scroll to the **Build Steps** section
5. Click **Add build step** → select **Execute shell**
6. Enter a simple command:
   ```bash
   echo "Hello from Jenkins!"
   date
   ```
7. Click **Save**
8. Click **Build Now** on the left sidebar
9. Click the build number under **Build History** → **Console Output**
10. You should see:
    ```
    Hello from Jenkins!
    Tue Jun 24 ...
    Finished: SUCCESS
    ```

---

### Step 9 — Create a Jenkins User

1. From the Jenkins dashboard, go to **Manage Jenkins** → **Users**
2. Click **Create User**
3. Fill in:
   - **Username:** `devuser`
   - **Password:** (set a strong password)
   - **Full Name:** `Dev User`
   - **Email:** your email
4. Click **Create User**
5. Go to **Manage Jenkins** → **Security**
6. Under **Authorization**, select **Matrix-based security**
7. Add the new user and assign appropriate permissions (e.g. read, build)
8. Click **Save**

---

### Step 10 — Destroy Resources (Cleanup)

To avoid unnecessary AWS charges:

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted. This terminates the EC2 instance and deletes the security group.

---

## What the Shell Script Does

`scripts/setup_jenkins.sh` runs automatically on the EC2 instance via `user_data`:

| Step | What it does |
|------|-------------|
| System update | `apt-get update` — refreshes package lists |
| Install Java 17 | `openjdk-17-jre` — required runtime for Jenkins LTS |
| Add Jenkins repo | Adds the official Jenkins apt repository and GPG key |
| Install Jenkins | `apt-get install jenkins` |
| Start Jenkins | Enables and starts the `jenkins` systemd service on port `8080` |
| Helper script | Creates `~/get_jenkins_password.sh` for easy password retrieval |

---

## Ports Reference

| Port | Purpose |
|------|---------|
| `22` | SSH access to the EC2 instance |
| `8080` | Jenkins web UI |

---

## Submission

- Push all files (including `.env.example` and output screenshots) to GitHub
- **Do not push `.env`** — it is gitignored to protect your credentials
- Screenshots to include: Jenkins dashboard, created project with successful build, users list
- Submit the GitHub repository URL in the portal
