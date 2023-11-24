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
