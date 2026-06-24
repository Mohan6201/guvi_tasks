output "instance_us_east_1" {
  description = "Public IP of the nginx instance in us-east-1"
  value       = aws_instance.nginx_east.public_ip
}

output "instance_us_west_2" {
  description = "Public IP of the nginx instance in us-west-2"
  value       = aws_instance.nginx_west.public_ip
}

output "nginx_url_us_east_1" {
  description = "URL to reach nginx in us-east-1"
  value       = "http://${aws_instance.nginx_east.public_ip}"
}

output "nginx_url_us_west_2" {
  description = "URL to reach nginx in us-west-2"
  value       = "http://${aws_instance.nginx_west.public_ip}"
}
