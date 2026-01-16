# Trend React Application - Production Deployment

This repository contains a complete CI/CD pipeline setup for deploying a React application to production using Docker, Kubernetes, Jenkins, and AWS EKS.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │───▶│     Jenkins     │───▶│    DockerHub    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Monitoring    │◀───│   AWS EKS       │◀───│  Docker Image   │
│ (Prometheus)    │    │   Kubernetes    │    │                 │
│   (Grafana)     │    │     Cluster     │    └─────────────────┘
└─────────────────┘    └─────────────────┘
```

## 📋 Prerequisites

- **AWS CLI** configured with appropriate permissions
- **Docker Desktop** installed and running
- **kubectl** configured for EKS
- **Terraform** installed
- **Node.js** and **npm** (for local development)
- **Git** installed

## 🚀 Quick Start

### 1. Clone and Setup Local Environment

```bash
git clone https://github.com/yourusername/trend.git
cd trend
```

### 2. Run Application Locally

```bash
# Install http-server globally
npm install -g http-server

# Run the application on port 3000
cd dist
http-server -p 3000 -c-1
```

Access the application at: `http://localhost:3000`

### 3. Docker Setup

#### Build Docker Image
```bash
# Make sure Docker Desktop is running
docker build -t trend-app:latest .
```

#### Test Docker Container
```bash
docker run -d -p 8080:80 --name trend-test trend-app:latest
curl http://localhost:8080
docker stop trend-test
docker rm trend-test
```

#### Push to DockerHub
```bash
# Login to DockerHub
docker login

# Tag and push
docker tag trend-app:latest yourdockerhub/trend-app:latest
docker push yourdockerhub/trend-app:latest
```

### 4. Infrastructure Setup with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the changes
terraform apply

# Get outputs
terraform output
```

This will create:
- VPC with public, private, and EKS subnets
- EKS Kubernetes cluster (1.29)
- EC2 instance with Jenkins pre-installed
- IAM roles and policies
- Security groups

### 5. Kubernetes Deployment

#### Configure kubectl for EKS
```bash
aws eks update-kubeconfig --region us-east-1 --name trend-eks-cluster
```

#### Deploy Application
```bash
# Update the image in k8s/deployment.yaml with your DockerHub image
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/loadbalancer.yaml

# Check deployment status
kubectl get pods
kubectl get services
kubectl get deployment
```

### 6. Jenkins Setup

#### Access Jenkins
Get the Jenkins server IP from Terraform outputs:
```bash
terraform output jenkins_public_ip
```

Access Jenkins at: `http://<jenkins-ip>:8080`

#### Initial Jenkins Setup
1. Get initial admin password:
   ```bash
   ssh -i your-key.pem ec2-user@<jenkins-ip>
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```

2. Install required plugins via script:
   ```bash
   cd jenkins
   chmod +x setup.sh
   ./setup.sh
   ```

#### Configure Jenkins Credentials
1. **DockerHub Credentials**:
   - Go to Manage Jenkins → Manage Credentials → Global → Add Credentials
   - Kind: Username with password
   - Username: Your DockerHub username
   - Password: Your DockerHub password
   - ID: `dockerhub-credentials`

2. **Kubernetes Config**:
   - Get kubeconfig file: `aws eks update-kubeconfig --region us-east-1 --name trend-eks-cluster`
   - Copy `~/.kube/config` file
   - Add as Secret file credential with ID: `kubeconfig`

#### Create Jenkins Pipeline
1. Create new pipeline project
2. Select "Pipeline script from SCM"
3. Repository URL: `https://github.com/yourusername/trend.git`
4. Script path: `jenkins/Jenkinsfile`

### 7. GitHub Webhook Setup

1. Go to your GitHub repository
2. Settings → Webhooks → Add webhook
3. Payload URL: `http://<jenkins-ip>:8080/github-webhook/`
4. Content type: `application/json`
5. Events: Just the `push` event

### 8. Monitoring Setup

```bash
cd monitoring
chmod +x setup.sh
./setup.sh
```

This will deploy:
- Prometheus for metrics collection
- Grafana for visualization

#### Access Monitoring
- **Prometheus**: `http://<prometheus-lb-ip>:9090`
- **Grafana**: `http://<grafana-lb-ip>:3000`
  - Username: `admin`
  - Password: `admin123`

#### Configure Grafana
1. Add Prometheus data source: `http://prometheus-service:9090`
2. Import Kubernetes dashboards

## 📁 Project Structure

```
trend/
├── dist/                   # Built React application
├── terraform/             # Infrastructure as code
│   ├── main.tf           # Main Terraform configuration
│   ├── variables.tf      # Input variables
│   └── outputs.tf        # Output variables
├── k8s/                   # Kubernetes manifests
│   ├── deployment.yaml   # Application deployment
│   ├── service.yaml      # Service and Ingress
│   └── loadbalancer.yaml # LoadBalancer service
├── jenkins/              # Jenkins configuration
│   ├── Jenkinsfile       # Declarative pipeline
│   └── setup.sh          # Jenkins setup script
├── monitoring/           # Monitoring stack
│   ├── prometheus.yaml   # Prometheus deployment
│   ├── grafana.yaml      # Grafana deployment
│   └── setup.sh          # Monitoring setup script
├── Dockerfile            # Docker configuration
├── nginx.conf            # Nginx configuration
├── .gitignore            # Git ignore rules
└── .dockerignore         # Docker ignore rules
```

