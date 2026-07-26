#!/bin/bash
set -e

# EC2 user-data for the JENKINS instance: Docker + Jenkins.
# Jenkins builds/pushes images and SSHes into the separate app instance to deploy them.

apt-get update -y
apt-get install -y curl gnupg fontconfig

# -------------------------------------------------------------------
# Docker (Jenkins needs it to build/push images)
# -------------------------------------------------------------------

curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# -------------------------------------------------------------------
# Java 21 + Jenkins
# -------------------------------------------------------------------

apt-get install -y openjdk-21-jre

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" \
  | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update -y
apt-get install -y jenkins

# jenkins.service is auto-started by the package install above, so the group
# change only takes effect after an explicit restart — `start` on an already
# running unit is a no-op.
usermod -aG docker jenkins
systemctl enable jenkins
systemctl restart jenkins

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
