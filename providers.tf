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
