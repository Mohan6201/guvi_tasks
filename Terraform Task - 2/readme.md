# Terraform Task - 2

## Task Description

Create **2 EC2 instances in 2 different AWS regions** and install **nginx** on both using Terraform.

---

## Tech Stack

- **Terraform** — Infrastructure as Code tool to provision AWS resources
- **AWS EC2** — Virtual machines where nginx will be installed
- **AWS CLI** — Used to configure AWS credentials locally

---

## Project Structure

```
Terraform Task - 2/
├── main.tf           # Providers, security groups, and EC2 instances
├── variables.tf      # Input variable declarations (no hardcoded values)
├── outputs.tf        # Outputs public IPs and nginx URLs after apply
├── .env              # Your actual credentials and config — never commit this
├── .env.example      # Safe-to-commit template showing all required variables
├── .gitignore        # Excludes .env and Terraform state from git
└── readme.md         # This file
```

---

## Environment Variables

All credentials and configuration are driven through environment variables — **nothing is hardcoded**.

There are two types of variables used:

| Prefix | Read by | Purpose |
|--------|---------|---------|
| `AWS_*` | AWS Terraform provider (automatic) | AWS account credentials |
| `TF_VAR_*` | Terraform (automatic) | Terraform input variables |

### Full list of variables

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` | Your AWS Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | Your AWS Secret Access Key |
| `TF_VAR_region_1` | Primary AWS region (e.g. `us-east-1`) |
| `TF_VAR_region_2` | Secondary AWS region (e.g. `us-west-2`) |
| `TF_VAR_instance_type` | EC2 instance type (e.g. `t2.micro`) |
| `TF_VAR_key_name_region_1` | Key pair name in region 1 |
| `TF_VAR_key_name_region_2` | Key pair name in region 2 |

---

## Prerequisites

1. **AWS Account** — Active account with EC2 and IAM permissions
2. **AWS CLI** — [Download here](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
3. **Terraform** — [Download here](https://developer.hashicorp.com/terraform/downloads) (version >= 1.3.0)
4. **EC2 Key Pairs** — Create key pairs in both regions via AWS Console:
   - Go to **AWS Console > EC2 > Key Pairs**
   - Switch to `us-east-1` and create a key pair, note the name
   - Switch to `us-west-2` and create a key pair, note the name

---

## Step-by-Step Setup

### Step 1 — Set Up the `.env` File

Copy the example file and fill in your actual values:

```bash
cp .env.example .env
```

Open `.env` and replace the placeholder values:

```env
# AWS Credentials — from AWS Console > IAM > Users > Security Credentials
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# Terraform Variables
TF_VAR_region_1=us-east-1
TF_VAR_region_2=us-west-2
TF_VAR_instance_type=t2.micro
TF_VAR_key_name_region_1=my-key-us-east-1
TF_VAR_key_name_region_2=my-key-us-west-2
```

> **Never commit `.env` to git.** It is already listed in `.gitignore`.

---

### Step 2 — Load the Environment Variables

You must load the `.env` file into your shell session before running Terraform.

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

Verify the variables are loaded:

**Linux / macOS:**
```bash
echo $AWS_ACCESS_KEY_ID
echo $TF_VAR_region_1
```

**Windows (PowerShell):**
```powershell
echo $env:AWS_ACCESS_KEY_ID
echo $env:TF_VAR_region_1
```

---

### Step 3 — Initialize Terraform

This downloads the AWS provider plugin. Run once per project.

```bash
terraform init
```

Expected output:
```
Initializing provider plugins...
- Installed hashicorp/aws v5.x.x

Terraform has been successfully initialized!
```

---

### Step 4 — Preview the Execution Plan

See what Terraform will create before actually creating anything.

```bash
terraform plan
```

Expected resources in the plan:
- 2 Security Groups (one per region)
- 2 EC2 instances (one per region)

---

### Step 5 — Apply the Configuration

Create the actual AWS resources. Type `yes` when prompted.

```bash
terraform apply
```

Terraform will:
1. Fetch the latest Amazon Linux 2 AMI in `us-east-1` and `us-west-2`
2. Create a Security Group in each region allowing ports **22 (SSH)** and **80 (HTTP)**
3. Launch a `t2.micro` EC2 instance in each region
4. Run the `user_data` script on each instance to install and start nginx automatically

---

### Step 6 — Read the Output

After `apply` completes, Terraform prints the public IPs and URLs:

```
Outputs:

instance_us_east_1  = "3.x.x.x"
instance_us_west_2  = "54.x.x.x"
nginx_url_us_east_1 = "http://3.x.x.x"
nginx_url_us_west_2 = "http://54.x.x.x"
```

---

### Step 7 — Verify nginx is Running

Open the URLs from the output in your browser, or use curl:

```bash
curl http://<instance_us_east_1_ip>
curl http://<instance_us_west_2_ip>
```

You should see the **nginx welcome page** HTML in the response.

> Wait 1-2 minutes after `apply` for the instance to finish booting and nginx to start.

---

### Step 8 — Destroy Resources (Cleanup)

To avoid unnecessary AWS charges, destroy all resources when done:

```bash
terraform destroy
```

Type `yes` when prompted. This terminates both EC2 instances and deletes the security groups.

---

## How nginx is Installed

nginx is installed automatically via EC2 `user_data` — a script that runs once on first boot:

```bash
#!/bin/bash
yum update -y
amazon-linux-extras install nginx1 -y
systemctl start nginx
systemctl enable nginx
```

| Step | What it does |
|------|-------------|
| `yum update -y` | Updates all system packages |
| `amazon-linux-extras install nginx1 -y` | Installs nginx on Amazon Linux 2 |
| `systemctl start nginx` | Starts nginx immediately |
| `systemctl enable nginx` | Enables nginx to auto-start on reboot |

---

## Infrastructure Overview

| Resource | Region 1 (us-east-1) | Region 2 (us-west-2) |
|----------|----------------------|----------------------|
| EC2 Instance | nginx-server-us-east-1 | nginx-server-us-west-2 |
| Instance Type | `TF_VAR_instance_type` | `TF_VAR_instance_type` |
| AMI | Amazon Linux 2 (latest) | Amazon Linux 2 (latest) |
| Security Group | nginx-sg-us-east-1 | nginx-sg-us-west-2 |
| Ports Open | 22 (SSH), 80 (HTTP) | 22 (SSH), 80 (HTTP) |
| nginx Install | via user_data on boot | via user_data on boot |

---

## Submission

- Push all files (including `.env.example` and output screenshots) to GitHub
- **Do not push `.env`** — it is gitignored to protect your credentials
- Submit the GitHub repository URL in the portal
