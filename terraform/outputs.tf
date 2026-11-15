output "vpc_id" {
  description = "Existing default VPC"
  value       = data.aws_vpc.default.id
}

output "subnet_id" {
  description = "Selected subnet"
  value       = data.aws_subnet.selected.id
}

output "availability_zone" {
  description = "Selected availability zone"
  value       = data.aws_subnet.selected.availability_zone
}


output "security_group_id" {
  description = "Application security group"
  value       = aws_security_group.application_sg.id
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.application_server.id
}

output "public_ip" {
  description = "Public IPv4 address"
  value       = aws_instance.application_server.public_ip
}

output "application_url" {
  description = "Application URL"
  value       = "http://${aws_instance.application_server.public_ip}"
}