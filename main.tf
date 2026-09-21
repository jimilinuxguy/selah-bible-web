terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ACM certificates used by CloudFront MUST be in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

locals {
  domain_name = "bible.jimisanchez.com"
}

# ------------------------------------------------------------
# Route 53 hosted zone
# Assumes jimisanchez.com already exists in Route 53.
# ------------------------------------------------------------

data "aws_route53_zone" "main" {
  name         = "jimisanchez.com"
  private_zone = false
}

# ------------------------------------------------------------
# S3 bucket
# ------------------------------------------------------------

resource "aws_s3_bucket" "spa" {
  bucket = local.domain_name

  tags = {
    Name        = local.domain_name
    Application = "Bible SPA"
  }
}

resource "aws_s3_bucket_public_access_block" "spa" {
  bucket = aws_s3_bucket.spa.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "spa" {
  bucket = aws_s3_bucket.spa.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# ------------------------------------------------------------
# Upload index.html
# Assumes index.html is in the same directory as Terraform.
# ------------------------------------------------------------

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.spa.id
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"

  # Forces Terraform to update the object when index.html changes.
  etag = filemd5("${path.module}/index.html")
}

# ------------------------------------------------------------
# ACM certificate
# CloudFront requires this in us-east-1.
# ------------------------------------------------------------

resource "aws_acm_certificate" "spa" {
  provider = aws.us_east_1

  domain_name       = local.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.spa.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "spa" {
  provider = aws.us_east_1

  certificate_arn = aws_acm_certificate.spa.arn

  validation_record_fqdns = [
    for record in aws_route53_record.certificate_validation :
    record.fqdn
  ]
}

# ------------------------------------------------------------
# CloudFront Origin Access Control
# ------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "spa" {
  name                              = "${local.domain_name}-oac"
  description                       = "OAC for ${local.domain_name}"
  origin_access_control_origin_type = "s3"

  signing_behavior = "always"
  signing_protocol = "sigv4"
}

# ------------------------------------------------------------
# CloudFront distribution
# ------------------------------------------------------------

resource "aws_cloudfront_distribution" "spa" {

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = [
    local.domain_name
  ]

  origin {
    domain_name              = aws_s3_bucket.spa.bucket_regional_domain_name
    origin_id                = "s3-${local.domain_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.spa.id
  }

  default_cache_behavior {
    target_origin_id = "s3-${local.domain_name}"

    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    compress = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 86400
  }

  # ----------------------------------------------------------
  # SPA fallback
  #
  # If CloudFront/S3 receives:
  #
  # /john/3/16
  #
  # S3 won't actually have an object with that name.
  # Return index.html instead and let your SPA handle the route.
  # ----------------------------------------------------------

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.spa.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [
    aws_acm_certificate_validation.spa
  ]

  tags = {
    Name        = local.domain_name
    Application = "Bible SPA"
  }
}

# ------------------------------------------------------------
# S3 bucket policy
#
# Only this specific CloudFront distribution can read objects.
# ------------------------------------------------------------

data "aws_iam_policy_document" "spa" {

  statement {
    sid = "AllowCloudFrontServicePrincipalReadOnly"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.spa.arn}/*"
    ]

    principals {
      type = "Service"

      identifiers = [
        "cloudfront.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"

      values = [
        aws_cloudfront_distribution.spa.arn
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "spa" {
  bucket = aws_s3_bucket.spa.id
  policy = data.aws_iam_policy_document.spa.json
}

# ------------------------------------------------------------
# Route 53
# bible.jimisanchez.com -> CloudFront
# ------------------------------------------------------------

resource "aws_route53_record" "spa_ipv4" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.spa.domain_name
    zone_id                = aws_cloudfront_distribution.spa.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "spa_ipv6" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.spa.domain_name
    zone_id                = aws_cloudfront_distribution.spa.hosted_zone_id
    evaluate_target_health = false
  }
}