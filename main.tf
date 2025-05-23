terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "mental-health-iot"
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.user_events.arn,
          aws_dynamodb_table.mental_health_insights.arn
        ]
      }
    ]
  })
}

# DynamoDB Tables
resource "aws_dynamodb_table" "user_events" {
  name           = "${var.project_name}-user-events"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"
  stream_enabled = true
  stream_view_type = "NEW_IMAGE"

  attribute {
    name = "userId"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-user-events"
    Environment = var.environment
  }
}

resource "aws_dynamodb_table" "mental_health_insights" {
  name         = "${var.project_name}-mental-health-insights"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "date"

  attribute {
    name = "date"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-mental-health-insights"
    Environment = var.environment
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "mental_health_api" {
  name        = "${var.project_name}-api"
  description = "Mental Health IoT Data API"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.post_user_integration,
    aws_api_gateway_integration.post_user_python_integration,
    aws_api_gateway_integration.get_mental_insights_integration,
    aws_api_gateway_integration.get_daily_insights_integration,
    aws_api_gateway_integration.get_visualizations_integration,
    aws_api_gateway_integration.get_summary_stats_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.mental_health_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.user_resource.id,
      aws_api_gateway_method.post_user.id,
      aws_api_gateway_integration.post_user_integration.id,
      aws_api_gateway_resource.user_python_resource.id,
      aws_api_gateway_method.post_user_python.id,
      aws_api_gateway_integration.post_user_python_integration.id,
      aws_api_gateway_resource.mental_insights_resource.id,
      aws_api_gateway_method.get_mental_insights.id,
      aws_api_gateway_integration.get_mental_insights_integration.id,
      aws_api_gateway_resource.daily_insights_resource.id,
      aws_api_gateway_method.get_daily_insights.id,
      aws_api_gateway_integration.get_daily_insights_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.mental_health_api.id
  stage_name    = var.environment
}

# Lambda Functions
resource "aws_lambda_function" "ts_lambda" {
  filename         = "ts-lambda.zip"
  function_name    = "${var.project_name}-ts-lambda"
  role            = aws_iam_role.lambda_role.arn
  handler         = "dist/app.handler"
  runtime         = "nodejs18.x"
  timeout         = 10

  environment {
    variables = {
      PGHOST     = "localhost"  # Replace with actual RDS endpoint
      PGUSER     = "postgres"
      PGPASSWORD = "example"
      PGDATABASE = "users"
      PGPORT     = "5432"
    }
  }

  depends_on = [aws_iam_role_policy.lambda_policy]
}

resource "aws_lambda_function" "py_lambda" {
  filename         = "py-lambda.zip"
  function_name    = "${var.project_name}-py-lambda"
  role            = aws_iam_role.lambda_role.arn
  handler         = "app.lambda_handler"
  runtime         = "python3.11"
  timeout         = 10

  environment {
    variables = {
      PGHOST     = "localhost"  # Replace with actual RDS endpoint
      PGUSER     = "postgres"
      PGPASSWORD = "example"
      PGDATABASE = "users"
      PGPORT     = "5432"
    }
  }

  depends_on = [aws_iam_role_policy.lambda_policy]
}

resource "aws_lambda_function" "mental_insights_lambda" {
  filename         = "mental-insights-lambda.zip"
  function_name    = "${var.project_name}-mental-insights"
  role            = aws_iam_role.lambda_role.arn
  handler         = "mental_insights.handler"
  runtime         = "nodejs18.x"
  timeout         = 10

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.mental_health_insights.name
    }
  }

  depends_on = [aws_iam_role_policy.lambda_policy]
}

# API Gateway Resources and Methods

# /user resource
resource "aws_api_gateway_resource" "user_resource" {
  rest_api_id = aws_api_gateway_rest_api.mental_health_api.id
  parent_id   = aws_api_gateway_rest_api.mental_health_api.root_resource_id
  path_part   = "user"
}

resource "aws_api_gateway_method" "post_user" {
  rest_api_id   = aws_api_gateway_rest_api.mental_health_api.id
  resource_id   = aws_api_gateway_resource.user_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_user_integration" {
  rest_api_id = aws_api_gateway_rest_api.mental_health_api.id
  resource_id = aws_api_gateway_resource.user_resource.id
  http_method = aws_api_gateway_method.post_user.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.ts_lambda.invoke_arn
}