## 🔄 CI/CD Pipeline

The Jenkins pipeline includes the following stages:

1. **Checkout**: Pulls latest code from GitHub
2. **Build Docker Image**: Creates Docker image with application
3. **Test Docker Image**: Validates container functionality
4. **Push to DockerHub**: Uploads image to registry
5. **Deploy to Kubernetes**: Applies Kubernetes manifests

### Pipeline Triggers
- **Automatic**: Triggered by GitHub webhook on every push
- **Manual**: Can be triggered manually from Jenkins UI

## 📊 Monitoring and Observability

### Prometheus Metrics
- Container resource usage
- Application response times
- Kubernetes cluster health
- Custom application metrics

### Grafana Dashboards
- Kubernetes cluster overview
- Application performance metrics
- Resource utilization
- Error rates and alerts

## 🔧 Configuration

### Environment Variables
Update the following files with your specific values:

1. **jenkins/Jenkinsfile**:
   - `DOCKER_IMAGE`: Your DockerHub repository
   - Email addresses for notifications

2. **k8s/deployment.yaml**:
   - `image`: Your DockerHub image path

3. **terraform/variables.tf**:
   - AWS region and other infrastructure settings

## 🚨 Troubleshooting

### Common Issues

1. **Docker Build Fails**:
   - Ensure Docker Desktop is running
   - Check Dockerfile syntax
   - Verify all required files are present

2. **Terraform Apply Fails**:
   - Check AWS credentials
   - Verify IAM permissions
   - Review Terraform error logs

3. **Kubernetes Deployment Fails**:
   - Check kubeconfig configuration
   - Verify EKS cluster status
   - Review pod logs: `kubectl logs <pod-name>`

4. **Jenkins Pipeline Fails**:
   - Check webhook configuration
   - Verify credentials setup
   - Review Jenkins console output

5. **Monitoring Issues**:
   - Check monitoring namespace: `kubectl get pods -n monitoring`
   - Verify service endpoints
   - Review Prometheus targets

### Useful Commands

```bash
# Kubernetes
kubectl get pods -o wide
kubectl get services
kubectl get deployment
kubectl logs <pod-name>
kubectl describe pod <pod-name>

# Docker
docker ps
docker logs <container-id>
docker inspect <container-id>

# Terraform
terraform plan
terraform apply
terraform destroy
terraform output

# Jenkins
# Check Jenkins logs on EC2
ssh -i your-key.pem ec2-user@<jenkins-ip>
sudo tail -f /var/log/jenkins/jenkins.log
```

## 🧪 Testing

### Local Testing
```bash
# Test application locally
cd dist
http-server -p 3000

# Test Docker container
docker build -t trend-test .
docker run -d -p 8080:80 trend-test
curl http://localhost:8080
```

### Integration Testing
```bash
# Test Kubernetes deployment
kubectl port-forward service/trend-app-service 8080:80
curl http://localhost:8080

# Test monitoring
kubectl port-forward service/prometheus-service 9090:9090 -n monitoring
curl http://localhost:9090/targets
```

## 📈 Scaling

### Horizontal Pod Autoscaling
```bash
# Create HPA for the application
kubectl autoscale deployment trend-app --cpu-percent=50 --min=1 --max=10
kubectl get hpa
```

### Cluster Scaling
Update `terraform/main.tf` to modify EKS node group size:
```hcl
scaling_config {
  desired_size = 3  # Increase for production
  max_size     = 10
  min_size     = 2
}
```

## 🔐 Security Considerations

1. **IAM Roles**: Principle of least privilege
2. **Network Security**: VPC with private subnets
3. **Secrets Management**: Use Kubernetes secrets for sensitive data
4. **Container Security**: Regular base image updates
5. **HTTPS**: Configure SSL/TLS for production

## 💰 Cost Optimization

1. **Use Spot Instances** for EKS worker nodes
2. **Enable Auto-scaling** to match demand
3. **Monitor Resource Usage** and right-size instances
4. **Clean up unused resources** regularly

## 📝 Maintenance

### Regular Tasks
- Update container images
- Monitor cluster health
- Backup Jenkins configuration
- Review and update IAM policies
- Apply security patches

### Backup Procedures
```bash
# Backup Jenkins configuration
scp -i your-key.pem ec2-user@<jenkins-ip>:/var/lib/jenkins/config.xml .

# Backup Terraform state
cp terraform/terraform.tfstate terraform/terraform.tfstate.backup
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For issues and questions:
- Create an issue in the GitHub repository
- Check Jenkins logs for pipeline failures
- Review Kubernetes events for deployment issues
- Monitor Grafana dashboards for application health

---

**Note**: This setup is for demonstration purposes. For production use, ensure you:
- Use proper domain names and SSL certificates
- Implement robust backup strategies
- Set up comprehensive logging and monitoring
- Follow security best practices
- Configure proper disaster recovery procedures
