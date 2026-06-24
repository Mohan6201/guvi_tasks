#!/bin/bash
set -e

apt-get update -y
apt-get install -y fontconfig curl gnupg

# -------------------------------------------------------------------
# Java 17 (required by Jenkins LTS)
# -------------------------------------------------------------------

apt-get install -y openjdk-17-jre
java -version

# -------------------------------------------------------------------
# Jenkins (LTS from official apt repo)
# -------------------------------------------------------------------

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" \
  | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update -y
apt-get install -y jenkins

# -------------------------------------------------------------------
# Enable and start Jenkins
# -------------------------------------------------------------------

systemctl enable jenkins
systemctl start jenkins

# -------------------------------------------------------------------
# Write initial admin password path to a helper file for easy retrieval
# -------------------------------------------------------------------

cat > /home/ubuntu/get_jenkins_password.sh <<'EOF'
#!/bin/bash
echo "Jenkins Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
EOF

chmod +x /home/ubuntu/get_jenkins_password.sh
chown ubuntu:ubuntu /home/ubuntu/get_jenkins_password.sh
