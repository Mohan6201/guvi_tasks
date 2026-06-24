output "instance_region_1_id" {
  description = "Instance ID in region 1"
  value       = aws_instance.ec2_region_1.id
}

output "instance_region_1_public_ip" {
  description = "Public IP of the EC2 instance in region 1"
  value       = aws_instance.ec2_region_1.public_ip
}

output "instance_region_2_id" {
  description = "Instance ID in region 2"
  value       = aws_instance.ec2_region_2.id
}

output "instance_region_2_public_ip" {
  description = "Public IP of the EC2 instance in region 2"
  value       = aws_instance.ec2_region_2.public_ip
}

output "ssh_region_1" {
  description = "SSH command for region 1 instance"
  value       = "ssh -i ~/.ssh/${var.key_name_region_1}.pem ec2-user@${aws_instance.ec2_region_1.public_ip}"
}

output "ssh_region_2" {
  description = "SSH command for region 2 instance"
  value       = "ssh -i ~/.ssh/${var.key_name_region_2}.pem ec2-user@${aws_instance.ec2_region_2.public_ip}"
}
