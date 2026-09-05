# This module builds a network with TWO public subnets and TWO private
# subnets, one of each per availability zone. The public subnets are
# required for the ALB and ASG (both need to spread across AZs for high
# availability); the private subnets aren't reachable from the internet and
# host things like the RDS database, which also requires 2 AZs for its
# DB subnet group even when Multi-AZ failover itself is disabled.

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

# Two public subnets, one per AZ. `count` here creates one aws_subnet per
# entry in availability_zones, indexing into public_subnet_cidrs the same
# way — count.index is 0 then 1.
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # auto-assign a public IP to instances launched here

  tags = {
    Name = "bongo-dev-public-subnet-${count.index + 1}"
  }
}

# Two private subnets, one per AZ — same pattern as the public subnets, but
# with no route to the Internet Gateway, so nothing here is directly
# reachable from (or can directly reach) the internet. RDS requires a DB
# subnet group spanning 2 AZs even with Multi-AZ failover turned off.
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "bongo-dev-private-subnet-${count.index + 1}"
  }
}

# A route table is a set of rules for where network traffic is allowed to go.
# This one sends all traffic not destined for the VPC (0.0.0.0/0) out through
# the Internet Gateway — that's what makes a subnet "public". Both public
# subnets share this single route table.
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
# associates it with both public subnets.
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
