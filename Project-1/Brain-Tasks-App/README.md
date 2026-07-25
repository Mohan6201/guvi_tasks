# Brain Tasks App - Production Deployment

A modern React task management application deployed on AWS EKS with a full CI/CD pipeline using AWS CodePipeline and CodeBuild (build + deploy stages). Every AWS resource name/setting is centralized in one `.env` file - see **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** for the full step-by-step setup.

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
- **Load Balancer**: AWS Application Load Balancer

### Infrastructure
- **EKS Cluster**: brain-tasks-cluster (us-east-1)
- **Node Group**: t3.medium instances (1-3 nodes)
- **Namespace**: brain-tasks
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
- AWS IAM permissions for:
  - ECR (Elastic Container Registry)
  - EKS (Elastic Kubernetes Service)
  - CodeBuild, CodeDeploy, CodePipeline
  - IAM roles for EKS cluster and nodes

## 🛠️ Local Development Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Brain-Tasks-App
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

Everything is driven by `.env` (`cp .env.example .env`, fill in values).
Full walkthrough with explanations: **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)**.

```bash
./iam-setup.sh          # 1. IAM roles for EKS/CodeBuild/CodePipeline
./ecr-setup.sh           # 2. ECR repository
./eks-setup.sh           # 3. EKS cluster + node group
./codebuild-setup.sh     # 4. CodeBuild build + deploy projects
# 5. one-time manual step: create a GitHub connection in the console,
#    paste its ARN into CODESTAR_CONNECTION_ARN in .env
./codepipeline-setup.sh  # 6. Source -> Build -> Deploy pipeline
```

Manual/local Kubernetes deploy (no pipeline needed):
```bash
./k8s/deploy.sh
```

## 🔄 CI/CD Pipeline

### Pipeline Stages

1. **Source**: GitHub, via a CodeStar Connection
2. **Build**: AWS CodeBuild (`buildspec.yml`) - builds the Docker image
   and pushes it to ECR
3. **Deploy**: AWS CodeBuild (`buildspec-deploy.yml`) - renders the k8s
   manifests with the built image, `kubectl apply`s them to EKS, waits
   for rollout, prints the LoadBalancer URL

> CodeDeploy does not support EKS as a deployment target, so the Deploy
> stage is a second CodeBuild project rather than CodeDeploy/`appspec.yml`
> (kept in the repo only as a reference, not invoked). See
> DEPLOYMENT_GUIDE.md for details.

### Build Process (buildspec.yml)
- **Install Phase**: Verifies Docker/AWS CLI (already on the managed image)
- **Pre-build Phase**: Logs into ECR
- **Build Phase**: `npm run build`, then builds and tags the Docker image
- **Post-build Phase**: Pushes image to ECR, writes `image-uri.txt` /
  `imagedefinitions.json` artifacts for the Deploy stage

### Deploy Process (buildspec-deploy.yml)
- Installs `kubectl`, points it at the EKS cluster from `.env`
- Renders `k8s/*.yaml` templates with the real image URI (`k8s/render.sh`)
- Refreshes the ECR pull secret, applies namespace/deployment/service
- Waits for rollout, prints the LoadBalancer hostname

## 📁 Project Structure

```
Brain-Tasks-App/
├── src/                    # React source code
│   ├── App.jsx            # Main application component
│   ├── App.css            # Application styles
│   ├── main.jsx           # Application entry point
│   └── index.css          # Global styles
├── k8s/                    # Kubernetes manifests (${VAR} templates)
│   ├── namespace.yaml     # Namespace template
│   ├── deployment.yaml    # Deployment template
│   ├── service.yaml       # LoadBalancer service template
│   ├── render.sh          # Renders templates from .env -> k8s/rendered/
│   ├── deploy.sh          # Manual local deploy (render + apply + wait)
│   └── ecr-secret.yaml    # Deprecated - secret now created imperatively
├── scripts/                # Reference only (see appspec.yml note below)
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
├── appspec.yml             # Deprecated - CodeDeploy doesn't support EKS
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
- Artifact generation

### appspec.yml (deprecated)
- CodeDeploy does not support EKS as a deployment platform, so this file
  is not used by the pipeline - kept only as a reference for the deploy
  steps, which are actually implemented in `buildspec-deploy.yml`

## 📊 Monitoring and Logging

### CloudWatch Integration
- Build logs in CodeBuild
- Deployment logs in CodeDeploy
- Application logs via CloudWatch agent (optional)

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
   - Wait for LB provisioning (5-10 minutes)

4. **Pods Not Starting**
   - Check image pull policy and ECR credentials
   - Verify resource limits
   - Check node group capacity

### Debug Commands
```bash
# Check deployment status
kubectl rollout status deployment/brain-tasks-app -n brain-tasks

# Get detailed pod information
kubectl describe pods -n brain-tasks -l app=brain-tasks-app

# Check events
kubectl get events -n brain-tasks --sort-by=.metadata.creationTimestamp
```

## 📈 Performance Considerations

### Resource Limits
- Memory: 128Mi request, 256Mi limit per pod
- CPU: 100m request, 200m limit per pod
- Replicas: 3 for high availability

### Scaling
- Horizontal Pod Autoscaler can be added
- Node group can scale from 1-3 nodes
- Load Balancer handles traffic distribution

## 🔒 Security

- ECR repository with image scanning enabled
- IAM roles for EKS cluster and nodes
- Network policies (can be added)
- Secrets management via Kubernetes secrets

## 📝 Deployment Commands Summary

```bash
# 1. Local development
npm install && npm run dev

# 2. Docker build and test
docker build -t brain-tasks-app:latest .
docker run -d -p 8080:80 brain-tasks-app:latest

# 3. AWS ECR setup
./ecr-setup.sh

# 4. AWS EKS setup
./eks-setup.sh

# 5. Deploy to Kubernetes
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# 6. Check deployment
kubectl get pods -n brain-tasks
kubectl get services -n brain-tasks
```

## 🎯 Load Balancer Access

After successful deployment, the application will be accessible via the AWS Load Balancer URL:

```bash
kubectl get service brain-tasks-app-service -n brain-tasks -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## 📞 Support

For issues and questions:
1. Check the troubleshooting section
2. Review CloudWatch logs
3. Verify AWS IAM permissions
4. Check Kubernetes events and pod status

---

**Note**: `k8s/deployment.yaml` / `service.yaml` / `namespace.yaml` are `${VAR}` templates - values come from `.env` via `k8s/render.sh`, nothing to hand-edit.
