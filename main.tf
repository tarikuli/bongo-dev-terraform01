# The root module doesn't create any AWS resources directly — it just wires
# together three reusable child modules and passes the values each one
# needs. A `module` block is like calling a function: `source` says where
# the module's code lives, and every other argument fills in one of that
# module's variables.

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidr = var.private_subnet_cidr
  availability_zones  = var.availability_zones
}

module "alb" {
  source = "./modules/alb"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  health_check_path = var.health_check_path
}

module "ec2" {
  source = "./modules/ec2"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids

  instance_type    = var.instance_type
  root_volume_size = var.root_volume_size
  my_ip_cidr       = var.my_ip_cidr
  key_name         = var.key_name

  # Values from the alb module — this dependency is also what tells
  # Terraform to create the ALB (and its security group/target group)
  # before the launch template and ASG that reference them.
  alb_security_group_id = module.alb.alb_security_group_id
  target_group_arn      = module.alb.target_group_arn

  asg_min_size         = var.asg_min_size
  asg_max_size         = var.asg_max_size
  asg_desired_capacity = var.asg_desired_capacity
}