# /user-python resource
resource "aws_api_gateway_resource" "user_python_resource" {
  rest_api_id = aws_api_gateway_rest_api.mental_health_api.id
  parent_id   = aws_api_gateway_rest_api.mental_health_api.root_resource_id
  path_part   = "user-python"
}

resource "aws_api_gateway_method" "post_user_python" {
  rest_api_id   = aws_api_gateway_rest_api.mental_health_api.id
  resource_id   = aws_api_gateway_resource.user_python_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_user_python_integration" {
  rest_api_id = aws_api_gateway_rest_api.mental_health_api.id
  resource_id = aws_api_gateway_resource.user_python_resource.id
  http_method = aws_api_gateway_method.post_user_python.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.py_lambda.invoke_arn
}

# /mental-insights resource
resource "aws_api_gateway_resource" "mental_insights_resource" {
  rest_api_id = aws_api_gateway_rest_api.mental_health_api.id
  parent_id   = aws_api_gateway_rest_api.mental_health_api.root_resource_id
  path_part   = "mental-insights"
}

resource "aws_api_gateway_method" "get_mental_insights" {
  rest_api_id   = aws_api_gateway_rest_api.mental_health_api.id
  resource_id   = aws_api_gateway_resource.mental_insights_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_mental_insights_integration" {
  rest_api_id = aws_api_gateway_rest_api.mental_health_api.id
  resource_id = aws_api_gateway_resource.mental_insights_resource.id
  http_method = aws_api_gateway_method.get_mental_insights.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.mental_insights_lambda.invoke_arn
}

# /visualizations resource
resource "aws_api_gateway_resource" "visualizations_resource" {
  rest_api_id = aws_api_gateway_rest_api.mental_health_api.id
  parent_id   = aws_api_gateway_rest_api.mental_health_api.root_resource_id
  path_part   = "visualizations"
}

resource "aws_api_gateway_method" "get_visualizations" {
  rest_api_id   = aws_api_gateway_rest_api.mental_health_api.id
  resource_id   = aws_api_gateway_resource.visualizations_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_visualizations_integration" {
  rest_api_id = aws_api_gateway_rest_api.mental_health_api.id
  resource_id = aws_api_gateway_resource.visualizations_resource.id
  http_method = aws_api_gateway_method.get_visualizations.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.mental_insights_lambda.invoke_arn
}

# /summary-stats resource
resource "aws_api_gateway_resource" "summary_stats_resource" {
  rest_api_id = aws_api_gateway_rest_api.mental_health_api.id
  parent_id   = aws_api_gateway_rest_api.mental_health_api.root_resource_id
  path_part   = "summary-stats"
}

resource "aws_api_gateway_method" "get_summary_stats" {
  rest_api_id   = aws_api_gateway_rest_api.mental_health_api.id
  resource_id   = aws_api_gateway_resource.summary_stats_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_summary_stats_integration" {
  rest_api_id = aws_api_gateway_rest_api.mental_health_api.id
  resource_id = aws_api_gateway_resource.summary_stats_resource.id
  http_method = aws_api_gateway_method.get_summary_stats.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.mental_insights_lambda.invoke_arn
}
resource "aws_api_gateway_resource" "daily_insights_resource" {
  rest_api_id = aws_api_gateway_rest_api.mental_health_api.id
  parent_id   = aws_api_gateway_rest_api.mental_health_api.root_resource_id
  path_part   = "daily-insights"
}

resource "aws_api_gateway_method" "get_daily_insights" {
  rest_api_id   = aws_api_gateway_rest_api.mental_health_api.id
  resource_id   = aws_api_gateway_resource.daily_insights_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_daily_insights_integration" {
  rest_api_id = aws_api_gateway_rest_api.mental_health_api.id
  resource_id = aws_api_gateway_resource.daily_insights_resource.id
  http_method = aws_api_gateway_method.get_daily_insights.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.mental_insights_lambda.invoke_arn
}

# Lambda Permissions
resource "aws_lambda_permission" "allow_api_gateway_ts" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ts_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.mental_health_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_py" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.py_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.mental_health_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_insights" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mental_insights_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.mental_health_api.execution_arn}/*/*"
}

# Outputs
output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = "https://${aws_api_gateway_rest_api.mental_health_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.api_stage.stage_name}"
}

output "dynamodb_user_events_table" {
  description = "DynamoDB User Events table name"
  value       = aws_dynamodb_table.user_events.name
}

output "dynamodb_insights_table" {
  description = "DynamoDB Mental Health Insights table name"
  value       = aws_dynamodb_table.mental_health_insights.name
}