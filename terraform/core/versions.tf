terraform {
  # The S3 backend's use_lockfile needs Terraform 1.10 or later.
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    key          = "core/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      "Project"   = var.project_name
      "ManagedBy" = "terraform"
      "Stack"     = "core"
    }
  }
}
