############################################
# DynamoDB Table
############################################
resource "aws_dynamodb_table" "bookings" {
  name         = "${var.project_name}-bookings"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "booking_id"

  attribute {
    name = "booking_id"
    type = "S"
  }

  tags = {
    Project = var.project_name
  }
}

############################################
# SNS Topic + Subscription
############################################
resource "aws_sns_topic" "booking_notifications" {
  name = "${var.project_name}-booking-notifications"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.booking_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

############################################
# IAM Role + Policy for Lambda
############################################
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["dynamodb:*"]
        Resource = aws_dynamodb_table.bookings.arn
      },
      {
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = aws_sns_topic.booking_notifications.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

############################################
# Lambda Function
############################################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda_package.zip"
}

resource "aws_lambda_function" "booking_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      BOOKINGS_TABLE = aws_dynamodb_table.bookings.name
      SNS_TOPIC_ARN  = aws_sns_topic.booking_notifications.arn
    }
  }
}

############################################
# API Gateway
############################################
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project_name}-api"
  description = "REST API for doctor appointment bookings"
}

# Resources
resource "aws_api_gateway_resource" "book" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "book"
}

resource "aws_api_gateway_resource" "update" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "update"
}

resource "aws_api_gateway_resource" "cancel" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "cancel"
}

resource "aws_api_gateway_resource" "bookings" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "bookings"
}

locals {
  lambda_arn = aws_lambda_function.booking_handler.invoke_arn

  cors_method_response = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  cors_integration_response = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

############################################
# API Methods + Integrations
############################################
# POST /book
resource "aws_api_gateway_method" "book_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.book.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "book_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.book.id
  http_method             = aws_api_gateway_method.book_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = local.lambda_arn
}

# PUT /update
resource "aws_api_gateway_method" "update_put" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.update.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "update_put_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.update.id
  http_method             = aws_api_gateway_method.update_put.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = local.lambda_arn
}

# DELETE /cancel
resource "aws_api_gateway_method" "cancel_delete" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.cancel.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cancel_delete_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.cancel.id
  http_method             = aws_api_gateway_method.cancel_delete.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = local.lambda_arn
}

# GET /bookings
resource "aws_api_gateway_method" "bookings_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.bookings.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "bookings_get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.bookings.id
  http_method             = aws_api_gateway_method.bookings_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = local.lambda_arn
}

############################################
# OPTIONS Methods for CORS (All endpoints)
############################################
locals {
  endpoints = {
    book     = aws_api_gateway_resource.book.id
    update   = aws_api_gateway_resource.update.id
    cancel   = aws_api_gateway_resource.cancel.id
    bookings = aws_api_gateway_resource.bookings.id
  }
}

resource "aws_api_gateway_method" "options_methods" {
  for_each      = local.endpoints
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = each.value
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_integrations" {
  for_each      = local.endpoints
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = each.value
  http_method   = aws_api_gateway_method.options_methods[each.key].http_method
  type          = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_method_responses" {
  for_each            = local.endpoints
  rest_api_id         = aws_api_gateway_rest_api.api.id
  resource_id         = each.value
  http_method         = aws_api_gateway_method.options_methods[each.key].http_method
  status_code         = "200"
  response_parameters = local.cors_method_response
}

resource "aws_api_gateway_integration_response" "options_integration_responses" {
  for_each            = local.endpoints
  rest_api_id         = aws_api_gateway_rest_api.api.id
  resource_id         = each.value
  http_method         = aws_api_gateway_method.options_methods[each.key].http_method
  status_code         = "200"
  response_parameters = local.cors_integration_response
}

############################################
# Deployment + Stage
############################################
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.book_post_integration,
    aws_api_gateway_integration.update_put_integration,
    aws_api_gateway_integration.cancel_delete_integration,
    aws_api_gateway_integration.bookings_get_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
  stage_name    = "prod"
}

############################################
# Lambda Permission for API Gateway
############################################
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.booking_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

############################################
# S3 Website Hosting (Frontend)
############################################
resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "${var.project_name}-frontend-${random_id.bucket_id.hex}"
}

resource "aws_s3_bucket_public_access_block" "frontend_block" {
  bucket                  = aws_s3_bucket.frontend_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

data "aws_iam_policy_document" "s3_website_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend_bucket.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = data.aws_iam_policy_document.s3_website_policy.json
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "index.html"
  source       = "${path.module}/frontend/index.html"
  content_type = "text/html"
}

resource "aws_s3_object" "style" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "style.css"
  source       = "${path.module}/frontend/style.css"
  content_type = "text/css"
}

resource "aws_s3_object" "script" {
  bucket       = aws_s3_bucket.frontend_bucket.id
  key          = "script.js"
  source       = "${path.module}/frontend/script.js"
  content_type = "application/javascript"
}


