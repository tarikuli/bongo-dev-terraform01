# This is a separate, standalone Terraform config from the root project.
# It CANNOT use the S3/DynamoDB backend it creates below — Terraform has to
# already know where to store state before it can use a backend, so this
# config's own state stays local (a terraform.tfstate file right here in
# bootstrap/). That's normal and expected for bootstrap configs.
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
