#SQS to receieve messages from api gateway
resource "aws_sqs_queue" "stripe_webhook_sqs" {
  name                    = "stripe-webhook-sqs"
  sqs_managed_sse_enabled = true
  tags = {
    Environment = var.environment
  }
}
#set up a policy for the first sqs to send dead letters to the dlq
resource "aws_sqs_queue_redrive_policy" "stripe_webhook_sqs_redrive_policy" {
  queue_url = aws_sqs_queue.stripe_webhook_sqs.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.stripe_webhook_sqs_dlq.arn
    maxReceiveCount     = 4
  })
}
#SQS to receive dead letters
resource "aws_sqs_queue" "stripe_webhook_sqs_dlq" {
  name                      = "stripe-webhook-sqs-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
  tags = {
    Environment = var.environment
  }
}
#policy to receieve dead letters from the original sqs
resource "aws_sqs_queue_redrive_allow_policy" "stripe_webhook_sqs_dlq_redirve_allow_policy" {
  queue_url = aws_sqs_queue.stripe_webhook_sqs_dlq.id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.stripe_webhook_sqs.arn]
  })
}

#IAM Resource block for Lambda IAM role.
resource "aws_iam_role" "stripe_webhook_sqs_to_lambda_to_eventbridge_role" {
  name               = var.stripe_webhook_lambda_iam_role
  assume_role_policy = data.template_file.lambda_assume_role_policy.rendered
}

#attach both IAM Policy and IAM Role to each other:
resource "aws_iam_role_policy_attachment" "attach_cloudwatch_iam_policy_for_lambda" {
  role       = aws_iam_role.stripe_webhook_sqs_to_lambda_to_eventbridge_role.name
  policy_arn = data.aws_iam_policy.cloudwatch_iam_policy_for_lambda.arn
}

#IAM policy to provide receive message, delete message, and read attribute access to SQS queues
resource "aws_iam_policy" "stripe_webhook_sqs_to_lambda_policy" {
  name        = var.stripe_webhook_sqs_to_lambda_policy_name
  path        = "/"
  description = "IAM policy to provide receive message, delete message, and read attribute access to SQS queues"
  policy      = data.template_file.stripe_webhook_sqs_to_lambda_policy_template.rendered
}

#attach stripe_webhook_sqs_to_lambda_policy to stripe_webhook_sqs_to_lambda_to_eventbridge_role
resource "aws_iam_role_policy_attachment" "attach_stripe_webhook_sqs_to_lambda_policy" {
  role       = aws_iam_role.stripe_webhook_sqs_to_lambda_to_eventbridge_role.name
  policy_arn = aws_iam_policy.stripe_webhook_sqs_to_lambda_policy.arn
}

#lambda to receive message from sqs
resource "aws_lambda_function" "stripe_webhook_lambda" {
  filename      = data.archive_file.stripe_webhook_lambda_zip.output_path
  function_name = "stripe_webhook_lambda"
  role          = aws_iam_role.stripe_webhook_sqs_to_lambda_to_eventbridge_role.arn
  handler       = "index.handler"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = data.archive_file.stripe_webhook_lambda_zip.output_base64sha256
  runtime          = var.lambda_runtime
  # layers = [
  #   aws_lambda_layer_version.lambda_deps_layer.arn,
  #   # aws_lambda_layer_version.lambda_utils_layer.arn
  # ]

  # environment {
  #   variables = {
  #     # STRIPE_SECRET = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)[var.stripe_secret_key]
  #     STRIPE_SECRET = data.hcp_vault_secrets_secret.stripeSecret.secret_value
  #   }
  # }
}

#Allows lambdas to receive events from SQS
resource "aws_lambda_event_source_mapping" "example" {
  event_source_arn = aws_sqs_queue.stripe_webhook_sqs.arn
  function_name    = aws_lambda_function.stripe_webhook_lambda.arn

  # filter_criteria {
  #   filter {
  #     pattern = jsonencode({
  #       body = {
  #         Temperature : [{ numeric : [">", 0, "<=", 100] }]
  #         Location : ["New York"]
  #       }
  #     })
  #   }
  # }
}
