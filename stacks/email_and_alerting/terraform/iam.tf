# Email report
resource "aws_iam_policy" "email_report_cloudwatch_log_access" {
  name   = "${var.environment}-email-report-cloudwatch-log-access"
  policy = data.aws_iam_policy_document.email_report_cloudwatch_log_access.json
}


data "aws_iam_policy_document" "email_report_cloudwatch_log_access" {
  statement {
    sid = "CloudwatchLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.email_report_lambda.arn}:*",
    ]
  }
}

resource "aws_iam_role" "email_report_lambda_role" {
  name               = "${var.environment}-email-report-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.email_report_lambda_assume_role.json
}
resource "aws_iam_role_policy_attachment" "email_report_lambda_attach_ssm_access" {
  role       = aws_iam_role.email_report_lambda_role.name
  policy_arn = aws_iam_policy.email_report_lambda_ssm_access.arn
}

resource "aws_iam_role_policy_attachment" "email_report_lambda_attach_log_access" {
  role       = aws_iam_role.email_report_lambda_role.name
  policy_arn = aws_iam_policy.email_report_cloudwatch_log_access.arn
}

resource "aws_iam_role_policy_attachment" "email_report_lambda_attach_bucket_read_access" {
  role       = aws_iam_role.email_report_lambda_role.name
  policy_arn = aws_iam_policy.reports_generator_bucket_read_access.arn
}

resource "aws_iam_role_policy_attachment" "email_report_lambda_attach_send_raw_email" {
  role       = aws_iam_role.email_report_lambda_role.name
  policy_arn = aws_iam_policy.email_report_lambda_send_raw_email.arn
}


data "aws_iam_policy_document" "email_report_lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "email_report_lambda_ssm_access" {
  statement {
    sid = "GetSSMParameter"

    actions = [
      "ssm:GetParameter"
    ]

    resources = [
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${var.email_report_recipient_email_param_name}",
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${var.email_report_recipient_internal_email_param_name}",
    ]
  }
}

resource "aws_iam_policy" "email_report_lambda_ssm_access" {
  name   = "${var.environment}-email-report-lambda-ssm-access"
  policy = data.aws_iam_policy_document.email_report_lambda_ssm_access.json
}

data "aws_ssm_parameter" "reports_generator_bucket_name" {
  name = var.reports_generator_bucket_param_name
}

