data "archive_file" "stripe_webhook_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dist/handlers/stripe_webhook_lambda/"
  output_path = "${path.module}/lambda/dist/stripe_webhook_lambda.zip"
}

data "aws_iam_policy" "cloudwatch_iam_policy_for_lambda" {
  name = var.cloudwatch_lambda_iam_policy
}

data "template_file" "lambda_assume_role_policy" {
  template = file("./template/stripe_webhook_sqs_to_lambda_to_eventbridge_role_policy.tpl")
}

data "template_file" "stripe_webhook_sqs_to_lambda_policy_template" {
  template = file("./template/stripe_webhook_sqs_to_lambda_policy.tpl")

  vars = {
    sqsarn = aws_sqs_queue.stripe_webhook_sqs.arn
  }
}
