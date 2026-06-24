# TrendStore — DevOps Deployment

## Task Description

Dockerize and deploy a React application to **AWS EKS**, provision infrastructure with **Terraform**, automate builds with **Jenkins CI/CD** (GitHub Webhook triggered), push images to **DockerHub**, and monitor the cluster with **Prometheus + Grafana**.

---

## Tech Stack

- **Docker** — Containerize the React app (nginx:alpine, port 80)
- **DockerHub** — Store and version Docker images
- **Terraform** — Provision VPC, EKS cluster, and Jenkins EC2
- **AWS EKS** — Managed Kubernetes cluster to run the app
- **Jenkins** — CI/CD pipeline with GitHub Webhook auto-trigger
- **Prometheus + Grafana** — Cluster monitoring and dashboards deployed on EKS

---

## Project Structure

```
Trend/
├── Dockerfile                  # nginx:alpine serving React dist/ on port 80
├── nginx.conf                  # Custom nginx config
├── terraform/
│   ├── main.tf                 # VPC, subnets, EKS cluster, Jenkins EC2
│   ├── variables.tf            # All input variables (no hardcoded values)
│   └── outputs.tf              # Jenkins URL, EKS name, kubeconfig command
├── scripts/
│   └── setup_jenkins.sh        # Installs Docker, Jenkins, kubectl, AWS CLI on EC2
├── jenkins/
│   ├── Jenkinsfile             # Declarative pipeline — build, test, push, deploy
│   └── setup.sh                # Jenkins plugin installation guide
├── k8s/
│   ├── deployment.yaml         # Trend app Deployment (3 replicas)
│   ├── service.yaml            # ClusterIP service + Ingress
│   └── loadbalancer.yaml       # LoadBalancer service for public access
├── monitoring/
│   ├── prometheus.yaml         # Prometheus Deployment + Service in monitoring namespace
│   ├── grafana.yaml            # Grafana Deployment + Secret + Service
│   └── setup.sh                # Deploys monitoring stack to EKS
├── .env                        # Your credentials — never commit this
├── .env.example                # Safe template to commit
├── .dockerignore
├── .gitignore
└── README.md
```

---

## Architecture

```
GitHub push
    │
    ▼ webhook
Jenkins (EC2 t2.medium)
    │
    ├── docker build → DockerHub (<username>/trend-app)
    │
    └── kubectl apply → AWS EKS Cluster
                            │
                            ├── trend-app pods (3 replicas)
                            │       └── LoadBalancer → public internet
                            │
                            └── monitoring namespace
                                    ├── Prometheus :9090
                                    └── Grafana    :3000
```

---

## Environment Variables

All credentials and config are driven through environment variables — **nothing is hardcoded**.

| Variable | Where Used | Description |
|----------|-----------|-------------|
| `AWS_ACCESS_KEY_ID` | Terraform, AWS CLI | AWS Access Key |
| `AWS_SECRET_ACCESS_KEY` | Terraform, AWS CLI | AWS Secret Key |
| `TF_VAR_aws_region` | Terraform | AWS region (e.g. `us-east-1`) |
| `TF_VAR_environment` | Terraform | Environment tag (e.g. `production`) |
| `TF_VAR_cluster_name` | Terraform | EKS cluster name |
| `TF_VAR_node_instance_type` | Terraform | EKS worker node type (e.g. `t3.medium`) |
| `TF_VAR_jenkins_instance_type` | Terraform | Jenkins EC2 type (e.g. `t2.medium`) |
| `TF_VAR_key_name` | Terraform | EC2 key pair name for SSH |
| `DOCKERHUB_USERNAME` | Jenkins global env | DockerHub username |
| `DOCKERHUB_PASSWORD` | Jenkins credentials | DockerHub password/token |
| `EKS_CLUSTER_NAME` | Jenkins global env | EKS cluster to deploy to |
| `AWS_DEFAULT_REGION` | Jenkins global env | AWS region for kubectl config |

---

## Prerequisites

1. **AWS Account** with EC2, EKS, IAM, and VPC permissions
2. **Terraform** >= 1.3.0
3. **AWS CLI** installed locally
4. **EC2 Key Pair** in your target region
5. **DockerHub account** — create a public repo `<username>/trend-app`

---

## Step-by-Step Setup

### Step 1 — Set Up `.env`

```bash
cp .env.example .env
```

Fill in your actual values in `.env`. Never commit this file.

---

### Step 2 — Load Environment Variables

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

### Step 3 — Provision Infrastructure with Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This creates:
- VPC with public and private subnets across 2 AZs
- EKS cluster (`trend-eks-cluster`) with 2 × t3.medium worker nodes
- EC2 instance for Jenkins with Docker, Java 17, Jenkins, kubectl, and AWS CLI pre-installed
- IAM roles for EKS cluster and nodes
- Security groups

Note the outputs:
```
jenkins_url      = "http://x.x.x.x:8080"
ssh_command      = "ssh -i ~/.ssh/my-key-pair.pem ubuntu@x.x.x.x"
kubeconfig_command = "aws eks update-kubeconfig --region us-east-1 --name trend-eks-cluster"
```

---

### Step 4 — Configure kubectl for EKS

