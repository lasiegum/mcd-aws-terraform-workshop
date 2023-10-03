resource "aws_s3_bucket" "mcd_s3_bucket" {
  bucket_prefix = "mcd-logs-"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_bucket_encryption" {
  bucket = aws_s3_bucket.mcd_s3_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "mcd_s3_bucket_public_access_block" {
  bucket                  = aws_s3_bucket.mcd_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.mcd_s3_bucket.id
  rule {
    id     = "Delete Objects after 1 days"
    status = "Enabled"
    expiration {
      days = 1
    }
  }
}

data "aws_iam_policy_document" "mcd_s3_bucket_policy_document" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["${aws_s3_bucket.mcd_s3_bucket.arn}"]
    actions   = ["s3:GetBucketAcl"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["${aws_s3_bucket.mcd_s3_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    actions   = ["s3:PutObject"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["${aws_s3_bucket.mcd_s3_bucket.arn}"]
    actions   = ["s3:GetBucketAcl"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
  }
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["${aws_s3_bucket.mcd_s3_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    actions   = ["s3:PutObject"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
  }
}

resource "aws_s3_bucket_policy" "mcd_s3_bucket_policy" {
  bucket     = aws_s3_bucket.mcd_s3_bucket.id
  policy     = data.aws_iam_policy_document.mcd_s3_bucket_policy_document.json
  depends_on = [
    aws_s3_bucket_public_access_block.mcd_s3_bucket_public_access_block
  ]
}

resource "aws_route53_resolver_query_log_config" "mcd_dns_query_log_config" {
  name            = "mcd-dns-query-log-cfg"
  destination_arn = aws_s3_bucket.mcd_s3_bucket.arn
}

resource "aws_cloudtrail" "mcd_cloudtrail" {
  name                          = "mcd-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.mcd_s3_bucket.id
  enable_log_file_validation    = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_logging                = true
  depends_on = [
    aws_s3_bucket_policy.mcd_s3_bucket_policy
  ]
}

resource "aws_s3_bucket_notification" "mcd_s3_bucket_notification" {
  bucket      = aws_s3_bucket.mcd_s3_bucket.id
  queue {
    queue_arn = "arn:aws:sqs:${data.aws_region.current.name}:${var.mcd_controller_aws_account_number}:inventory_logs_queue_${var.mcd_deployment_name}_${data.aws_region.current.name}"
    events    = ["s3:ObjectCreated:*"]
  }
  depends_on  = [
    aws_s3_bucket_policy.mcd_s3_bucket_policy
  ]
}

output "mcd_dns_query_log_config_id" {
  value = aws_route53_resolver_query_log_config.mcd_dns_query_log_config.id
}

output "mcd_s3_bucket" {
  value = {
      arn : aws_s3_bucket.mcd_s3_bucket.arn
      id : aws_s3_bucket.mcd_s3_bucket.id
  }
}