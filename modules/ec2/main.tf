# A `data` source reads existing information from AWS instead of creating
# something new. Here, instead of hardcoding an AMI ID (which changes every
# time Amazon patches the image), we ask AWS for the latest one that matches
# our filters and use its ID below.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true       # if multiple AMIs match, pick the newest
  owners      = ["amazon"] # only trust images published by Amazon itself

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"] # Amazon Linux 2023, 64-bit x86
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"] # hardware virtual machine — the standard type on EC2 today
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"] # boots from an EBS volume (vs. old instance-store AMIs)
  }
}

# A security group is a virtual firewall attached to the instance (not the
# subnet). Rules here are allow-only — anything not explicitly allowed is
# denied by default.
resource "aws_security_group" "web" {
  name        = "bongo-dev-web-sg"
  description = "Allow SSH from my IP; HTTP only from the ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr] # restricted to your IP, not the whole internet
  }

  # Instead of a CIDR block, this references another security group — only
  # traffic actually coming from something in the ALB's security group is
  # allowed. Instances are no longer reachable directly from the internet;
  # every request has to go through the ALB first.
  ingress {
    description     = "HTTP from the ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  # Outbound rules ("egress") control what the instance is allowed to reach.
  # This allows all outbound traffic, which is the common default (e.g. so
  # the instance can reach package repositories to install nginx).
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # "-1" means "all protocols"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bongo-dev-web-sg"
  }
}

# A launch template is the "blueprint" the Auto Scaling Group uses every
# time it launches a new instance — it replaces a standalone aws_instance
# once instances can be created/destroyed automatically by the ASG.
resource "aws_launch_template" "web" {
  name_prefix   = "bongo-dev-web-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  key_name      = var.key_name # SSH key pair; null = launch without one

  vpc_security_group_ids = [aws_security_group.web.id]

  # The root volume is the disk the OS boots from. root_device_name comes
  # from the AMI itself rather than being hardcoded, since it can differ
  # between AMIs.
  block_device_mappings {
    device_name = data.aws_ami.amazon_linux_2023.root_device_name

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3" # current-generation SSD; cheaper and faster than the older gp2
      delete_on_termination = true
    }
  }

  # user_data must be base64-encoded for a launch template (aws_instance
  # handles that encoding for you automatically; aws_launch_template does not).
  user_data = base64encode(file("${path.module}/user_data.sh"))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "bongo-dev-web"
    }
  }

  # Launch templates are versioned and often referenced elsewhere (like the
  # ASG below) — creating a new version before destroying the old one avoids
  # a brief window with no valid template for the ASG to launch from.
  lifecycle {
    create_before_destroy = true
  }
}

# The Auto Scaling Group (ASG) keeps a target number of instances running,
# launching new ones from the template above and terminating unhealthy
# ones, spread across the given subnets (one per AZ) for high availability.
resource "aws_autoscaling_group" "web" {
  name                = "bongo-dev-web-asg"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity

  # "ELB" means the ASG trusts the ALB's target group health checks (not
  # just "is the instance running") to decide if an instance is healthy —
  # so a running instance that's failing '/' still gets replaced.
  health_check_type         = "ELB"
  health_check_grace_period = 300 # seconds to let a new instance boot nginx before checking it

  target_group_arns = [var.target_group_arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  # Unlike a plain resource's `tags = {}`, an ASG's `tag` blocks need
  # propagate_at_launch to pass the tag down to each instance it creates.
  tag {
    key                 = "Name"
    value               = "bongo-dev-web"
    propagate_at_launch = true
  }
}
