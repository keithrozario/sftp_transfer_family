terraform {
  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "3.41.0"
    }

  }
}

provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_kms_key" "this_key" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 7
}

data "local_file" "pub_key" {
    filename = "transfer-key.pub"
}

data "local_file" "private_key" {
  filename = "transfer-key"
}

resource "aws_ssm_parameter" "sftp_password" {
  name  = "/sftp/sftp_password"
  type  = "SecureString"
  value = data.local_file.private_key.content
}

module "source_server" {
    source = "./sftp_server"
    server_name = "source"
    bucket_prefix = "sftp-source"
    kms_key_arn = aws_kms_key.this_key.arn
    user_public_key = data.local_file.pub_key.content
}

module "destination_server" {
    source = "./sftp_server"
    server_name = "destination"
    bucket_prefix = "sftp-destination"
    kms_key_arn = aws_kms_key.this_key.arn
    user_public_key = data.local_file.pub_key.content
}

resource "aws_s3_bucket" "intermediate_server" {
  bucket_prefix = "intermediate-server"
  force_destroy = true

    versioning {
        enabled = true
    }
    
    lifecycle_rule {
    id      = "10YrRetention"
    enabled = true
    tags = {
      rule      = "log"
      autoclean = "true"
    }

    transition {
      days          = 360
      storage_class = "GLACIER"
    }

    expiration {
      days = 3650
    }
  }

    server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.this_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

}

resource "aws_ssm_parameter" "intermediate_bucket" {
  name  = "/sftp/intermediate_bucket"
  type  = "String"
  value = aws_s3_bucket.intermediate_server.id
}

resource "aws_ssm_parameter" "kms_arn" {
  name  = "/sftp/kms_arn"
  type  = "String"
  value = aws_kms_key.this_key.arn
}

