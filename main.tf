# The root module doesn't create any AWS resources directly — it just wires
# together two reusable child modules and passes the values each one needs.
# A `module` block is like calling a function: `source` says where the
# module's code lives, and every other argument fills in one of that
# module's variables.

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
}

module "ec2" {
  source = "./modules/ec2"

  # Values coming from the vpc module's outputs (module.<name>.<output>) —
  # this dependency is also what tells Terraform to create the VPC and
  # subnets before the instance and security group.
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_id

  instance_type    = var.instance_type
  root_volume_size = var.root_volume_size
  my_ip_cidr       = var.my_ip_cidr
  key_name         = var.key_name
}
