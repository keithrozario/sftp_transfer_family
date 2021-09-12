data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

## Cloudwatch Log Role

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "main" {
  name               = format("%s%s",var.server_name,"ServerRole")
  description        = "Logging Role for Transfer Family"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "role_policy" {
  statement {
    actions = [
      "logs:DescribeLogStreams",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      format("arn:aws:logs:%s:%s:*", data.aws_region.current.name, data.aws_caller_identity.current.account_id)
    ]
  }
}

resource "aws_iam_role_policy" "main" {
  name   = format("%s%s",var.server_name,"ServerPolicy")
  role   = aws_iam_role.main.name
  policy = data.aws_iam_policy_document.role_policy.json
}

# Transfer Server
resource "aws_transfer_server" "this" {
  endpoint_type = "PUBLIC"
  protocols   = ["SFTP"]
  identity_provider_type = "SERVICE_MANAGED"
  logging_role = aws_iam_role.main.arn
  security_policy_name = "TransferSecurityPolicy-2020-06"
    tags = {
    Name = var.server_name
  }
}


## User
resource "aws_transfer_user" "this" {
  server_id = aws_transfer_server.this.id
  user_name = "sftpUser"
  role      = aws_iam_role.this.arn

  tags = {
    NAME = "sftpUser"
  }

    home_directory_type = "LOGICAL"
    home_directory_mappings {
    entry  = "/"
    target = "/${aws_s3_bucket.this.id}"
  }
}

resource "aws_iam_role" "this" {
  name = format("%s%s",var.server_name,"UserRole")

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "transfer.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "this" {
  name = format("%s%s",var.server_name,"UserPolicy")
  role = aws_iam_role.this.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowListingOfUserFolder",
            "Action": [
                "s3:ListBucket"  
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.this.id}"
            ]
        },
        {
            "Sid": "HomeDirObjectAccess",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:DeleteObjectVersion",
                "s3:GetObjectVersion",
                "s3:GetObjectACL",
                "s3:PutObjectACL"
            ],
            "Resource": "arn:aws:s3:::${aws_s3_bucket.this.id}/*"
        },
        {
            "Sid": "EncryptedBucket",
            "Action": [
              "kms:Decrypt",
              "kms:Encrypt",
              "kms:GenerateDataKey"
            ],
            "Effect": "Allow",
            "Resource": "${var.kms_key_arn}"
        }
    ]
}
POLICY
}

## SSH Key
resource "aws_transfer_ssh_key" "this" {
  server_id = aws_transfer_server.this.id
  user_name = aws_transfer_user.this.user_name
  body      = var.user_public_key
}