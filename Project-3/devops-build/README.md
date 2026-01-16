# DevOps React Application Deployment

This repository contains a React application with complete DevOps deployment setup including Docker, Jenkins, AWS, and monitoring.

## Project Structure

```
├── build/                  # React production build
├── monitoring/             # Monitoring configuration
│   ├── docker-compose.yml
│   ├── prometheus.yml
│   ├── alertmanager.yml
│   └── alert_rules.yml
├── aws/                    # AWS deployment scripts
│   ├── deploy-ec2.sh
│   └── cleanup.sh
├── Dockerfile
├── docker-compose.yml
├── nginx.conf
├── build.sh
├── deploy.sh
├── Jenkinsfile
├── .dockerignore
├── .gitignore
└── package.json
```

## Quick Start

### 1. Local Development

```bash
# Build and run with Docker Compose
docker-compose up -d

# Access the application
http://localhost:80

# Health check
http://localhost:80/health

# Metrics
http://localhost:80/metrics
```

### 2. Build Docker Image

```bash
# Make scripts executable
chmod +x build.sh deploy.sh

# Build for dev environment
./build.sh dev

# Build for production
./build.sh master
```

### 3. Deploy to Server

```bash
# Deploy to dev server
./deploy.sh dev <server-ip>

# Deploy to production
./deploy.sh prod <server-ip>
```

## Docker Configuration

### Dockerfile
- Multi-stage build using nginx:alpine
- Serves React application on port 80
- Includes health check and metrics endpoints

### Docker Compose
- Single service configuration
- Port mapping 80:80
- Automatic restart policy

## Monitoring Setup

### Prometheus & Grafana

```bash
cd monitoring

# Start monitoring stack
docker-compose up -d

# Access Grafana (admin/admin)
http://localhost:3001

# Access Prometheus
http://localhost:9090

# Access AlertManager
http://localhost:9093
```

### Health Checks

- **Application Health**: `GET /health`
- **Metrics**: `GET /metrics`
- **Application**: `GET /` (React app)

### Alert Rules

- Application down detection
- High CPU usage (>80%)
- High memory usage (>85%)
- Low disk space (>90%)

## AWS Deployment

### Prerequisites

- AWS CLI configured
- IAM permissions for EC2 operations
- Docker Hub account

### Deploy to EC2

```bash
cd aws

# Deploy development environment
./deploy-ec2.sh dev

# Deploy production environment
./deploy-ec2.sh prod
```

### Security Configuration

- **HTTP Access**: Open to all IPs (0.0.0.0/0)
- **SSH Access**: Restricted to your current IP only
- **Instance Type**: t2.micro
- **Region**: us-east-1

### Cleanup

```bash
# Clean up all resources
./cleanup.sh dev    # or prod
```

## Jenkins CI/CD

### Pipeline Configuration

The `Jenkinsfile` includes:

1. **Checkout**: Pull source code
2. **Build**: Create Docker image with appropriate tag
3. **Push**: Deploy to Docker Hub (dev/prod repositories)
4. **Deploy**: Automatic deployment to target servers

### Branch Strategy

- **dev branch** → `dev` Docker Hub repo → Development server (port 8080)
- **master/main branch** → `prod` Docker Hub repo → Production server (port 80)

### Jenkins Setup

1. Install Jenkins
2. Configure Docker Hub credentials
3. Create pipeline job with GitHub webhook
4. Set up auto-trigger on push events

## Docker Hub Repositories

### Required Repositories

1. **dev** (Public): `your-username/dev`
   - Tags: `dev-latest`, `feature-branch-name`
   
2. **prod** (Private): `your-username/prod`
   - Tags: `prod-latest`

### Update Scripts

Replace `your-dockerhub-username` in:
- `build.sh`
- `deploy.sh`
- `Jenkinsfile`
- `aws/deploy-ec2.sh`

## Environment Variables

### Application
- `NODE_ENV`: production
- `PORT`: 80 (default)

### Monitoring
- `GF_SECURITY_ADMIN_PASSWORD`: admin (Grafana)

## File Exclusions

### .dockerignore
Excludes source files, documentation, and development files from Docker build context.

### .gitignore
Excludes build artifacts, dependencies, and sensitive configuration.

## Health Monitoring

### Endpoints

```bash
# Application health
curl http://localhost:80/health

# Application metrics
curl http://localhost:80/metrics

# Prometheus metrics
curl http://localhost:9090/metrics
```

### Alert Configuration

Email notifications are configured in `monitoring/alertmanager.yml`. Update with your SMTP settings.

## Troubleshooting

### Common Issues

1. **Port conflicts**: Ensure ports 80, 3001, 9090, 9093 are available
2. **Docker permissions**: Add user to docker group
3. **AWS permissions**: Verify IAM policies
4. **Jenkins credentials**: Ensure Docker Hub credentials are correctly configured

### Logs

```bash
# Docker container logs
docker logs devops-react-app

# Monitoring stack logs
cd monitoring && docker-compose logs -f

# Jenkins logs
# Check Jenkins UI for pipeline logs
```

## Security Considerations

- SSH access restricted to your IP
- Production Docker repository is private
- Environment variables for sensitive data
- Regular security updates for base images

## Performance Optimization

- Nginx serves static files efficiently
- Docker multi-stage build reduces image size
- Health checks prevent serving broken applications
- Monitoring alerts for resource usage

## Backup and Recovery

- Docker images stored in Docker Hub
- Infrastructure as code (scripts)
- Configuration files in version control
- Monitoring data persistence via Docker volumes

## Submission Requirements

### GitHub Repository
- URL: `https://github.com/Mohan6201/guvi_tasks/tree/dev`
- Branch: `dev`

### Docker Images
- Dev: `your-username/dev:dev-latest`
- Prod: `your-username/prod:prod-latest`

### Screenshots Required
1. Jenkins (login page, configuration, build steps)
2. AWS (EC2 console, Security Group config)
3. Docker Hub (repositories with image tags)
4. Deployed application
5. Monitoring health status

### Deployed Site URL
- Development: `http://dev-server-ip:8080`
- Production: `http://prod-server-ip:80`

## Support

For issues or questions:
1. Check logs in respective services
2. Verify configuration files
3. Ensure all prerequisites are met
4. Review AWS and Docker Hub permissions
