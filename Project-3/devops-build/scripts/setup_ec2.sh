#!/bin/bash
set -e

apt-get update -y
apt-get install -y curl gnupg fontconfig

# -------------------------------------------------------------------
# Docker
# -------------------------------------------------------------------

curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# -------------------------------------------------------------------
# Java 17 + Jenkins
# -------------------------------------------------------------------

apt-get install -y openjdk-17-jre

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" \
  | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update -y
apt-get install -y jenkins

# Allow Jenkins user to run Docker commands
usermod -aG docker jenkins

systemctl enable jenkins
systemctl start jenkins

# -------------------------------------------------------------------
# Helper to retrieve Jenkins initial admin password
# -------------------------------------------------------------------

cat > /home/ubuntu/get_jenkins_password.sh <<'EOF'
#!/bin/bash
echo "Jenkins Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
EOF

chmod +x /home/ubuntu/get_jenkins_password.sh
chown ubuntu:ubuntu /home/ubuntu/get_jenkins_password.sh
