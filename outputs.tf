############################################
# Output Values
############################################
output "api_invoke_url" {
  description = "The invoke URL of the API Gateway"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}/"
}


output "lambda_function_name" {
  description = "Name of the deployed Lambda function"
  value       = aws_lambda_function.booking_handler.function_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.bookings.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic used for notifications"
  value       = aws_sns_topic.booking_notifications.arn
}

output "s3_website_url" {
  description = "URL of the S3 static website hosting the frontend"
  value       = aws_s3_bucket_website_configuration.frontend_website.website_endpoint
}

