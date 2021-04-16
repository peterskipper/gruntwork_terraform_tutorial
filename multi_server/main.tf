provider "aws" {
  region = "us-east-2"
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
}

/*
resource "aws_instance" "gruntwork_example" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  tags = {
    Name = "gruntwork_example"
  }

  vpc_security_group_ids = [aws_security_group.sec_grp.id]
}
*/

resource "aws_launch_configuration" "gruntwork_example" {
  image_id        = "ami-0c55b159cbfafe1f0"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.sec_grp.id]
  user_data       = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "gruntwork_example" {
  launch_configuration = aws_launch_configuration.gruntwork_example.id
  availability_zones   = data.aws_availability_zones.all.names

  min_size = 2
  max_size = 10

  load_balancers    = [aws_elb.gruntwork_example.name]
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = "gruntwork_asg_example"
    propagate_at_launch = true
  }
}

# lists all AZs for this account
data "aws_availability_zones" "all" {}

resource "aws_elb" "gruntwork_example" {
  name               = "gruntwork-example"
  availability_zones = data.aws_availability_zones.all.names
  security_groups    = [aws_security_group.elb_sec_grp.id]

  health_check {
    target              = "HTTP:${var.server_port}/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # This adds a listener for incoming HTTP requests
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }
}

resource "aws_security_group" "sec_grp" {
  name = "gruntwork_example_sec_grp"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "elb_sec_grp" {
  name = "gruntwork_example_elb_sec_grp"

  # Allow all outbound (for health checks from elb to asg)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

/*
output "public_ip" {
  value       = aws_instance.gruntwork_example.public_ip
  description = "The public IP of the Web Server"
}
*/

output "clb_dns_name" {
  value       = aws_elb.gruntwork_example.dns_name
  description = "The domain name of the load balancer"
}
