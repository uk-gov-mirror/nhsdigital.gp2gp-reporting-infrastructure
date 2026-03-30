locals {
  ses_domain = "mail.${var.hosted_zone_name}"
  from_email = "gp2gp-reports@${aws_ses_domain_identity.gp2gp_inbox.domain}"
}

data "aws_ssm_parameter" "asid_lookup_address_prefix" {
  name = var.asid_lookup_inbox_prefix_param_name
}

data "aws_ssm_parameter" "gp2gp_mailbox" {
  name = var.email_report_recipient_email_param_name
}

resource "aws_ses_email_identity" "gp2gp_mailbox" {
  email = data.aws_ssm_parameter.gp2gp_mailbox.value
}

resource "aws_ses_domain_identity" "gp2gp_inbox" {
  domain = local.ses_domain
}

resource "aws_ses_receipt_rule_set" "gp2gp_inbox" {
  rule_set_name = "gp2gp-inbox-rules-${var.environment}"
}

resource "aws_ses_active_receipt_rule_set" "active_rule_set" {
  rule_set_name = aws_ses_receipt_rule_set.gp2gp_inbox.rule_set_name
}

resource "aws_ses_receipt_rule" "asid_lookup" {
  name          = local.ses_receipt_rule_asid_lookup_name
  rule_set_name = aws_ses_receipt_rule_set.gp2gp_inbox.rule_set_name
  enabled       = true
  scan_enabled  = true
  recipients    = ["${data.aws_ssm_parameter.asid_lookup_address_prefix.value}@${local.ses_domain}"]

  s3_action {
    bucket_name       = aws_s3_bucket.gp2gp_inbox_storage.id
    object_key_prefix = "asid_lookup/"
    position          = 1
  }

  lambda_action {
    function_arn    = aws_lambda_function.store_asid_lookup.arn
    invocation_type = "Event"
    position        = 2
  }

  depends_on = [
    aws_s3_bucket_policy.gp2gp_inbox_storage,
    aws_lambda_permission.store_asid_lookup_ses_trigger
  ]
}

resource "aws_ses_domain_dkim" "gp2gp_inbox_domain_identification" {
  domain = aws_ses_domain_identity.gp2gp_inbox.domain
}

resource "aws_route53_record" "gp2gp_inbox_dkim_records" {
  count   = 3
  zone_id = data.aws_route53_zone.gp_registrations.zone_id
  name    = "${aws_ses_domain_dkim.gp2gp_inbox_domain_identification.dkim_tokens[count.index]}._domainkey.${local.ses_domain}"
  type    = "CNAME"
  ttl     = 1800
  records = ["${aws_ses_domain_dkim.gp2gp_inbox_domain_identification.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "gp2gp_inbox_dmarc" {
  zone_id = data.aws_route53_zone.gp_registrations.zone_id
  name    = "_dmarc.${local.ses_domain}"
  type    = "TXT"
  ttl     = 300

  records = ["v=DMARC1; p=none; adkim=s; aspf=s"]
}

resource "aws_ses_domain_mail_from" "sending" {
  domain           = aws_ses_domain_identity.gp2gp_inbox.domain
  mail_from_domain = "mail.${aws_ses_domain_identity.gp2gp_inbox.domain}"

  behavior_on_mx_failure = "UseDefaultValue"
}

resource "aws_route53_record" "ses_mail_from_mx" {
  zone_id = data.aws_route53_zone.gp_registrations.zone_id
  name    = "mail.${aws_ses_domain_identity.gp2gp_inbox.domain}"
  type    = "MX"
  ttl     = 600

  records = [
    "10 feedback-smtp.eu-west-2.amazonses.com"
  ]
}

resource "aws_route53_record" "ses_mail_from_spf" {
  zone_id = data.aws_route53_zone.gp_registrations.zone_id
  name    = "mail.${aws_ses_domain_identity.gp2gp_inbox.domain}"
  type    = "TXT"
  ttl     = 600

  records = [
    "v=spf1 include:amazonses.com -all"
  ]
}
