# This module builds a minimal, isolated network: one VPC containing a
# "public" subnet (reachable from the internet) and a "private" subnet
# (not reachable from the internet). Only the public subnet is used by the
# ec2 module today; the private one is scaffolding for future resources
# (e.g. a database) that shouldn't be internet-facing.

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
