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
  description = "Allow SSH from my IP and HTTP from anywhere"
  vpc_id      = var.vpc_id

  # Inbound rules ("ingress") control what's allowed to reach the instance.
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr] # restricted to your IP, not the whole internet
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # a public website needs to accept traffic from anyone
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

# The actual virtual machine. It boots from the AMI looked up above, lives
# in the given subnet, is protected by the security group, and runs
# user_data.sh on first boot.
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = var.key_name                        # SSH key pair; null = launch without one
  user_data              = file("${path.module}/user_data.sh") # script run once on first boot

  # The root volume is the disk the OS boots from.
  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3" # current-generation SSD; cheaper and faster than the older gp2
  }

  tags = {
    Name = "bongo-dev-web"
  }
}
