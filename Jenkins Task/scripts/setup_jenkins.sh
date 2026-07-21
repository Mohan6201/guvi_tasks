#!/bin/bash
set -eo pipefail

apt-get update -y
apt-get install -y fontconfig curl gnupg

# -------------------------------------------------------------------
# Java 21 (current Jenkins LTS recommends 21 over 17 to avoid
# service startup failures)
# -------------------------------------------------------------------

apt-get install -y openjdk-21-jre
java -version

# -------------------------------------------------------------------
# Jenkins (LTS from official apt repo)
# -------------------------------------------------------------------

mkdir -p /etc/apt/keyrings

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
  | tee /etc/apt/keyrings/jenkins-keyring.asc > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
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
