# Brain Tasks App - Production Deployment

A modern React task management application deployed on AWS EKS with full CI/CD pipeline using AWS CodePipeline, CodeBuild, and CodeDeploy.

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
- **CI/CD**: AWS CodePipeline, CodeBuild, CodeDeploy
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

### 1. ECR Setup
```bash
# Make the script executable
chmod +x ecr-setup.sh

# Run the ECR setup script
./ecr-setup.sh
```

### 2. EKS Cluster Setup
```bash
# Make the script executable
chmod +x eks-setup.sh

# Run the EKS setup script
./eks-setup.sh
```

### 3. Manual Kubernetes Deployment
```bash
# Apply namespace
kubectl apply -f k8s/namespace.yaml

# Apply deployment
kubectl apply -f k8s/deployment.yaml

# Apply service
kubectl apply -f k8s/service.yaml

# Check deployment status
kubectl get pods -n brain-tasks
kubectl get services -n brain-tasks
```

## 🔄 CI/CD Pipeline

### Pipeline Stages

1. **Source**: GitHub repository
2. **Build**: AWS CodeBuild
   - Builds Docker image
   - Pushes to ECR
   - Creates deployment artifacts
3. **Deploy**: AWS CodeDeploy
   - Deploys to EKS cluster
   - Runs validation checks

### Build Process (buildspec.yml)
- **Install Phase**: Installs Docker and AWS CLI
- **Pre-build Phase**: Logs into ECR
- **Build Phase**: Builds and tags Docker image
- **Post-build Phase**: Pushes image to ECR and creates artifacts

### Deployment Process (appspec.yml)
- **BeforeInstall**: Sets up EKS namespace and secrets
- **AfterInstall**: Applies Kubernetes manifests
- **ApplicationStart**: Scales deployment and shows load balancer URL
- **ValidateService**: Validates deployment health

## 📁 Project Structure

```
Brain-Tasks-App/
├── src/                    # React source code
│   ├── App.jsx            # Main application component
│   ├── App.css            # Application styles
│   ├── main.jsx           # Application entry point
│   └── index.css          # Global styles
├── k8s/                    # Kubernetes manifests
│   ├── namespace.yaml     # Kubernetes namespace
│   ├── deployment.yaml    # Application deployment
│   ├── service.yaml       # Load balancer service
│   └── ecr-secret.yaml    # ECR registry secret
├── scripts/                # CodeDeploy hooks
│   ├── before_install.sh   # Pre-installation script
│   ├── after_install.sh    # Post-installation script
│   ├── start_application.sh # Application startup script
│   └── validate_service.sh # Service validation script
├── dist/                   # Production build output
├── Dockerfile             # Docker configuration
├── package.json           # Node.js dependencies
├── vite.config.js         # Vite configuration
├── buildspec.yml          # CodeBuild configuration
├── appspec.yml            # CodeDeploy configuration
├── ecr-setup.sh           # ECR setup script
├── eks-setup.sh           # EKS setup script
└── README.md              # This file
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

### appspec.yml
- AWS CodeDeploy configuration
- Deployment hooks for EKS
- Service validation

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

**Note**: Replace `123456789012` in `k8s/deployment.yaml` with your actual AWS account ID before deployment.
