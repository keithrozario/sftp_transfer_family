resource "aws_s3_bucket" "this" {
  bucket_prefix = var.bucket_prefix
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
        kms_master_key_id = var.kms_key_arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

}