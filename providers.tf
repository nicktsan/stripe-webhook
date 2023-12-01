terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.76.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "hcp" {
  # Configuration options
}

# provider "stripe" {
#   # Configuration options. You can provide your api-key through the STRIPE_API_KEY environment variable.
#   # Console Command Example: export STRIPE_API_KEY="<api-key>"
# }
