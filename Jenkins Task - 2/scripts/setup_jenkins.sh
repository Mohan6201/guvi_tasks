#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Wait for any background apt/dpkg process (unattended-upgrades, apt-daily)
# to release its lock before we touch apt ourselves. On a fresh Ubuntu boot
# these run automatically and race with user_data, causing installs to fail
# with "Could not get lock /var/lib/dpkg/lock-frontend".
# ---------------------------------------------------------------------------
wait_for_apt_lock() {
  while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
        sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
    echo "Waiting for other apt process to release lock..."
    sleep 5
  done
}

wait_for_apt_lock
apt-get update -y
wait_for_apt_lock
apt-get install -y fontconfig curl gnupg

# -------------------------------------------------------------------
# Java 21 (current Jenkins LTS recommends 21 over 17 to avoid
# service startup failures)
# -------------------------------------------------------------------

wait_for_apt_lock
apt-get install -y openjdk-21-jre
java -version

# -------------------------------------------------------------------
# Jenkins (LTS from official apt repo)
# -------------------------------------------------------------------

mkdir -p /etc/apt/keyrings

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
  -o /etc/apt/keyrings/jenkins-keyring.asc

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" \
  | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

wait_for_apt_lock
apt-get update -y
wait_for_apt_lock
apt-get install -y jenkins

# -------------------------------------------------------------------
# Enable and start Jenkins
# -------------------------------------------------------------------

systemctl enable jenkins
systemctl start jenkins

# -------------------------------------------------------------------
# Helper script to retrieve initial admin password
# -------------------------------------------------------------------

cat > /home/ubuntu/get_jenkins_password.sh <<'EOF'
#!/bin/bash
echo "Jenkins Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
EOF

chmod +x /home/ubuntu/get_jenkins_password.sh
chown ubuntu:ubuntu /home/ubuntu/get_jenkins_password.sh

# Marker file so you can confirm setup finished: ls /home/ubuntu/jenkins_setup_done
touch /home/ubuntu/jenkins_setup_done
chown ubuntu:ubuntu /home/ubuntu/jenkins_setup_done
