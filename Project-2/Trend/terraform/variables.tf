variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. production, staging)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_version" {
  description = "EKS Kubernetes version (must be a currently AWS-supported version - check with: aws eks describe-cluster-versions)"
  type        = string
  default     = "1.33"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins server"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name for SSH access to Jenkins"
  type        = string
}

variable "jenkins_apt_key_url" {
  description = "Jenkins apt signing key URL. Jenkins rotates this key roughly yearly (filename is year-stamped) and the old one EXPIRES, not just gets superseded - an expired key makes the repo untrusted and 'apt-get install jenkins' fails with no installation candidate. If that happens, check https://www.jenkins.io/doc/book/installing/linux/ for the current key URL and update this default."
  type        = string
  default     = "https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key"
}

variable "jenkins_java_package" {
  description = "JRE package Jenkins requires. Jenkins periodically raises its minimum Java version (e.g. LTS releases have moved from 17 to 21) - if the jenkins service fails to start with 'older than the minimum required version', check https://www.jenkins.io/doc/administration/requirements/java/ and bump this."
  type        = string
  default     = "openjdk-21-jre"
}
