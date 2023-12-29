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
  lifecycle {
    create_before_destroy = true
  }
}

#attach stripe_webhook_sqs_to_lambda_policy to stripe_webhook_sqs_to_lambda_to_eventbridge_role
resource "aws_iam_role_policy_attachment" "attach_stripe_webhook_sqs_to_lambda_policy" {
  role       = aws_iam_role.stripe_webhook_sqs_to_lambda_to_eventbridge_role.name
  policy_arn = aws_iam_policy.stripe_webhook_sqs_to_lambda_policy.arn
}

# lambda to receive message from sqs
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
    aws_lambda_layer_version.lambda_utils_layer.arn
  ]

  environment {
    variables = {
      # DETAIL_TYPE                = var.detail_type
      STRIPE_SECRET              = data.hcp_vault_secrets_secret.stripeSecret.secret_value
      STRIPE_SIGNING_SECRET      = data.hcp_vault_secrets_secret.stripeSigningSecret.secret_value
      STRIPE_EVENT_BUS           = var.event_bus_name
      STRIPE_LAMBDA_EVENT_SOURCE = var.stripe_lambda_event_source
    }
  }
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
# Create an s3 resource for storing the utils_layer
resource "aws_lambda_layer_version" "lambda_utils_layer" {
  layer_name = "shared_utils"
  s3_bucket  = aws_s3_bucket.dev_stripe_webhook_bucket.id      #conflicts with filename
  s3_key     = aws_s3_object.lambda_utils_layer_s3_storage.key #conflicts with filename
  # filename         = data.archive_file.utils_layer_code_zip.output_path
  source_code_hash = data.archive_file.utils_layer_code_zip.output_base64sha256

  compatible_runtimes = [var.lambda_runtime]
  depends_on = [
    aws_s3_object.lambda_utils_layer_s3_storage,
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

# create an s3 object for storing the utils layer
resource "aws_s3_object" "lambda_utils_layer_s3_storage" {
  bucket = aws_s3_bucket.dev_stripe_webhook_bucket.id
  key    = var.utils_layer_storage_key
  source = data.archive_file.utils_layer_code_zip.output_path

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = data.archive_file.utils_layer_code_zip.output_base64sha256
  depends_on = [
    data.archive_file.utils_layer_code_zip,
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
  lifecycle {
    create_before_destroy = true
  }
}

# Attach the IAM stripe_webhook_APIGW_to_SQS_Policy to stripe_webhook_APIGW_to_SQS_Role
resource "aws_iam_role_policy_attachment" "APIGWPolicyAttachment" {
  role       = aws_iam_role.stripe_webhook_APIGW_to_SQS_Role.name
  policy_arn = aws_iam_policy.stripe_webhook_APIGW_to_SQS_Policy.arn
}

# Create an HTTP API Gateway
resource "aws_api_gateway_rest_api" "stripe_webhook_api" {
  name = "stripe-webhook-http-api"
  # body = data.template_file.stripe_webhook_api_body.rendered
  description = "stripe webhook"
}

#Configure API Gateway resource
resource "aws_api_gateway_resource" "stripe_webhook_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.stripe_webhook_api.id
  parent_id   = aws_api_gateway_rest_api.stripe_webhook_api.root_resource_id
  path_part   = var.path
}

#Configure API Gateway method request
resource "aws_api_gateway_method" "stripe_webhook_api_method" {
  rest_api_id   = aws_api_gateway_rest_api.stripe_webhook_api.id
  resource_id   = aws_api_gateway_resource.stripe_webhook_api_resource.id
  http_method   = "POST"
  authorization = "NONE"
  request_parameters = {
    "method.request.header.stripe-signature" = true,
  }
}

#Configure API Gateway integration
resource "aws_api_gateway_integration" "stripe_webhook_api_integration" {
  rest_api_id             = aws_api_gateway_rest_api.stripe_webhook_api.id
  resource_id             = aws_api_gateway_resource.stripe_webhook_api_resource.id
  http_method             = aws_api_gateway_method.stripe_webhook_api_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = join("", ["arn:aws:apigateway:", var.region, ":sqs:path/", data.aws_caller_identity.current.account_id, "/", aws_sqs_queue.stripe_webhook_sqs.name])
  credentials             = aws_iam_role.stripe_webhook_APIGW_to_SQS_Role.arn
  request_parameters = {
    "integration.request.header.Content-Type"                              = "'application/x-www-form-urlencoded'"
    "integration.request.querystring.MessageAttribute.1.Name"              = "'stripeSignature'"
    "integration.request.querystring.MessageAttribute.1.Value.DataType"    = "'String'"
    "integration.request.querystring.MessageAttribute.1.Value.StringValue" = "method.request.header.stripe-signature"
  }
  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$util.urlEncode($input.body)"
  }
  passthrough_behavior = "NEVER"
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

# Configure API Gateway integration response
resource "aws_api_gateway_integration_response" "stripe_webhook_api_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.stripe_webhook_api.id
  resource_id = aws_api_gateway_resource.stripe_webhook_api_resource.id
  http_method = aws_api_gateway_method.stripe_webhook_api_method.http_method
  status_code = aws_api_gateway_method_response.stripe_webhook_api_method_response.status_code
}

# Configure API Gateway method response
resource "aws_api_gateway_method_response" "stripe_webhook_api_method_response" {
  rest_api_id = aws_api_gateway_rest_api.stripe_webhook_api.id
  resource_id = aws_api_gateway_resource.stripe_webhook_api_resource.id
  http_method = aws_api_gateway_method.stripe_webhook_api_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}
# Forces redeployment of the api gateway after detecting changes
# resource "terraform_data" "stripe_webhook_api_deployment_replacement" {
#   input = var.revision
# }
# Create a new API Gateway deployment for the created rest api
resource "aws_api_gateway_deployment" "stripe_webhook_api_deployment" {
  depends_on  = [aws_api_gateway_integration.stripe_webhook_api_integration]
  rest_api_id = aws_api_gateway_rest_api.stripe_webhook_api.id

  #Trigger API Gateway redeployment based on changes to the following resources
  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.stripe_webhook_api_resource.id,
      aws_api_gateway_method.stripe_webhook_api_method.id,
      aws_api_gateway_integration.stripe_webhook_api_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
    # replace_triggered_by  = [terraform_data.stripe_webhook_api_deployment_replacement]
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
    format = join(", ", ["{ \"requestId\":\"$context.requestId\"",
      "\"ip\":\"$context.identity.sourceIp\"",
      "\"requestTime\":\"$context.requestTime\"",
      "\"httpMethod\":\"$context.httpMethod\"",
      "\"routeKey\":\"$context.routeKey\"",
      "\"status\":\"$context.status\",\"protocol\":\"$context.protocol\"",
      "\"responseLength\":\"$context.responseLength\"",
      "\"authorizererror\":\"$context.authorizer.error\"",
      "\"errormessage\":\"$context.error.message\"",
      "\"errormessageString\":\"$context.error.messageString\"",
      "\"errorresponseType\":\"$context.error.responseType\"",
      "\"integrationerror\":\"$context.integration.error\"",
    "\"integrationErrorMessage\":\"$context.integrationErrorMessage\" }"])
  }
}