Run the kubeconfig command from Terraform outputs:
```bash
aws eks update-kubeconfig --region us-east-1 --name trend-eks-cluster
kubectl get nodes
# Expected: 2 nodes in Ready state
```

---

### Step 5 — Test Docker Build Locally

```bash
docker build -t trend-app:test .
docker run -p 8080:80 trend-app:test
curl http://localhost:8080
```

---

### Step 6 — Push Initial Image to DockerHub

```bash
docker tag trend-app:test $DOCKERHUB_USERNAME/trend-app:latest
echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
docker push $DOCKERHUB_USERNAME/trend-app:latest
```

---

### Step 7 — Deploy App to EKS Manually (First Time)

```bash
kubectl apply -f k8s/
kubectl get pods
kubectl get svc trend-app-loadbalancer
# Wait for EXTERNAL-IP to be assigned (~2 minutes)
```

Access the app at `http://<EXTERNAL-IP>`.

---

### Step 8 — Unlock Jenkins

Wait **3-5 minutes** after Terraform apply, then:

```bash
ssh -i ~/.ssh/<key>.pem ubuntu@<jenkins_ip>
./get_jenkins_password.sh
```

Open `http://<jenkins_ip>:8080`, paste the password, install suggested plugins, and create admin user.

---

### Step 9 — Install Additional Jenkins Plugins

Go to **Manage Jenkins > Plugins > Available plugins**:

| Plugin | Purpose |
|--------|---------|
| **Docker Pipeline** | Docker commands in pipeline |
| **GitHub** | GitHub webhook integration |
| **Pipeline** | Declarative Jenkinsfile |
| **AWS Steps** | AWS CLI in pipeline |

Restart Jenkins after installation.

---

### Step 10 — Configure Jenkins Credentials and Global Env Vars

**Add DockerHub credential:**
1. **Manage Jenkins > Credentials > Global > Add Credentials**
   - Kind: **Username with password**
   - Username: your DockerHub username
   - Password: your DockerHub password/token
   - ID: `dockerhub-creds` ← must match Jenkinsfile exactly

**Add Global Environment Variables:**
1. **Manage Jenkins > System > Global Properties > Environment Variables**
2. Add:
   - `EKS_CLUSTER_NAME` = `trend-eks-cluster`
   - `AWS_DEFAULT_REGION` = `us-east-1`
   - `AWS_ACCESS_KEY_ID` = your key
   - `AWS_SECRET_ACCESS_KEY` = your secret

---

### Step 11 — Create Jenkins Pipeline Job

1. **New Item** → name `trendstore-pipeline` → **Pipeline** → OK
2. **Build Triggers** → check **GitHub hook trigger for GITScm polling**
3. **Pipeline** → **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: your GitHub repo URL
   - Branch: `*/main`
   - Script Path: `jenkins/Jenkinsfile`
4. Click **Save**

---

### Step 12 — Set Up GitHub Webhook

1. GitHub repo → **Settings > Webhooks > Add webhook**
2. **Payload URL:** `http://<jenkins_ip>:8080/github-webhook/`
3. **Content type:** `application/json`
4. **Events:** Just the **push** event
5. Click **Add webhook** — verify the green tick

---

### Step 13 — Test Auto-Trigger

```bash
echo "# trigger build" >> README.md
git add README.md
git commit -m "trigger Jenkins build"
git push origin main
```

Jenkins should auto-trigger within seconds and run all 5 pipeline stages.

---

### Step 14 — Deploy Monitoring Stack

```bash
cd monitoring
chmod +x setup.sh
./setup.sh
```

Access monitoring (wait ~2 min for LoadBalancer IPs):
```bash
kubectl get svc -n monitoring
```

- **Prometheus:** `http://<prometheus-lb-ip>:9090`
- **Grafana:** `http://<grafana-lb-ip>:3000` (admin / admin123)

In Grafana:
1. **Connections > Data Sources > Add** → Prometheus → URL: `http://prometheus-service.monitoring:9090`
2. **Dashboards > Import** → ID `3119` (Kubernetes cluster overview) → Import

---

### Step 15 — Cleanup

```bash
# Delete K8s resources first (avoids orphaned LoadBalancers)
kubectl delete -f k8s/
kubectl delete -f monitoring/

# Destroy infrastructure
cd terraform
terraform destroy
```

---

## Jenkins Pipeline Stages

| Stage | What it does |
|-------|-------------|
| **Checkout** | Pulls latest code from GitHub |
| **Build Docker Image** | Builds and tags `<username>/trend-app:$BUILD_NUMBER` |
| **Test Docker Image** | Runs container on port 8081, curls health check |
| **Push to DockerHub** | Pushes both `$BUILD_NUMBER` and `latest` tags |
| **Deploy to EKS** | Updates kubeconfig, applies k8s manifests, sets new image, waits for rollout |

---

## Submission

- GitHub repo URL submitted
- README with setup steps, pipeline explanation, and screenshots
- LoadBalancer EXTERNAL-IP documented
- DockerHub image name with tag documented
- Screenshots in repo:
  - Jenkins pipeline — successful build + console output
  - Terraform apply output
  - EKS nodes (`kubectl get nodes`) and pods (`kubectl get pods`)
  - DockerHub repo with image tags
  - Deployed app in browser at LoadBalancer IP
  - Grafana monitoring dashboard
