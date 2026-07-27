# Brain Tasks App - Production Deployment

A React task management application deployed on AWS EKS with a full CI/CD pipeline: **GitHub → CodePipeline → CodeBuild (build) → CodeBuild (deploy) → EKS**. Every AWS resource name/setting is centralized in one `.env` file - see **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** for the full step-by-step setup.

## ✅ Live Deployment (verified)

The pipeline has been run end-to-end and the app is live and responding.

| | |
|---|---|
| **App URL** | http://aec0476e2c4434817b96dbde314cfb8a-1180093499.us-east-1.elb.amazonaws.com |
| **Load Balancer ARN** | `arn:aws:elasticloadbalancing:us-east-1:074925547344:loadbalancer/aec0476e2c4434817b96dbde314cfb8a` |
| **Load Balancer type** | Classic Load Balancer (default for a plain `type: LoadBalancer` Service on EKS - no AWS Load Balancer Controller installed) |
| **HTTP check** | `200 OK`, serving the built React app |
| **EKS cluster** | `brain-tasks-cluster` (us-east-1), nodes `Ready` |
| **Pods** | 3/3 `Running`, rollout complete |
| **Pipeline stages** | Source ✅ Build ✅ Deploy ✅ (all `Succeeded`) |

Verify it yourself:
```bash
kubectl get pods -n brain-tasks -l app=brain-tasks-app
kubectl get service brain-tasks-app-service -n brain-tasks
curl -I http://aec0476e2c4434817b96dbde314cfb8a-1180093499.us-east-1.elb.amazonaws.com/
```

## 🚀 Application Overview

The Brain Tasks App is a responsive task management application built with React and Vite. It allows users to create, manage, and track their daily tasks with a clean and intuitive interface.

### Features
- ✅ Add and delete tasks
- ✅ Mark tasks as complete/incomplete
- ✅ Task statistics (total, completed, pending)
- ✅ Responsive design for mobile and desktop
- ✅ Modern UI with smooth animations

## 🏗️ Architecture

### Technology Stack
- **Frontend**: React 18, Vite
- **Styling**: CSS3 with modern design
- **Containerization**: Docker with nginx
- **Orchestration**: Kubernetes (EKS)
- **CI/CD**: AWS CodePipeline, CodeBuild (Build stage + Deploy stage)
- **Container Registry**: AWS ECR
- **Load Balancer**: Classic Load Balancer (Kubernetes `Service` of `type: LoadBalancer`)

### Infrastructure
- **EKS Cluster**: `brain-tasks-cluster` (us-east-1)
- **Node Group**: `brain-tasks-nodes`, t3.medium instances (min 1 / desired 2 / max 3)
- **Namespace**: `brain-tasks`
- **Service Type**: LoadBalancer
- **Replicas**: 3 pods for high availability

## 📋 Prerequisites

### Local Development
- Node.js 18+
- npm or yarn
- Docker Desktop
- Git

### AWS Deployment
- AWS CLI configured with appropriate permissions
- kubectl
- AWS IAM permissions for: ECR, EKS, CodeBuild, CodePipeline, IAM (to create the roles the scripts need)

## 🛠️ Local Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/Mohan6201/guvi_tasks.git
   cd guvi_tasks/Project-1/Brain-Tasks-App
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Run development server**
   ```bash
   npm run dev
   ```
   Application will be available at http://localhost:5173

4. **Build for production**
   ```bash
   npm run build
   ```

5. **Run production build locally**
   ```bash
   npm start
   ```
   Application will be available at http://localhost:3000

## 🐳 Docker Setup

1. **Build Docker image**
   ```bash
   docker build -t brain-tasks-app:latest .
   ```

2. **Run Docker container**
   ```bash
   docker run -d -p 8080:80 --name brain-tasks-container brain-tasks-app:latest
   ```
   Application will be available at http://localhost:8080

## ☁️ AWS Deployment

Everything is driven by `.env` (`cp .env.example .env`, fill in values). This is exactly the sequence that produced the live deployment above.

```bash
./iam-setup.sh          # 1. IAM roles for EKS/CodeBuild/CodePipeline
./ecr-setup.sh           # 2. ECR repository
./eks-setup.sh           # 3. EKS cluster + node group
./codebuild-setup.sh     # 4. CodeBuild build + deploy projects
# 5. one-time manual step: create a GitHub connection in the console,
#    paste its ARN into CODESTAR_CONNECTION_ARN in .env
./codepipeline-setup.sh  # 6. Source -> Build -> Deploy pipeline
aws codepipeline start-pipeline-execution --name brain-tasks-app-pipeline --region us-east-1
```

