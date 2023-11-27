variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "environment for code (ie: dev, prod)"
  type        = string
}

variable "lambda_runtime" {
  description = "runtime for lambda"
  type        = string
}

variable "stripe_webhook_lambda_iam_role" {
  description = "Name of the IAM role for the lambda function"
  type        = string
}

variable "cloudwatch_lambda_iam_policy" {
  description = "Name of the cloudwatch policy for the lambda function"
  type        = string
}

variable "stripe_webhook_sqs_to_lambda_policy_name" {
  description = "Name of the policy to provide receive message, delete message, and read attribute access to SQS queues"
  type        = string
}
