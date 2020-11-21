terraform {
  required_version = ">= 0.12"

  backend "s3" {
    bucket  = "bartosz.tech.terraform"
    key     = "blog/terraform.tfstate"
    region  = "eu-west-2"
    encrypt = true
  }
}

provider "aws" {
  region = "eu-west-2"
}

provider "aws" {
  alias = "aws-us-east-1"
  region = "us-east-1"
}

resource "aws_s3_bucket" "blog" {
  bucket = var.blog_domain
  acl    = "public-read"

  website {
    index_document = "index.html"
  }
}

resource "aws_route53_zone" "blog" {
  name = var.blog_domain
}

resource "aws_acm_certificate" "cert_eu" {
  domain_name       = "${var.blog_domain}."
  validation_method = "DNS"
  subject_alternative_names = [
    "*.${var.blog_domain}",
  ]
}

resource "aws_acm_certificate" "cert" {
  provider = aws.aws-us-east-1
  domain_name       = "${var.blog_domain}."
  validation_method = "DNS"
  subject_alternative_names = [
    "*.${var.blog_domain}",
  ]
}

resource "aws_route53_record" "cert_validation" {
  provider = aws.aws-us-east-1
  name    = aws_acm_certificate.cert.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options[0].resource_record_type
  zone_id = aws_route53_zone.blog.zone_id
  records = [
  aws_acm_certificate.cert.domain_validation_options[0].resource_record_value]
  ttl = 60
}

resource "aws_acm_certificate_validation" "cert" {
  provider = aws.aws-us-east-1
  certificate_arn = aws_acm_certificate.cert.arn
  validation_record_fqdns = [
  aws_route53_record.cert_validation.fqdn]
}

resource "aws_acm_certificate_validation" "cert_eu" {
  certificate_arn = aws_acm_certificate.cert_eu.arn
  validation_record_fqdns = [
  aws_route53_record.cert_validation.fqdn]
}

resource "aws_cloudfront_origin_access_identity" "blog" {
  comment = "service s3 access ${var.blog_domain}"
}

resource "aws_cloudfront_distribution" "blog" {
  origin {
    domain_name = aws_s3_bucket.blog.bucket_domain_name
    origin_id   = "service-s3-${var.blog_domain}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.blog.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = [
    var.blog_domain
  ]

  default_cache_behavior {
    allowed_methods = [
      "DELETE",
      "GET",
      "HEAD",
      "OPTIONS",
      "PATCH",
      "POST",
      "PUT",
    ]

    cached_methods = [
      "GET",
      "HEAD",
    ]

    target_origin_id = "service-s3-${var.blog_domain}"

    forwarded_values {
      query_string = true

      cookies {
        forward = "none"
      }

      headers = ["Access-Control-Request-Headers", "Access-Control-Request-Method", "Origin"]
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    minimum_protocol_version = "TLSv1"
    ssl_support_method       = "sni-only"
  }
}

resource "aws_route53_record" "a" {
  zone_id = aws_route53_zone.blog.zone_id
  name    = var.blog_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.blog.domain_name
    zone_id                = aws_cloudfront_distribution.blog.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "mx" {
  name            = var.blog_domain
  ttl             = 300
  type            = "MX"
  zone_id         = aws_route53_zone.blog.zone_id

  records = [
    "10 in1-smtp.messagingengine.com",
    "20 in2-smtp.messagingengine.com",
  ]
}

resource "aws_route53_record" "txt" {
  name            = var.blog_domain
  ttl             = 300
  type            = "TXT"
  zone_id         = aws_route53_zone.blog.zone_id

  records = [
    "v=spf1 include:spf.messagingengine.com ?all",
  ]
}

resource "aws_route53_record" "cname_1" {
  name            = "fm1._domainkey"
  ttl             = 300
  type            = "CNAME"
  zone_id         = aws_route53_zone.blog.zone_id

  records = [
    "fm1.${var.blog_domain}.dkim.fmhosted.com",
  ]
}

resource "aws_route53_record" "cname_2" {
  name            = "fm2._domainkey"
  ttl             = 300
  type            = "CNAME"
  zone_id         = aws_route53_zone.blog.zone_id

  records = [
    "fm2.${var.blog_domain}.dkim.fmhosted.com",
  ]
}

resource "aws_route53_record" "cname_3" {
  name            = "fm3._domainkey"
  ttl             = 300
  type            = "CNAME"
  zone_id         = aws_route53_zone.blog.zone_id

  records = [
    "fm3.${var.blog_domain}.dkim.fmhosted.com",
  ]
}