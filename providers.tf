# The `terraform` block configures Terraform itself: the minimum CLI version
# and which "providers" (plugins that talk to a cloud API) this project needs.
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws" # where to download the provider from (Terraform Registry)
      version = "~> 5.0"        # "~> 5.0" means "any 5.x version, but not 6.0"
    }
    random = {
      source  = "hashicorp/random" # used by modules/rds to generate the master password
      version = "~> 3.6"
    }
  }
}

# The `provider` block configures the AWS provider itself — in this case, just
# which region it should create resources in. Credentials are picked up
# automatically from your environment (e.g. `aws configure` / env vars), so
# they don't need to be written here.
provider "aws" {
  region = var.aws_region
}
