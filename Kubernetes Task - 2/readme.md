# Kubernetes Task - 2

## Task Description

Create an **AWS EKS cluster**, deploy an **Nginx application** on it, and expose it to the outside world via a **LoadBalancer service**.

---

## Tech Stack

- **AWS EKS** — Managed Kubernetes cluster on AWS
- **eksctl** — CLI tool to create and manage EKS clusters declaratively
- **kubectl** — Kubernetes CLI to deploy and manage workloads
- **AWS LoadBalancer** — Exposes the Nginx deployment to the public internet

---

## Project Structure

```
Kubernetes Task - 2/
├── cluster/
│   └── eks-cluster.yaml       # eksctl cluster config (env var templated)
├── k8s/
│   ├── deployment.yaml        # Nginx Deployment (2 replicas)
│   └── service.yaml           # LoadBalancer Service to expose Nginx externally
├── scripts/
│   ├── setup.sh               # End-to-end: create cluster + deploy nginx
│   └── teardown.sh            # Delete deployment and cluster
├── .env                       # Your actual credentials and config — never commit this
├── .env.example               # Safe-to-commit template showing all required variables
├── .gitignore                 # Excludes .env and generated files
└── readme.md                  # This file
```

---

## Architecture

```
Internet
   │
   ▼
AWS LoadBalancer  (port 80)
   │
   ▼
nginx-service  (ClusterIP → LoadBalancer)
   │
   ├──▶ nginx-pod-1  (port 80)
   └──▶ nginx-pod-2  (port 80)

All pods run inside:
  EKS Cluster → Managed Node Group (t3.medium × 2)
```

---

## Environment Variables

All credentials and configuration are driven through environment variables — **nothing is hardcoded**.

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` | Your AWS Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | Your AWS Secret Access Key |
| `AWS_DEFAULT_REGION` | AWS region for the EKS cluster (e.g. `us-east-1`) |
| `CLUSTER_NAME` | Name of the EKS cluster to create |
| `K8S_VERSION` | Kubernetes version (e.g. `1.29`) |
| `NODE_INSTANCE_TYPE` | EC2 instance type for worker nodes (e.g. `t3.medium`) |
| `NODE_DESIRED` | Desired number of worker nodes |
| `NODE_MIN` | Minimum number of worker nodes |
| `NODE_MAX` | Maximum number of worker nodes |

> The `cluster/eks-cluster.yaml` is a template. The `setup.sh` script uses `envsubst` to substitute all `${VARIABLE}` placeholders before passing it to `eksctl`.

---

## Prerequisites

Install the following tools before proceeding:

1. **AWS CLI** — [Install guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
   ```bash
   aws --version
   ```

2. **eksctl** — [Install guide](https://eksctl.io/installation/)
   ```bash
   eksctl version
   ```

3. **kubectl** — [Install guide](https://kubernetes.io/docs/tasks/tools/)
   ```bash
   kubectl version --client
   ```

4. **envsubst** — included in the `gettext` package
   ```bash
   # Linux
   sudo apt-get install -y gettext

   # macOS
   brew install gettext && brew link --force gettext
   ```

5. **AWS IAM Permissions** — your AWS user must have permissions for:
   - EKS (create/describe/delete cluster)
   - EC2 (instances, VPC, security groups)
   - IAM (roles and policies for EKS)
   - CloudFormation (eksctl uses it internally)

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
AWS_DEFAULT_REGION=us-east-1

# EKS Cluster Config
CLUSTER_NAME=nginx-eks-cluster
K8S_VERSION=1.29
NODE_INSTANCE_TYPE=t3.medium
NODE_DESIRED=2
NODE_MIN=1
NODE_MAX=3
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
echo $CLUSTER_NAME
echo $AWS_DEFAULT_REGION
```

---

### Step 3 — Run the Setup Script

The `setup.sh` script handles everything end-to-end:

```bash
cd scripts
chmod +x setup.sh
./setup.sh
```

The script will:
1. Check all prerequisites are installed
2. Validate all required environment variables are set
3. Create the EKS cluster using `eksctl` (~15-20 minutes)
4. Update `kubeconfig` so `kubectl` points to the new cluster
5. Wait for all worker nodes to be `Ready`
6. Deploy the Nginx `Deployment` (2 replicas) and `LoadBalancer` Service
7. Wait for the LoadBalancer to get an external hostname
8. Print the public URL to access Nginx

---

### Step 4 — Verify the Cluster

Check nodes are running:
```bash
kubectl get nodes
```

Expected output:
```
NAME                          STATUS   ROLES    AGE   VERSION
ip-192-168-x-x.ec2.internal   Ready    <none>   5m    v1.29.x
ip-192-168-x-x.ec2.internal   Ready    <none>   5m    v1.29.x
```

---

### Step 5 — Verify the Deployment

Check all pods and services:
```bash
kubectl get all
```

Expected output:
```
NAME                                    READY   STATUS    RESTARTS   AGE
pod/nginx-deployment-xxxxxx-xxxxx       1/1     Running   0          2m
pod/nginx-deployment-xxxxxx-xxxxx       1/1     Running   0          2m

NAME                    TYPE           CLUSTER-IP     EXTERNAL-IP                        PORT(S)
service/nginx-service   LoadBalancer   10.100.x.x     xxxx.us-east-1.elb.amazonaws.com   80:xxxxx/TCP
```

---

### Step 6 — Access Nginx Externally

Copy the `EXTERNAL-IP` hostname from the service output and open it in your browser:

```bash
curl http://<EXTERNAL-IP>
```

Or get it directly:
```bash
kubectl get svc nginx-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

You should see the **nginx welcome page**.

> It may take **2-3 minutes** after the service is created for the AWS LoadBalancer to be fully provisioned.

---

### Step 7 — Teardown (Cleanup)

To delete all resources and avoid AWS charges:

```bash
cd scripts
chmod +x teardown.sh
./teardown.sh
```

This will:
1. Delete the Nginx Service and Deployment from the cluster
2. Delete the entire EKS cluster and all associated AWS resources (VPC, node group, etc.)

---

## File Details

### `cluster/eks-cluster.yaml`

A declarative eksctl cluster config template. Variables like `${CLUSTER_NAME}` are substituted at runtime by `setup.sh` using `envsubst`.

- Uses **managed node groups** — AWS manages node upgrades and patching
- Enables **OIDC** — required for IAM Roles for Service Accounts (IRSA)

### `k8s/deployment.yaml`

Deploys **2 replicas** of the official `nginx:latest` image with defined CPU and memory resource limits.

### `k8s/service.yaml`

Exposes the Nginx deployment via a **LoadBalancer** service on port `80`. AWS automatically provisions an ELB (Elastic Load Balancer) and assigns a public hostname.

### `scripts/setup.sh`

End-to-end setup script that creates the cluster, deploys Nginx, and polls until the external URL is available.

### `scripts/teardown.sh`

Cleanup script that deletes the Kubernetes resources first, then the entire EKS cluster.

---

## Submission

- Push all files (including `.env.example` and output screenshots) to GitHub
- **Do not push `.env`** — it is gitignored to protect your credentials
- Submit the GitHub repository URL in the portal
