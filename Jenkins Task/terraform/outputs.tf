output "instance_public_ip" {
  description = "Public IP of the Jenkins server"
  value       = aws_instance.jenkins_server.public_ip
}

output "jenkins_url" {
  description = "URL to access the Jenkins web UI"
  value       = "http://${aws_instance.jenkins_server.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH command to connect to the Jenkins server"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.jenkins_server.public_ip}"
}
