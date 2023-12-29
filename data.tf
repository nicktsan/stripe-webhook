# Setup for stripe webhook lambda
data "archive_file" "stripe_webhook_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dist/handlers/stripe_webhook_lambda/"
  output_path = "${path.module}/lambda/dist/stripe_webhook_lambda.zip"
}

# Setup for util lambda layer
data "archive_file" "utils_layer_code_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dist/layers/util-layer/"
  output_path = "${path.module}/lambda/dist/utils.zip"
}

# Setup for dependencies lambda layer
data "archive_file" "deps_layer_code_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dist/layers/deps-layer/"
  output_path = "${path.module}/lambda/dist/deps.zip"
}

# The cloudwatch iam policy for lambda
data "aws_iam_policy" "cloudwatch_iam_policy_for_lambda" {
  name = var.cloudwatch_lambda_iam_policy
}

# template file to use for lambda
data "template_file" "lambda_assume_role_policy" {
  template = file("./template/stripe_webhook_sqs_to_lambda_to_eventbridge_role.tpl")
}

# template file for policy for sqs to send messages to lambda
data "template_file" "stripe_webhook_sqs_to_lambda_policy_template" {
  template = file("./template/stripe_webhook_sqs_to_lambda_policy.tpl")

  vars = {
    sqsarn = aws_sqs_queue.stripe_webhook_sqs.arn
  }
}

data "template_file" "event_bridge_put_events_policy_template" {
  template = file("./template/event_bridge_put_events_policy.tpl")

  vars = {
    eventBusArn = aws_cloudwatch_event_bus.stripe_webhook_event_bus.arn
  }
}

# template file for IAM role to send messages from API gateway to SQS
data "template_file" "stripe_webhook_APIGW_to_SQS_Role_template" {
  template = file("./template/stripe_webhook_APIGW_to_SQS_Role.tpl")
}

# template file for IAM policy to send messages from API gateway to SQS
data "template_file" "stripe_webhook_APIGW_to_SQS_Policy_template" {
  template = file("./template/stripe_webhook_APIGW_to_SQS_Policy.tpl")

  vars = {
    sqsarn = aws_sqs_queue.stripe_webhook_sqs.arn
  }
}

# template file for an open api definition of the stripe webhook
data "template_file" "stripe_webhook_api_body" {
  template = file("./template/stripe_webhook_api_body.tpl")

  vars = {
    apigwVersion = var.apigwVersion
    APIGWRole    = aws_iam_role.stripe_webhook_APIGW_to_SQS_Role.arn
    region       = var.region
    account_id   = data.aws_caller_identity.current.account_id
    sqsname      = aws_sqs_queue.stripe_webhook_sqs.name
  }
}

# initialize the current caller to get their account number information
data "aws_caller_identity" "current" {}

# template for the logging policy of API gateway
data "template_file" "stripe_webhook_APIGW_logPolicy_template" {
  template = file("./template/stripe_webhook_APIGW_logPolicy.tpl")

  vars = {
    logGroup = aws_cloudwatch_log_group.stripe_webhook_APIGW_logGroup.arn
    apiarn   = aws_api_gateway_rest_api.stripe_webhook_api.arn
  }
}

# data to grab the stripe secret from hcp vault secrets
data "hcp_vault_secrets_secret" "stripeSecret" {
  app_name    = "movie-app"
  secret_name = var.stripe_secret_key
}

# data to grab the stripe webhook signing secret from hcp vault secrets
data "hcp_vault_secrets_secret" "stripeSigningSecret" {
  app_name    = "movie-app"
  secret_name = var.stripe_webhook_signing_secret
}

# template for the cloudwatch logging policy for eventbridge
# data "template_file" "stripe_webhook_eventbridge_log_groupPolicy_template" {
#   template = file("./template/stripe_webhook_eventbridge_log_groupPolicy.tpl")
#   todo fix template to allow for logging
#   vars = {
#     logGroup     = aws_cloudwatch_log_group.stripe_webhook_eventbridge_log_group.arn
#     eventRuleArn = aws_cloudwatch_event_rule.stripe_webhook_eventbridge_event_rule.arn
#   }
# }

data "template_file" "stripe_webhook_eventbridge_event_rule_pattern_template" {
  template = file("./template/stripe_webhook_eventbridge_event_rule_pattern.tpl")

  vars = {
    # account_id  = data.aws_caller_identity.current.account_id
    eventSource = var.stripe_lambda_event_source
  }
}