data "aws_iam_policy_document" "reports_generator_bucket_read_access" {
  statement {
    sid = "ListBucket"

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${data.aws_ssm_parameter.reports_generator_bucket_name.value}",
    ]
  }

  statement {
    sid = "ReadObjects"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${data.aws_ssm_parameter.reports_generator_bucket_name.value}/*"
    ]
  }
}

resource "aws_iam_policy" "reports_generator_bucket_read_access" {
  name   = "${data.aws_ssm_parameter.reports_generator_bucket_name.value}-read"
  policy = data.aws_iam_policy_document.reports_generator_bucket_read_access.json
}

resource "aws_iam_policy" "email_report_lambda_send_raw_email" {
  name   = "${var.environment}-email-report-send-raw-email"
  policy = data.aws_iam_policy_document.email_report_send_raw_email.json
}

data "aws_iam_policy_document" "email_report_send_raw_email" {
  statement {
    sid = "SendEmailWithAttachment"

    actions = [
      "ses:SendRawEmail"
    ]

    resources = [
      "arn:aws:ses:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:identity/${aws_ses_domain_identity.gp2gp_inbox.domain}",
      "arn:aws:ses:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:identity/${data.aws_ssm_parameter.email_report_recipient_internal_email_param_name.value}",
      "arn:aws:ses:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:identity/${data.aws_ssm_parameter.gp2gp_mailbox.value}"
    ]
  }
}

# Log alerts
resource "aws_iam_policy" "log_alerts_cloudwatch_log_access" {
  name   = "${var.environment}-log-alerts-cloudwatch-log-access"
  policy = data.aws_iam_policy_document.log_alerts_cloudwatch_log_access.json
}

resource "aws_cloudwatch_log_group" "log_alerts_technical_failures_above_threshold" {
  name = "/aws/lambda/${var.environment}-${var.log_alerts_technical_failures_above_threshold_lambda_name}"
  tags = merge(
    local.common_tags,
    {
      Name            = "${var.environment}-${var.log_alerts_technical_failures_above_threshold_lambda_name}"
      ApplicationRole = "AwsCloudwatchLogGroup"
    }
  )
  retention_in_days = 60
}

data "aws_iam_policy_document" "log_alerts_cloudwatch_log_access" {
  statement {
    sid = "CloudwatchLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.log_alerts_technical_failures_above_threshold.arn}:*",
      "${aws_cloudwatch_log_group.log_alerts_pipeline_error.arn}:*",
      "${aws_cloudwatch_log_group.gp2gp_dashboard_alert.arn}:*"
    ]
  }
}

resource "aws_iam_role" "log_alerts_lambda_role" {
  name               = "${var.environment}-log-alerts-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.log_alerts_lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "email_report_lambda_attach_log_alerts_access" {
  role       = aws_iam_role.email_report_lambda_role.name
  policy_arn = aws_iam_policy.log_alerts_ssm_access.arn
}

resource "aws_iam_role_policy_attachment" "email_report_lambda_attach_log_alerts_log_access" {
  role       = aws_iam_role.email_report_lambda_role.name
  policy_arn = aws_iam_policy.log_alerts_cloudwatch_log_access.arn
}

data "aws_iam_policy_document" "log_alerts_lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "log_alerts_ssm_access" {
  statement {
    sid = "GetSSMParameter"

    actions = [
      "ssm:GetParameter"
    ]

    resources = [
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${var.log_alerts_slack_bot_token_param_name}",
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${var.log_alerts_slack_channel_id_param_name}",
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${var.log_alerts_general_webhook_url_param_name}"
    ]
  }
}

resource "aws_iam_policy" "log_alerts_ssm_access" {
  name   = "${var.environment}-log-alerts-ssm-access"
  policy = data.aws_iam_policy_document.log_alerts_ssm_access.json
}

data "aws_iam_policy_document" "ses_to_s3" {
  statement {
    sid       = "AllowSESPuts"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.gp2gp_inbox_storage.id}/*"]

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["${aws_ses_receipt_rule_set.gp2gp_inbox.arn}:receipt-rule/*"]
    }
  }
}

resource "aws_s3_bucket_policy" "gp2gp_inbox_storage" {
  bucket = aws_s3_bucket.gp2gp_inbox_storage.id
  policy = data.aws_iam_policy_document.ses_to_s3.json
}

# Store asid lookup
data "aws_iam_policy_document" "store_asid_lookup_lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "store_asid_lookup_lambda" {
  name               = "${var.environment}-store-asid-lookup-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.store_asid_lookup_lambda_assume_role.json
}

data "aws_s3_bucket" "gp2gp_asid_lookup" {
  bucket = "prm-gp2gp-asid-lookup-${var.environment}"
}

resource "aws_iam_policy" "store_asid_lookup_lambda" {
  name        = "${var.environment}-store-asid-lookup-lambda-policy"
  description = "IAM policy for Store ASID Lookup Lambda"
  policy      = data.aws_iam_policy_document.store_asid_lookup_lambda_access.json
}

data "aws_iam_policy_document" "store_asid_lookup_lambda_access" {
  statement {
    sid    = "WriteLogsAndLogStream"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.store_asid_lookup.arn}:*"]
  }

  statement {
    sid    = "ReadWriteEmails"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = [
      "${aws_s3_bucket.gp2gp_inbox_storage.arn}/*"
    ]
  }

  statement {
    sid    = "ListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.gp2gp_inbox_storage.arn
    ]
  }

  statement {
    sid    = "WriteObjects"
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${data.aws_s3_bucket.gp2gp_asid_lookup.arn}/*"
    ]
  }

  statement {
    sid    = "GetSSMParameter"
    effect = "Allow"
    actions = [
      "ssm:GetParameter"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/registrations/${var.environment}/data-pipeline/gp2gp-dashboard/permitted-emails",
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/registrations/${var.environment}/data-pipeline/gp2gp-dashboard/email-storage-bucket-name"
    ]
  }

  statement {
    sid       = "ListStepFunctions"
    effect    = "Allow"
    actions   = ["states:ListStateMachines"]
    resources = ["*"]
  }

  statement {
    sid    = "StepFunctionExecution"
    effect = "Allow"
    actions = [
      "states:StartExecution"
    ]
    resources = ["arn:aws:states:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:stateMachine:ods-downloader-pipeline"]
  }
}

resource "aws_iam_role_policy_attachment" "store_asid_lookup_lambda" {
  policy_arn = aws_iam_policy.store_asid_lookup_lambda.arn
  role       = aws_iam_role.store_asid_lookup_lambda.name
}
