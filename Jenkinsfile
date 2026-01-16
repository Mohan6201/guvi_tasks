pipeline {
    agent any
    
    environment {
        DOCKERHUB_USERNAME = credentials('dockerhub-username')
        DOCKERHUB_PASSWORD = credentials('dockerhub-password')
        APP_NAME = 'devops-react-app'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    def branchName = env.BRANCH_NAME
                    def tag = ""
                    def repo = ""
                    
                    if (branchName == 'dev') {
                        tag = 'dev-latest'
                        repo = "${DOCKERHUB_USERNAME}/dev"
                    } else if (branchName == 'master' || branchName == 'main') {
                        tag = 'prod-latest'
                        repo = "${DOCKERHUB_USERNAME}/prod"
                    } else {
                        tag = "feature-${branchName}"
                        repo = "${DOCKERHUB_USERNAME}/dev"
                    }
                    
                    // Build the Docker image
                    sh "docker build -t ${APP_NAME}:${tag} ."
                    
                    // Tag for Docker Hub
                    sh "docker tag ${APP_NAME}:${tag} ${repo}:${tag}"
                    
                    // Store for later stages
                    env.IMAGE_TAG = tag
                    env.REPO_NAME = repo
                }
            }
        }
        
        stage('Login to Docker Hub') {
            steps {
                script {
                    sh "echo ${DOCKERHUB_PASSWORD} | docker login -u ${DOCKERHUB_USERNAME} --password-stdin"
                }
            }
        }
        
        stage('Push to Docker Hub') {
            steps {
                script {
                    sh "docker push ${REPO_NAME}:${IMAGE_TAG}"
                }
            }
        }
        
        stage('Deploy to Server') {
            when {
                anyOf {
                    branch 'dev'
                    branch 'master'
                    branch 'main'
                }
            }
            steps {
                script {
                    def serverIP = ""
                    def port = ""
                    
                    if (env.BRANCH_NAME == 'dev') {
                        serverIP = 'your-dev-server-ip'  // Replace with actual dev server IP
                        port = '8080'
                    } else {
                        serverIP = 'your-prod-server-ip'  // Replace with actual prod server IP
                        port = '80'
                    }
                    
                    // Deploy script will be executed on the target server
                    // This assumes SSH access is configured
                    sh """
                        ssh user@${serverIP} "
                            docker pull ${REPO_NAME}:${IMAGE_TAG}
                            docker stop devops-react-app-${env.BRANCH_NAME} || true
                            docker rm devops-react-app-${env.BRANCH_NAME} || true
                            docker run -d \\
                                --name devops-react-app-${env.BRANCH_NAME} \\
                                --restart unless-stopped \\
                                -p ${port}:80 \\
                                -e NODE_ENV=production \\
                                ${REPO_NAME}:${IMAGE_TAG}
                        "
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully!'
            echo "Image pushed to: ${REPO_NAME}:${IMAGE_TAG}"
        }
        failure {
            echo 'Pipeline failed!'
            mail to: 'your-email@example.com',
                 subject: "Pipeline Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                 body: "The pipeline failed for branch ${env.BRANCH_NAME}. Check the logs for details."
        }
        always {
            // Clean up workspace
            cleanWs()
            // Logout from Docker Hub
            sh 'docker logout || true'
        }
    }
}
