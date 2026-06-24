# Monitoring Task

## Task Description

Install **Prometheus** and **Grafana** on a Linux EC2 instance, connect Prometheus as a Grafana data source, and create a dashboard to view system metrics using **Node Exporter**.

---

## Tech Stack

- **AWS EC2** — Ubuntu 22.04 Linux server
- **Prometheus** — Metrics collection and storage
- **Node Exporter** — Exposes system-level metrics (CPU, memory, disk) to Prometheus
- **Grafana** — Dashboard and visualization layer
- **Terraform** — Provisions the EC2 instance and security group
- **Shell Script** — Installs and configures all monitoring tools on first boot

---

## Project Structure

```
Monitoring Task/
├── terraform/
│   ├── main.tf           # Provider, security group, EC2 instance
│   ├── variables.tf      # Input variable declarations (no hardcoded values)
│   └── outputs.tf        # Outputs public IP, Prometheus URL, Grafana URL
├── scripts/
│   └── setup_monitoring.sh  # Installs Node Exporter, Prometheus, and Grafana
├── .env                  # Your actual credentials and config — never commit this
├── .env.example          # Safe-to-commit template showing all required variables
├── .gitignore            # Excludes .env and Terraform state from git
└── readme.md             # This file
```

---

## Architecture

```
EC2 Instance (Ubuntu 22.04)
│
├── Node Exporter  :9100  →  exposes system metrics
├── Prometheus     :9090  →  scrapes Node Exporter every 15s
└── Grafana        :3000  →  reads from Prometheus, renders dashboards
```

---

## Environment Variables

All credentials and configuration are driven through environment variables — **nothing is hardcoded**.

| Prefix | Read by | Purpose |
|--------|---------|---------|
| `AWS_*` | AWS Terraform provider (automatic) | AWS account credentials |
| `TF_VAR_*` | Terraform (automatic) | Terraform input variables |

### Full list of variables

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` | Your AWS Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | Your AWS Secret Access Key |
| `TF_VAR_region` | AWS region to deploy the EC2 instance (e.g. `us-east-1`) |
| `TF_VAR_instance_type` | EC2 instance type (e.g. `t2.micro`) |
| `TF_VAR_key_name` | Key pair name for SSH access |

---

## Prerequisites

1. **AWS Account** — Active account with EC2 and IAM permissions
2. **AWS CLI** — [Download here](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
3. **Terraform** — [Download here](https://developer.hashicorp.com/terraform/downloads) (version >= 1.3.0)
4. **EC2 Key Pair** — Create a key pair in your target region:
   - Go to **AWS Console > EC2 > Key Pairs**
   - Create a key pair and download the `.pem` file
   - Note the key pair name — you'll need it in `.env`

---

## Step-by-Step Setup

### Step 1 — Set Up the `.env` File

Copy the example file and fill in your actual values:

```bash
cp .env.example .env
```

Open `.env` and replace the placeholder values:

```env
# AWS Credentials
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# Terraform Variables
TF_VAR_region=us-east-1
TF_VAR_instance_type=t2.micro
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

Verify the variables are loaded:

**Linux / macOS:**
```bash
echo $AWS_ACCESS_KEY_ID
echo $TF_VAR_region
```

**Windows (PowerShell):**
```powershell
echo $env:AWS_ACCESS_KEY_ID
echo $env:TF_VAR_region
```

---

### Step 3 — Initialize Terraform

Navigate to the terraform directory and initialize:

```bash
cd terraform
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
- 1 Security Group (ports 22, 9090, 3000, 9100)
- 1 EC2 instance (Ubuntu 22.04)

---

### Step 5 — Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted. Terraform will:
1. Fetch the latest Ubuntu 22.04 AMI
2. Create a Security Group opening ports for SSH, Prometheus, Grafana, and Node Exporter
3. Launch a `t2.micro` EC2 instance
4. Run `setup_monitoring.sh` via `user_data` on first boot — this installs and starts all three services automatically

---

### Step 6 — Read the Output

After `apply` completes, Terraform prints the access URLs:

```
Outputs:

instance_public_ip  = "3.x.x.x"
prometheus_url      = "http://3.x.x.x:9090"
grafana_url         = "http://3.x.x.x:3000"
node_exporter_url   = "http://3.x.x.x:9100/metrics"
```

> Wait **3-5 minutes** after `apply` for the instance to boot and all services to start.

---

### Step 7 — Verify Prometheus

1. Open `http://<public_ip>:9090` in your browser
2. Go to **Status > Targets**
3. You should see two targets UP:
   - `prometheus` (localhost:9090)
   - `node_exporter` (localhost:9100)

---

### Step 8 — Set Up Grafana

1. Open `http://<public_ip>:3000` in your browser
2. Log in with default credentials:
   - **Username:** `admin`
   - **Password:** `admin`
   - You will be prompted to change the password on first login

3. **Add Prometheus as a Data Source:**
   - Go to **Connections > Data Sources > Add data source**
   - Select **Prometheus**
   - Set the URL to: `http://localhost:9090`
   - Click **Save & Test** — you should see "Data source is working"

4. **Import a Node Exporter Dashboard:**
   - Go to **Dashboards > Import**
   - Enter dashboard ID: `1860` (Node Exporter Full — community dashboard)
   - Click **Load**
   - Select your Prometheus data source
   - Click **Import**

You now have a full system metrics dashboard showing CPU, memory, disk, and network usage.

---

### Step 9 — Destroy Resources (Cleanup)

To avoid unnecessary AWS charges:

```bash
terraform destroy
```

Type `yes` when prompted. This terminates the EC2 instance and deletes the security group.

---

## What the Shell Script Does

`scripts/setup_monitoring.sh` runs automatically on the EC2 instance via `user_data`:

| Step | What it does |
|------|-------------|
| Install dependencies | `wget`, `curl`, `apt-transport-https` |
| Install Node Exporter | Downloads binary, creates system user, registers as a systemd service on port `9100` |
| Install Prometheus | Downloads binary, creates config at `/etc/prometheus/prometheus.yml`, registers as a systemd service on port `9090` |
| Configure Prometheus | Sets up scrape jobs for both `prometheus` and `node_exporter` targets |
| Install Grafana | Adds Grafana apt repo, installs via `apt`, registers as a systemd service on port `3000` |
| Start all services | Enables and starts `node_exporter`, `prometheus`, and `grafana-server` via `systemctl` |

---

## Ports Reference

| Port | Service | Purpose |
|------|---------|---------|
| `22` | SSH | Remote terminal access |
| `9090` | Prometheus | Metrics storage and query UI |
| `9100` | Node Exporter | Exposes raw system metrics |
| `3000` | Grafana | Dashboard and visualization UI |

---

## Submission

- Push all files (including `.env.example` and output screenshots) to GitHub
- **Do not push `.env`** — it is gitignored to protect your credentials
- Submit the GitHub repository URL in the portal
