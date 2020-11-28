provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = "ap-northeast-1"
  version    = ">=2.41.0"
}

terraform {
  required_version = ">=0.12.0"
  backend "s3" {
    region  = "ap-northeast-1"
    bucket  = "kou-terraform-aws-eks"
    key     = "terraform.tfstate.aws.terraform-aws-ecs"
    encrypt = true
  }
}
