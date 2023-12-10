data "archive_file" "stripe_webhook_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dist/handlers/stripe_webhook_lambda/"
  output_path = "${path.module}/lambda/dist/stripe_webhook_lambda.zip"
}

data "archive_file" "utils_layer_code_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dist/layers/util-layer/"
  output_path = "${path.module}/lambda/dist/utils.zip"
}

data "archive_file" "deps_layer_code_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dist/layers/deps-layer/"
  output_path = "${path.module}/lambda/dist/deps.zip"
}

data "aws_iam_policy" "cloudwatch_iam_policy_for_lambda" {
  name = var.cloudwatch_lambda_iam_policy
}

data "template_file" "lambda_assume_role_policy" {
  template = file("./template/stripe_webhook_sqs_to_lambda_to_eventbridge_role.tpl")
}

data "template_file" "stripe_webhook_sqs_to_lambda_policy_template" {
  template = file("./template/stripe_webhook_sqs_to_lambda_policy.tpl")

  vars = {
    sqsarn = aws_sqs_queue.stripe_webhook_sqs.arn
  }
}

data "template_file" "stripe_webhook_APIGW_to_SQS_Role_template" {
  template = file("./template/stripe_webhook_APIGW_to_SQS_Role.tpl")
}

data "template_file" "stripe_webhook_APIGW_to_SQS_Policy_template" {
  template = file("./template/stripe_webhook_APIGW_to_SQS_Policy.tpl")

  vars = {
    sqsarn = aws_sqs_queue.stripe_webhook_sqs.arn
  }
}

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

data "aws_caller_identity" "current" {}

data "template_file" "stripe_webhook_APIGW_logPolicy_template" {
  template = file("./template/stripe_webhook_APIGW_logPolicy.tpl")

  vars = {
    logGroup = aws_cloudwatch_log_group.stripe_webhook_APIGW_logGroup.arn
    apiarn   = aws_api_gateway_rest_api.stripe_webhook_api.arn
  }
}

data "hcp_vault_secrets_secret" "stripeSecret" {
  app_name    = "movie-app"
  secret_name = var.stripe_secret_key
}

data "hcp_vault_secrets_secret" "stripeSigningSecret" {
  app_name    = "movie-app"
  secret_name = var.stripe_webhook_signing_secret
}
