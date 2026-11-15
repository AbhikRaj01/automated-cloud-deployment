terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Discover existing default VPC
data "aws_vpc" "default" {
  default = true
}

# Discover existing subnet
data "aws_subnet" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = [var.availability_zone]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Retrieve the official Ubuntu 24.04 AMI
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# Security group
resource "aws_security_group" "application_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for cloud application deployment"
  vpc_id      = data.aws_vpc.default.id

  # SSH access restricted to administrator IP
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  # HTTP access
  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound connectivity
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

# EC2 application server
resource "aws_instance" "application_server" {
  ami                  = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.application_profile.name

  credit_specification {
    cpu_credits = "standard"
  }

  subnet_id                   = data.aws_subnet.selected.id
  vpc_security_group_ids      = [aws_security_group.application_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  # Use standard EC2 monitoring, not paid detailed monitoring
  monitoring = false

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name        = "${var.project_name}-server"
    Project     = var.project_name
    Environment = "Development"
  }
}

# CloudWatch CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name        = "${var.project_name}-high-cpu"
  alarm_description = "Triggers when EC2 CPU utilization exceeds 70% for 10 minutes"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.application_server.id
  }

  tags = {
    Name    = "${var.project_name}-cpu-alarm"
    Project = var.project_name
  }
}


# IAM Role for EC2 CloudWatch Access
resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "${var.project_name}-ec2-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = var.project_name
  }
}

# Least-privilege CloudWatch read policy
resource "aws_iam_policy" "cloudwatch_read_policy" {
  name        = "${var.project_name}-cloudwatch-read"
  description = "Allow EC2 dashboard to read CloudWatch metrics and alarms"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:DescribeAlarms"
      ]
      Resource = "*"
    }]
  })
}

# Attach policy to IAM role
resource "aws_iam_role_policy_attachment" "cloudwatch_read_attachment" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = aws_iam_policy.cloudwatch_read_policy.arn
}

# Instance profile connects the role to EC2
resource "aws_iam_instance_profile" "application_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2_cloudwatch_role.name
}
