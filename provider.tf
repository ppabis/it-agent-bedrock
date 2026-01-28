terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.68.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}