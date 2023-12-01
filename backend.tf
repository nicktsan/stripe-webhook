terraform {
  //This backend was already created in a different project: https://github.com/nicktsan/aws_backend
  backend "s3" {
    bucket               = "movies-terraform-backend"
    key                  = "terraform.tfstate"
    region               = "us-east-1"
    workspace_key_prefix = "stripe_webhook"
    dynamodb_table       = "movies-db-backend"
    encrypt              = true
  }
}
