variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Selected availability zone"
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  description = "Project identifier"
  type        = string
  default     = "automated-cloud-deployment"
}

variable "key_name" {
  description = "Existing AWS EC2 key pair"
  type        = string
  default     = "Static-Web-Server"
}

variable "admin_cidr" {
  description = "Public IP allowed to access SSH"
  type        = string
  default     = "106.192.164.134/32"
}