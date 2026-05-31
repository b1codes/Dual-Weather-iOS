output "api_url" {
  description = "Base URL of the deployed API."
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "function_name" {
  description = "Lambda function name — used by backend deploy script."
  value       = aws_lambda_function.api.function_name
}

output "table_name" {
  description = "DynamoDB table name."
  value       = aws_dynamodb_table.main.name
}

output "log_group_name" {
  description = "CloudWatch Log Group for the Lambda."
  value       = aws_cloudwatch_log_group.lambda.name
}
