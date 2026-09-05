# Child modules declare which providers they need but never configure them
# (no `provider` block) — the root module owns provider configuration.
# This module additionally needs the `random` provider for the master
# password, on top of `aws`.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
