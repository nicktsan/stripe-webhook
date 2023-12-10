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

variable "stripe_webhook_APIGW_to_SQS_Role_name" {
  description = "Name of the role for API Gateway to send messages to SQS"
  type        = string
}

variable "stripe_webhook_APIGW_to_SQS_Policy_name" {
  description = "Name of the policy for API Gateway to send messages to SQS"
  type        = string
}

variable "apigwVersion" {
  description = "version of the stripe webhook api"
  type        = string
}

variable "dev_stripe_webhook_bucket_name" {
  description = "name of the dev_stripe_webhook_bucket"
  type        = string
}

variable "deps_layer_storage_key" {
  description = "Key of the S3 Object that will store deps lambda layer"
  type        = string
}

variable "path" {
  description = "last part of the api gateway url"
  type        = string
}

variable "stripe_secret_key" {
  description = "Key of the stripe secret stored in hcp vault secrets"
  type        = string
  sensitive   = true
}

variable "stripe_webhook_signing_secret" {
  description = "Key of the stripe webhook signing secret stored in hcp vault secrets"
  type        = string
  sensitive   = true
}

variable "utils_layer_storage_key" {
  description = "Key of the S3 object that will store utils lambda layer"
  type        = string
}

variable "revision" {
  description = "Revision of deployment"
  type        = string
}
