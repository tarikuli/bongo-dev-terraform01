# The ALB's own firewall: accepts HTTP from anywhere (it's the public front
# door), and — like every security group — allows all outbound traffic so
# it can forward requests on to the instances.
resource "aws_security_group" "alb" {
  name        = "bongo-dev-alb-sg"
  description = "Allow HTTP from anywhere; forwards to EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bongo-dev-alb-sg"
  }
}

# The Application Load Balancer itself. It's "internal = false" (internet-
# facing) and spans both public subnets so it keeps working even if one AZ
# has an outage.
resource "aws_lb" "web" {
  name               = "bongo-dev-web-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "bongo-dev-web-alb"
  }
}

# A target group is the list of "backends" the ALB forwards traffic to — in
# this case, whichever EC2 instances the Auto Scaling Group registers here.
# The ALB uses this group's health check to decide which targets are
# actually healthy enough to receive traffic.
resource "aws_lb_target_group" "web" {
  name     = "bongo-dev-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30 # seconds between health checks
    timeout             = 5  # seconds to wait for a response
    healthy_threshold   = 2  # consecutive successes before marking healthy
    unhealthy_threshold = 2  # consecutive failures before marking unhealthy
  }

  tags = {
    Name = "bongo-dev-web-tg"
  }
}

# A listener tells the ALB what to do with incoming connections on a given
# port — here, forward everything on port 80 to the target group above.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
