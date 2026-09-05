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

# --- Networking ---
# Everything below builds a minimal, isolated network: one VPC containing a
# "public" subnet (reachable from the internet) and a "private" subnet
# (not reachable from the internet). Only the public subnet is actually used
# by the EC2 instance in this project; the private one is scaffolding for
# future resources (e.g. a database) that shouldn't be internet-facing.

# The VPC (Virtual Private Cloud) is the network boundary everything else
# lives inside — its own private address space, isolated from other VPCs.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # required for internal DNS resolution
  enable_dns_hostnames = true # gives instances a resolvable DNS hostname

  tags = {
    Name = "bongo-dev-vpc"
  }
}

# An Internet Gateway attaches the VPC to the public internet. On its own it
# does nothing — a subnet only becomes "public" once its route table sends
# outbound traffic to this gateway (see aws_route_table.public below).
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "bongo-dev-igw"
  }
}

# Public subnet: instances here can get a public IP and reach the internet
# via the Internet Gateway, once the route table below is associated with it.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true # auto-assign a public IP to instances launched here

  tags = {
    Name = "bongo-dev-public-subnet"
  }
}

# Private subnet: no route to the Internet Gateway, so nothing here is
# directly reachable from (or can directly reach) the internet.
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "bongo-dev-private-subnet"
  }
}

# A route table is a set of rules for where network traffic is allowed to go.
# This one sends all traffic not destined for the VPC (0.0.0.0/0) out through
# the Internet Gateway — that's what makes a subnet "public".
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0" # "everywhere else"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "bongo-dev-public-rt"
  }
}

# A route table does nothing until it's associated with a subnet — this
# association is what actually makes aws_subnet.public "public".
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- Security ---

# A security group is a virtual firewall attached to the instance (not the
# subnet). Rules here are allow-only — anything not explicitly allowed is
# denied by default.
resource "aws_security_group" "web" {
  name        = "bongo-dev-web-sg"
  description = "Allow SSH from my IP and HTTP from anywhere"
  vpc_id      = aws_vpc.main.id

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

# --- Compute ---

# The actual virtual machine. It combines everything above: it boots from
# the AMI we looked up, lives in the public subnet, is protected by the
# security group, and runs user_data.sh on first boot.
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
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
