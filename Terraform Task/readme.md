# Terraform Task

## Task Description

Launch **Linux EC2 instances in two different AWS regions** using a **single Terraform configuration file**.

---

## Tech Stack

- **Terraform** — Infrastructure as Code, single file with multi-region provider aliases
- **AWS EC2** — Amazon Linux 2 instances in two regions
- **AWS CLI** — Used to configure AWS credentials locally

---

## Project Structure

```
Terraform Task/
├── main.tf         # Single file — providers, security groups, and EC2 instances
├── variables.tf    # Input variable declarations (no hardcoded values)
├── outputs.tf      # Public IPs and SSH commands for both instances
├── .env            # Your actual credentials and config — never commit this
├── .env.example    # Safe-to-commit template showing all required variables
├── .gitignore      # Excludes .env and Terraform state from git
└── readme.md       # This file
```

---

## How It Works

A single `main.tf` file defines **two AWS provider aliases** — one per region. Each provider alias is then used to create its own security group and EC2 instance, all within the same file.

```
main.tf
 ├── provider "aws" alias="region_1"  →  us-east-1
 │    ├── aws_security_group  (ec2-sg-us-east-1)
 │    └── aws_instance        (linux-ec2-us-east-1)
 │
 └── provider "aws" alias="region_2"  →  us-west-2
      ├── aws_security_group  (ec2-sg-us-west-2)
      └── aws_instance        (linux-ec2-us-west-2)
```

---

## Environment Variables

All credentials and configuration are driven through environment variables — **nothing is hardcoded**.

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

1. **AWS Account** — Active account with EC2 permissions
2. **AWS CLI** — [Download here](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
3. **Terraform** — [Download here](https://developer.hashicorp.com/terraform/downloads) (version >= 1.3.0)
4. **EC2 Key Pairs** — Create one in each region:
   - Go to **AWS Console > EC2 > Key Pairs**
   - Switch to `us-east-1`, create a key pair, note the name
   - Switch to `us-west-2`, create a key pair, note the name

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

TF_VAR_region_1=us-east-1
TF_VAR_region_2=us-west-2
TF_VAR_instance_type=t2.micro
TF_VAR_key_name_region_1=my-key-us-east-1
TF_VAR_key_name_region_2=my-key-us-west-2
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

Verify:
```bash
echo $AWS_ACCESS_KEY_ID
echo $TF_VAR_region_1
```

---

### Step 3 — Initialize Terraform

Downloads the AWS provider plugin. Run once per project.

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

```bash
terraform plan
```

Expected resources in the plan:
- 2 Security Groups (one per region)
- 2 EC2 instances (one per region)

---

### Step 5 — Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted. Terraform will:
1. Fetch the latest Amazon Linux 2 AMI in both regions simultaneously
2. Create a Security Group in each region allowing port 22 (SSH)
3. Launch a `t2.micro` EC2 instance in each region

---

### Step 6 — Read the Output

After `apply` completes:

```
Outputs:

instance_region_1_id         = "i-0abc123..."
instance_region_1_public_ip  = "3.x.x.x"
instance_region_2_id         = "i-0xyz456..."
instance_region_2_public_ip  = "54.x.x.x"
ssh_region_1                 = "ssh -i ~/.ssh/my-key-us-east-1.pem ec2-user@3.x.x.x"
ssh_region_2                 = "ssh -i ~/.ssh/my-key-us-west-2.pem ec2-user@54.x.x.x"
```

---

### Step 7 — Verify Instances via SSH

Connect to each instance using the SSH commands from the output:

```bash
# Region 1
ssh -i ~/.ssh/my-key-us-east-1.pem ec2-user@<region_1_ip>

# Region 2
ssh -i ~/.ssh/my-key-us-west-2.pem ec2-user@<region_2_ip>
```

Once connected, verify the instance details:
```bash
curl http://169.254.169.254/latest/meta-data/placement/region
```

This returns the region the instance is running in, confirming the multi-region deployment.

---

### Step 8 — Verify via AWS Console

1. Go to **AWS Console > EC2 > Instances**
2. Switch to `us-east-1` — you should see `linux-ec2-us-east-1` running
3. Switch to `us-west-2` — you should see `linux-ec2-us-west-2` running

---

### Step 9 — Destroy Resources (Cleanup)

To avoid unnecessary AWS charges:

```bash
terraform destroy
```

Type `yes` when prompted. This terminates both EC2 instances and deletes both security groups across both regions.

---

## Infrastructure Overview

| Resource | Region 1 (us-east-1) | Region 2 (us-west-2) |
|----------|----------------------|----------------------|
| EC2 Instance | linux-ec2-us-east-1 | linux-ec2-us-west-2 |
| Instance Type | `TF_VAR_instance_type` | `TF_VAR_instance_type` |
| AMI | Amazon Linux 2 (latest) | Amazon Linux 2 (latest) |
| Security Group | ec2-sg-us-east-1 | ec2-sg-us-west-2 |
| Port Open | 22 (SSH) | 22 (SSH) |

---

## Submission

- Push all files (including `.env.example` and output screenshots) to GitHub
- **Do not push `.env`** — it is gitignored to protect your credentials
- Screenshots to include: `terraform apply` output and both instances running in AWS Console
- Submit the GitHub repository URL in the portal
