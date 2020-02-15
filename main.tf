resource "aws_s3_bucket" "web" {
  bucket = "watabee-web"
  acl    = "private"

  tags = {
    Name = "Bucket for static web site hosting"
  }
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Static web site hosting"
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.web.arn}/*"]

    principals {
      type = "AWS"
      identifiers = [
      aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }

  statement {
    actions = ["s3:ListBucket"]
    resources = [
    aws_s3_bucket.web.arn]

    principals {
      type = "AWS"
      identifiers = [
      aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.web.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_cloudfront_distribution" "web" {
  origin {
    domain_name = aws_s3_bucket.web.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.web.id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "Static web site hosting"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.web.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  web_acl_id = aws_waf_web_acl.waf_acl.id
}

resource "aws_waf_ipset" "ipset" {
  name = "StaticWebSiteHosting"

  ip_set_descriptors {
    type  = "IPV4"
    value = var.whitelist_ip
  }
}

resource "aws_waf_rule" "wafrule" {
  depends_on  = [aws_waf_ipset.ipset]
  name        = "StaticWebSiteHosting"
  metric_name = "StaticWebSiteHosting"

  predicates {
    data_id = aws_waf_ipset.ipset.id
    negated = false
    type    = "IPMatch"
  }
}

resource "aws_waf_web_acl" "waf_acl" {
  depends_on  = [aws_waf_ipset.ipset, aws_waf_rule.wafrule]
  name        = "StaticWebSiteHosting"
  metric_name = "StaticWebSiteHosting"

  default_action {
    type = "BLOCK"
  }

  rules {
    action {
      type = "ALLOW"
    }

    priority = 1
    rule_id  = aws_waf_rule.wafrule.id
    type     = "REGULAR"
  }
}
