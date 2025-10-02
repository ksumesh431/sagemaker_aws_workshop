terraform {
  required_version = ">= 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.14"
    }
  }

  backend "s3" {
    bucket       = "tf-statefile-bucket-aws-sagemaker-workshop" # Replace with your S3 bucket name
    key          = "sagemaker-workshop/terraform.tfstate"
    region       = "us-east-1" # Replace with your bucket's region
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}
