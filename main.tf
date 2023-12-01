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
  layers = [
    aws_lambda_layer_version.lambda_deps_layer.arn,
    # aws_lambda_layer_version.lambda_utils_layer.arn
  ]

  # environment {
  #   variables = {
  #     # STRIPE_SECRET = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)[var.stripe_secret_key]
  #     STRIPE_SECRET = data.hcp_vault_secrets_secret.stripeSecret.secret_value
  #   }
  # }
}

resource "aws_lambda_layer_version" "lambda_deps_layer" {
  layer_name = "stripe_webhook_shared_deps"
  s3_bucket  = aws_s3_bucket.dev_stripe_webhook_bucket.id     #conflicts with filename
  s3_key     = aws_s3_object.lambda_deps_layer_s3_storage.key #conflicts with filename
  // If using s3_bucket or s3_key, do not use filename, as they conflict
  # filename         = data.archive_file.deps_layer_code_zip.output_path
  source_code_hash = data.archive_file.deps_layer_code_zip.output_base64sha256

  compatible_runtimes = [var.lambda_runtime]
  depends_on = [
    aws_s3_object.lambda_deps_layer_s3_storage,
  ]
}

#create an s3 resource for storing the deps layer
resource "aws_s3_object" "lambda_deps_layer_s3_storage" {
  bucket = aws_s3_bucket.dev_stripe_webhook_bucket.id
  key    = var.deps_layer_storage_key
  source = data.archive_file.deps_layer_code_zip.output_path

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = data.archive_file.deps_layer_code_zip.output_base64sha256
  depends_on = [
    data.archive_file.deps_layer_code_zip,
  ]
}

resource "aws_s3_bucket" "dev_stripe_webhook_bucket" {
  bucket = "movies-stripe-webhook-bucket"

  tags = {
    Name        = "My stripe_webhook dev bucket"
    Environment = "dev"
  }
}
//applies an s3 bucket acl resource to s3_backend
resource "aws_s3_bucket_acl" "s3_acl" {
  bucket     = aws_s3_bucket.dev_stripe_webhook_bucket.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.dev_stripe_webhook_bucket_acl_ownership]
}
# Resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
resource "aws_s3_bucket_ownership_controls" "dev_stripe_webhook_bucket_acl_ownership" {
  bucket = aws_s3_bucket.dev_stripe_webhook_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

#Allows lambdas to receive events from SQS
resource "aws_lambda_event_source_mapping" "example" {
  event_source_arn        = aws_sqs_queue.stripe_webhook_sqs.arn
  function_name           = aws_lambda_function.stripe_webhook_lambda.arn
  function_response_types = ["ReportBatchItemFailures"]
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

# Create an IAM role for API Gateway
resource "aws_iam_role" "stripe_webhook_APIGW_to_SQS_Role" {
  name               = var.stripe_webhook_APIGW_to_SQS_Role_name
  assume_role_policy = data.template_file.stripe_webhook_APIGW_to_SQS_Role_template.rendered
}

# Create an IAM policy for API Gateway to send messages to SQS
resource "aws_iam_policy" "stripe_webhook_APIGW_to_SQS_Policy" {
  name        = var.stripe_webhook_APIGW_to_SQS_Policy_name
  path        = "/"
  description = "IAM policy to for API Gateway to send messages to SQS"
  policy      = data.template_file.stripe_webhook_APIGW_to_SQS_Policy_template.rendered
}

# Attach the IAM stripe_webhook_APIGW_to_SQS_Policy to stripe_webhook_APIGW_to_SQS_Role
resource "aws_iam_role_policy_attachment" "APIGWPolicyAttachment" {
  role       = aws_iam_role.stripe_webhook_APIGW_to_SQS_Role.name
  policy_arn = aws_iam_policy.stripe_webhook_APIGW_to_SQS_Policy.arn
}

# Create an HTTP API Gateway
resource "aws_api_gateway_rest_api" "stripe_webhook_api" {
  name = "stripe-webhook-http-api"
  body = data.template_file.stripe_webhook_api_body.rendered
}

# Create a new API Gateway deployment for the created rest api
resource "aws_api_gateway_deployment" "stripe_webhook_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.stripe_webhook_api.id
  lifecycle {
    create_before_destroy = true
  }
}

# Create a Log Group for API Gateway to push logs to
resource "aws_cloudwatch_log_group" "stripe_webhook_APIGW_logGroup" {
  name_prefix = "/aws/stripe-webhook-APIGW/terraform"
}

# Create a Log Policy to allow Cloudwatch to Create log streams and put logs
resource "aws_cloudwatch_log_resource_policy" "stripe_webhook_APIGW_logPolicy" {
  policy_name     = "Terraform-stripe_webhook_APIGW_logPolicy-${data.aws_caller_identity.current.account_id}"
  policy_document = data.template_file.stripe_webhook_APIGW_logPolicy_template.rendered
}


# Create a new API Gateway stage with logging enabled
resource "aws_api_gateway_stage" "StripeWebhookGatewayStage" {
  deployment_id = aws_api_gateway_deployment.stripe_webhook_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.stripe_webhook_api.id
  stage_name    = "default"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.stripe_webhook_APIGW_logGroup.arn
    format          = "{ \"requestId\":\"$context.requestId\", \"ip\": \"$context.identity.sourceIp\", \"requestTime\":\"$context.requestTime\", \"httpMethod\":\"$context.httpMethod\",\"routeKey\":\"$context.routeKey\", \"status\":\"$context.status\",\"protocol\":\"$context.protocol\", \"responseLength\":\"$context.responseLength\" }"
  }
}

# Configure API Gateway to push all logs to CloudWatch Logs
resource "aws_api_gateway_method_settings" "StripeWebhookGatewaySettings" {
  rest_api_id = aws_api_gateway_rest_api.stripe_webhook_api.id
  stage_name  = aws_api_gateway_stage.StripeWebhookGatewayStage.stage_name
  method_path = "*/*"

  settings {
    # Enable CloudWatch logging and metrics
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

# resource "stripe_webhook_endpoint" "webhook" {
#   url         = join("",[aws_api_gateway_stage.StripeWebhookGatewayStage.invoke_url, "/webhook"])
#   description = "webhook for checkout completion and order fulfillment"
#   enabled_events = [
#     "checkout.session.completed"
#   ]
# }
# TODO CREATE stripe endpoint
