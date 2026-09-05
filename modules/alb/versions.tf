# Child modules declare which providers they need but never configure them
# (no `provider` block) — the root module owns provider configuration
# (region, credentials) and passes it down automatically.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
