resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

data "archive_file" "placeholder" {
  type        = "zip"
  source_file = "${path.module}/lambda_placeholder/handler.py"
  output_path = "${path.module}/lambda_placeholder.zip"
}

resource "aws_lambda_function" "api" {
  function_name = var.function_name
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.12"
  architectures = ["arm64"]

  handler = "handler.handler"

  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  timeout     = 10
  memory_size = 512

  environment {
    variables = {
      DW_ENV                  = "prod"
      DW_TABLE_NAME           = aws_dynamodb_table.main.name
      DW_AUTH0_DOMAIN         = data.terraform_remote_state.platform.outputs.auth0_domain
      DW_AUTH0_AUDIENCE       = data.terraform_remote_state.platform.outputs.auth0_audience
      LOG_LEVEL               = "INFO"
      POWERTOOLS_SERVICE_NAME = "dual-weather-api"
    }
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
      handler,
    ]
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}