Full walkthrough with explanations: **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)**.

Manual/local Kubernetes deploy (no pipeline needed):
```bash
./k8s/deploy.sh
```

## 🔄 CI/CD Pipeline

### Pipeline Stages (`brain-tasks-app-pipeline`)

1. **Source**: GitHub (`Mohan6201/guvi_tasks`, branch `main`), via a CodeStar Connection
2. **Build**: AWS CodeBuild project `brain-tasks-app-build` (`buildspec.yml`) - builds the Docker image and pushes it to ECR
3. **Deploy**: AWS CodeBuild project `brain-tasks-app-deploy` (`buildspec-deploy.yml`) - renders the k8s manifests with the built image, `kubectl apply`s them to EKS, waits for rollout, prints the LoadBalancer URL

> CodeDeploy does not support EKS as a deployment target, so the Deploy
> stage is a second CodeBuild project rather than CodeDeploy/`appspec.yml`.
> An `appspec.yml` and CodeDeploy lifecycle-hook scripts (`scripts/*.sh`)
> were kept around briefly as a reference for what each deploy step
> conceptually does, but `appspec.yml` itself has since been removed — it
> was never invoked by anything (CodeDeploy can't target EKS at all), so
> keeping it risked implying a deploy path that doesn't actually exist.
> `scripts/*.sh` remain for now as conceptual reference only; the real
> deploy logic lives entirely in `buildspec-deploy.yml`. See
> DEPLOYMENT_GUIDE.md for details.

### Build Process (buildspec.yml)
- **Install Phase**: Verifies Docker/AWS CLI (already on the managed image)
- **Pre-build Phase**: Logs into ECR
- **Build Phase**: `npm run build`, then builds and tags the Docker image
- **Post-build Phase**: Pushes image to ECR, writes `image-uri.txt` / `imagedefinitions.json` / `buildspec-deploy.yml` as artifacts for the Deploy stage

### Deploy Process (buildspec-deploy.yml)
- Installs `kubectl`, points it at the EKS cluster from `.env`
- Renders `k8s/*.yaml` templates with the real image URI (`k8s/render.sh`)
- Refreshes the ECR pull secret, applies namespace/deployment/service
- Waits for rollout, prints the LoadBalancer hostname

## 📁 Project Structure

```
Brain-Tasks-App/
├── src/                    # React source code
│   ├── App.jsx             # Main application component
│   ├── App.css             # Application styles
│   ├── main.jsx            # Application entry point
│   └── index.css           # Global styles
├── k8s/                    # Kubernetes manifests (${VAR} templates)
│   ├── namespace.yaml      # Namespace template
│   ├── deployment.yaml     # Deployment template
│   ├── service.yaml        # LoadBalancer service template
│   ├── render.sh           # Renders templates from .env -> k8s/rendered/
│   ├── deploy.sh           # Manual local deploy (render + apply + wait)
│   └── ecr-secret.yaml     # Deprecated - secret now created imperatively
├── scripts/                # CodeDeploy lifecycle-hook scripts, reference only -
│   │                        # not invoked by anything (see note below)
│   ├── before_install.sh
│   ├── after_install.sh
│   ├── start_application.sh
│   └── validate_service.sh
├── dist/                   # Production build output
├── .env.example            # Config template - copy to .env and fill in
├── .env                    # Real config (gitignored)
├── Dockerfile              # Docker configuration
├── package.json            # Node.js dependencies
├── vite.config.js          # Vite configuration
├── buildspec.yml           # CodeBuild: build image, push to ECR
├── buildspec-deploy.yml    # CodeBuild: kubectl apply to EKS
├── iam-setup.sh            # Step 1: IAM roles
├── ecr-setup.sh            # Step 2: ECR repository
├── eks-setup.sh            # Step 3: EKS cluster + node group
├── codebuild-setup.sh      # Step 4: CodeBuild projects
├── codepipeline-setup.sh   # Step 6: CodePipeline
├── DEPLOYMENT_GUIDE.md     # Full step-by-step guide
└── README.md               # This file
```

## 🔧 Configuration Files

### Dockerfile
- Uses nginx:alpine as base image
- Serves static React app from dist/ directory
- Exposes port 80

### buildspec.yml
- AWS CodeBuild configuration
- Multi-stage build process
- ECR integration
- Artifact generation (including `buildspec-deploy.yml` for the Deploy stage)

## 📊 Monitoring and Logging

### CloudWatch Integration
- Build stage logs: CloudWatch Logs group `/aws/codebuild/brain-tasks-app` (stream per build, project `brain-tasks-app-build`)
- Deploy stage logs: same log group, project `brain-tasks-app-deploy`
- Application/pod logs: `kubectl logs` (see below); not shipped to CloudWatch unless Container Insights/Fluent Bit is added

### Kubernetes Monitoring
```bash
# View pod logs
kubectl logs -n brain-tasks -l app=brain-tasks-app -f

# Check pod status
kubectl get pods -n brain-tasks -w

# View service details
kubectl describe service brain-tasks-app-service -n brain-tasks
```

## 🚨 Troubleshooting

### Common Issues

1. **Docker Build Fails**
   - Ensure dist/ directory exists (run `npm run build`)
   - Check Dockerfile syntax

2. **EKS Deployment Fails**
   - Verify IAM roles and permissions
   - Check kubeconfig configuration
   - Validate ECR repository access

3. **Load Balancer Not Accessible**
   - Check security group configuration
   - Verify service type is LoadBalancer
   - Wait for LB provisioning (a few minutes for DNS to propagate)

4. **Pods Not Starting**
   - Check image pull policy and ECR credentials
   - Verify resource limits
   - Check node group capacity

5. **CodeBuild `--environment` CLI parsing errors (Windows/Git Bash)**
   - Two Windows-specific gotchas hit during setup, both already fixed in the scripts:
     - Git Bash (MSYS) rewrites `/`-leading arguments (e.g. CloudWatch log group `/aws/codebuild/...`) into Windows paths - scripts now `export MSYS_NO_PATHCONV=1` internally.
     - The AWS CLI's shorthand parser can't reliably parse a nested list-of-objects (`environmentVariables=[...]`) inside `--environment`; scripts now pass `--environment` as raw JSON instead of shorthand.

### Debug Commands
```bash
# Check deployment status
kubectl rollout status deployment/brain-tasks-app -n brain-tasks

# Get detailed pod information
kubectl describe pods -n brain-tasks -l app=brain-tasks-app

# Check events
kubectl get events -n brain-tasks --sort-by=.metadata.creationTimestamp

# Check pipeline/build status
aws codepipeline get-pipeline-state --name brain-tasks-app-pipeline --region us-east-1
aws codebuild list-builds-for-project --project-name brain-tasks-app-build --region us-east-1
```

## 📈 Performance Considerations

### Resource Limits
- Memory: 128Mi request, 256Mi limit per pod
- CPU: 100m request, 200m limit per pod
- Replicas: 3 for high availability

### Scaling
- Horizontal Pod Autoscaler can be added
- Node group can scale from 1-3 nodes (currently running 2)
- Load Balancer handles traffic distribution

## 🔒 Security

- ECR repository with image scanning enabled
- IAM roles for EKS cluster, nodes, CodeBuild, and CodePipeline (least-privilege managed policies, created by `iam-setup.sh`)
- AWS credentials never stored in `.env` or the repo - local scripts use the AWS CLI's configured identity, CodeBuild uses its IAM service role
- Network policies (can be added)
- Secrets management via Kubernetes secrets (ECR pull secret refreshed on every deploy, since ECR tokens expire every 12h)

## 🎯 Load Balancer Access

```bash
kubectl get service brain-tasks-app-service -n brain-tasks -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

To get the Load Balancer ARN (needed for submission), match the hostname against the classic ELB API:
```bash
aws elb describe-load-balancers --region us-east-1 --query "LoadBalancerDescriptions[].LoadBalancerName" --output text
# then: arn:aws:elasticloadbalancing:<region>:<account-id>:loadbalancer/<name>
```

## 📞 Support

For issues and questions:
1. Check the troubleshooting section
2. Review CloudWatch logs (`/aws/codebuild/brain-tasks-app`)
3. Verify AWS IAM permissions
4. Check Kubernetes events and pod status

---

**Note**: `k8s/deployment.yaml` / `service.yaml` / `namespace.yaml` are `${VAR}` templates - values come from `.env` via `k8s/render.sh`, nothing to hand-edit.
