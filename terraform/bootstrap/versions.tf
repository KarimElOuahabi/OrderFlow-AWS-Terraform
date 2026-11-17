terraform {
  # Same minimum as the other stacks: the S3 backend's use_lockfile needs Terraform 1.10 or later.
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      "Project"   = var.project_name
      "ManagedBy" = "terraform"
      "Stack"     = "bootstrap"
    }
  }
}
