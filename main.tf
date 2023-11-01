terraform {
  backend "s3" {
    bucket  = "holidaygifts-2023"
    key     = "luit/project19"
    region  = "us-east-1"
    profile = "enteryourprofile"
    encrypt = true
  }
}

provider "aws" {
  region  = var.region
  profile = "enteryourprofile"
}

resource "aws_vpc" "holidaygifts_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "HolidayGifts VPC"
  }
}

resource "aws_internet_gateway" "holidaygifts_igw" {
  vpc_id = aws_vpc.holidaygifts_vpc.id

  tags = {
    Name = "HolidayGifts IGW"
  }
}

resource "aws_route" "holidaygifts_igw_route" {
  route_table_id         = aws_vpc.holidaygifts_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.holidaygifts_igw.id
}

resource "aws_subnet" "holidaygifts_subnet" {
  count                   = length(var.subnet_cidr)
  vpc_id                  = aws_vpc.holidaygifts_vpc.id
  cidr_block              = var.subnet_cidr[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "HolidayGifts Subnet ${count.index + 1}"
  }
}

resource "aws_security_group" "holidaygifts_sg" {
  vpc_id = aws_vpc.holidaygifts_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "HolidayGifts SG"
  }
}

# Generate a new private key
resource "tls_private_key" "holidaygifts_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create an AWS key pair using the generated public key
resource "aws_key_pair" "holidaygifts_key" {
  key_name   = "holidaygifts-prod"
  public_key = tls_private_key.holidaygifts_key.public_key_openssh
}

# Save the private key locally for SSH access
resource "local_file" "holidaygifts_private_key" {
  content  = tls_private_key.holidaygifts_key.private_key_pem
  filename = "${path.module}/holidaygifts-prod.pem"

  provisioner "local-exec" {
    command = "chmod 400 ${path.module}/holidaygifts-prod.pem"
  }
}

resource "aws_launch_configuration" "holidaygifts_lc" {
  name          = "holidaygifts-launch-config"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  security_groups = [aws_security_group.holidaygifts_sg.id]

  user_data = file(var.holidaygifts_user_data_file)

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_key_pair.holidaygifts_key]
}

resource "aws_autoscaling_group" "holidaygifts_asg" {
  launch_configuration = aws_launch_configuration.holidaygifts_lc.name
  min_size             = 2
  max_size             = 5
  desired_capacity     = 2

  vpc_zone_identifier = aws_subnet.holidaygifts_subnet.*.id

  tag {
    key                 = "HolidayGifts-ASG"
    value               = "true"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "holidaygifts_alb_sg" {
  vpc_id = aws_vpc.holidaygifts_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "HolidayGifts ALB SG"
  }
}

resource "aws_security_group_rule" "from_alb_to_asg" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.holidaygifts_sg.id
  source_security_group_id = aws_security_group.holidaygifts_alb_sg.id
}

resource "aws_lb" "holidaygifts_alb" {
  name               = "holidaygifts-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.holidaygifts_alb_sg.id]
  subnets            = aws_subnet.holidaygifts_subnet.*.id

  enable_deletion_protection = false

  enable_http2 = true

  tags = {
    Name = "HolidayGifts ALB"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.holidaygifts_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_end.arn
  }
}

resource "aws_lb_target_group" "front_end" {
  name     = "front-end-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.holidaygifts_vpc.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.holidaygifts_asg.name
  lb_target_group_arn    = aws_lb_target_group.front_end.arn
}