# Create the custom Eventbridge event bus
resource "aws_cloudwatch_event_bus" "stripe_webhook_event_bus" {
  name = var.event_bus_name
}

#IAM policy for Lambda to send events to eventbridge
resource "aws_iam_policy" "event_bridge_put_events_policy" {
  name        = var.event_bridge_put_events_policy_name
  path        = "/"
  description = "IAM policy to send events to eventbridge"
  policy      = data.template_file.event_bridge_put_events_policy_template.rendered
  lifecycle {
    create_before_destroy = true
  }
}

#attach both IAM Policy and IAM Role to each other:
resource "aws_iam_role_policy_attachment" "attach_event_bridge_put_events_policy_for_lambda" {
  role       = aws_iam_role.stripe_webhook_sqs_to_lambda_to_eventbridge_role.name
  policy_arn = aws_iam_policy.event_bridge_put_events_policy.arn
}

# Create a Log Group for Eventbridge to push logs to
resource "aws_cloudwatch_log_group" "stripe_webhook_eventbridge_log_group" {
  name_prefix = "/aws/stripe-webhook-eventbridge/terraform"
}

# Create a Log Policy to allow Cloudwatch to Create log streams and put logs
# resource "aws_cloudwatch_log_resource_policy" "stripe_webhook_eventbridge_log_groupPolicy" {
#   policy_name     = "Terraform-stripe_webhook_eventbridge_log_groupPolicy-${data.aws_caller_identity.current.account_id}"
#   policy_document = data.template_file.stripe_webhook_eventbridge_log_groupPolicy_template.rendered
# }

#Create a new Event Rule
resource "aws_cloudwatch_event_rule" "stripe_webhook_eventbridge_event_rule" {
  name           = var.stripe_webhook_eventbridge_event_rule_name
  event_pattern  = data.template_file.stripe_webhook_eventbridge_event_rule_pattern_template.rendered
  event_bus_name = aws_cloudwatch_event_bus.stripe_webhook_event_bus.arn
}

#Set the log group as a target for the Eventbridge rule
resource "aws_cloudwatch_event_target" "stripe_webhook_eventbridge_log_group_target" {
  rule           = aws_cloudwatch_event_rule.stripe_webhook_eventbridge_event_rule.name
  arn            = aws_cloudwatch_log_group.stripe_webhook_eventbridge_log_group.arn
  event_bus_name = aws_cloudwatch_event_bus.stripe_webhook_event_bus.arn
}

#TODO implement alarm for DLQ
