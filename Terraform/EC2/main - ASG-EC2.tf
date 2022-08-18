#Author : Viswa
#Email  : viswacloud@outlook.com
#This terraform script use ASG - auto-scaling group and prepare two web servers, security group, and place the instances behind the elastic load balancer

#Step 1: Prepare the project
#Create a folder Aircore/EC2 on your computer
#Place the main.tf file in this folder
#Following work is in the main.tf

#Step 2: Require terraform version between 0.12 and 0.14
terraform {
  required_version = ">= 0.12, <= 0.14.8"
}

#Step 3:Declare AWS provider
provider "aws" {
  region = "eu-west-1"
}

#Step 4 :Declare the server_port parameter
variable "server_port" {
  description = "Server port for HTTP requests"
  type        = number
  default     = 8080
}

#Step 5 :Create the AMI to be launched in the ASG
resource "aws_launch_configuration" "example" {
  image_id        = "ami-013f256cced48b350"
  instance_type   = "t2.2xlarge"
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Viswa, EC2 Test" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

  # Required when using a launch configuration with an auto scaling group.
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  lifecycle {
    create_before_destroy = true
  }
}

#Step 6: Prepare the VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

#Step 7: Set up ASG parameters
resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier  = data.aws_subnet_ids.default.ids

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

#Step 8: Create load balancer
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.example.arn
  port              = 443
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

#Step 9: Create a security group for the load balancer
resource "aws_security_group" "alb" {
  name = "terraform-example-alb"

  # Allow inbound HTTP requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Step 10: Create the load balancer
resource "aws_lb_jboss" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default.ids
}

#Step 11: Set up load balancer parameters
resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

#Step 12: In our security group, allow the server port we configured earlier
resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Step 13: Output the load balancer endpoint for our server farm
output "alb_dns_name" {
  value       = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
}

#Step 14: Execute plan
# terraform plan
# terraform apply    

#Step 15: Cleanup
# terraform destroy    