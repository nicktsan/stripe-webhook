# Display the SQS queue URL & API Gateway invokation URL
output "SQS-QUEUE" {
  value       = aws_sqs_queue.stripe_webhook_sqs.id
  description = "The SQS Queue URL"
}
output "APIGW-URL" {
  value       = aws_api_gateway_stage.StripeWebhookGatewayStage.invoke_url
  description = "The API Gateway Invocation URL Queue URL"
}

# Command for testing to send data to api gateway
output "Test-Command1" {
  value       = "curl --location --request POST '${aws_api_gateway_stage.StripeWebhookGatewayStage.invoke_url}/webhook' --header 'Content-Type: application/json'  --data-raw '{ \"TestMessage\": \"Hello From ApiGateway!\" }'"
  description = "Command to invoke the API Gateway"
}

# Command for testing to retrieve the message from the SQS queue
output "Test-Command2" {
  value       = "aws sqs receive-message --queue-url ${aws_sqs_queue.stripe_webhook_sqs.id}"
  description = "Command to query the SQS Queue for messages"
}

#output the CloudWatch Log Stream Name
output "eventbridge-Logs-Stream-Name" {
  value       = aws_cloudwatch_log_group.stripe_webhook_eventbridge_log_group.id
  description = "The CloudWatch Log Group Name"
}
