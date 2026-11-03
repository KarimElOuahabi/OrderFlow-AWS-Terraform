resource "aws_dynamodb_table" "tickets" {
  name         = "${var.project_name}-tickets"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ticket_id"

  # The stream feeds the triage Lambda.
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "ticket_id"
    type = "S"
  }
}

resource "aws_iam_role" "create_ticket" {
  name = "${var.project_name}-create-ticket"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "create_ticket_logs" {
  role       = aws_iam_role.create_ticket.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Least privilege: the function only ever writes new tickets.
resource "aws_iam_role_policy" "create_ticket" {
  name = "tickets-table-access"
  role = aws_iam_role.create_ticket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.tickets.arn
      },
      {
        # X-Ray write actions do not support resource-level permissions.
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetrySegments"]
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "create_ticket" {
  type        = "zip"
  source_file = "${path.module}/lambda/create_ticket.py"
  output_path = "${path.module}/lambda/create_ticket.zip"
}

resource "aws_lambda_function" "create_ticket" {
  function_name    = "${var.project_name}-create-ticket"
  role             = aws_iam_role.create_ticket.arn
  runtime          = "python3.12"
  handler          = "create_ticket.handler"
  filename         = data.archive_file.create_ticket.output_path
  source_code_hash = data.archive_file.create_ticket.output_base64sha256
  timeout          = 10

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.tickets.name
    }
  }
}

resource "aws_apigatewayv2_api" "tickets" {
  name          = "${var.project_name}-tickets-api"
  protocol_type = "HTTP"
}

# API Gateway validates the Cognito token itself, so the Lambda only sees verified claims.
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.tickets.id
  name             = "${var.project_name}-cognito"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
    audience = [aws_cognito_user_pool_client.api.id]
  }
}

resource "aws_apigatewayv2_integration" "create_ticket" {
  api_id                 = aws_apigatewayv2_api.tickets.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.create_ticket.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "create_ticket" {
  api_id             = aws_apigatewayv2_api.tickets.id
  route_key          = "POST /tickets"
  target             = "integrations/${aws_apigatewayv2_integration.create_ticket.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_cloudwatch_log_group" "tickets_api" {
  name              = "/aws/apigateway/${var.project_name}-tickets"
  retention_in_days = 14
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.tickets.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.tickets_api.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
}

resource "aws_lambda_permission" "create_ticket_api" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_ticket.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.tickets.execution_arn}/*/*"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "triage" {
  name = "${var.project_name}-triage"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "triage_logs" {
  role       = aws_iam_role.triage.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "triage" {
  name = "stream-table-and-bedrock-access"
  role = aws_iam_role.triage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.tickets.arn
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:DescribeStream"]
        Resource = aws_dynamodb_table.tickets.stream_arn
      },
      {
        # ListStreams is not a resource-level action, so it can only be allowed on "*".
        Effect   = "Allow"
        Action   = ["dynamodb:ListStreams"]
        Resource = "*"
      },
      {
        # The model is only invocable through the "us." inference profile, and the profile
        # routes to the foundation model in these three regions. IAM checks both the profile
        # ARN and each foundation-model ARN, so allow both.
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = concat(
          ["arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.triage_model_id}"],
          [for region in ["us-east-1", "us-east-2", "us-west-2"] :
          "arn:aws:bedrock:${region}::foundation-model/${replace(var.triage_model_id, "/^(us|eu|apac|global)[.]/", "")}"],
        )
      },
      {
        # X-Ray write actions do not support resource-level permissions.
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetrySegments"]
        Resource = "*"
      },
    ]
  })
}

data "archive_file" "triage" {
  type        = "zip"
  source_file = "${path.module}/lambda/triage.py"
  output_path = "${path.module}/lambda/triage.zip"
}

resource "aws_lambda_function" "triage" {
  function_name    = "${var.project_name}-triage"
  role             = aws_iam_role.triage.arn
  runtime          = "python3.12"
  handler          = "triage.handler"
  filename         = data.archive_file.triage.output_path
  source_code_hash = data.archive_file.triage.output_base64sha256
  timeout          = 30

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      MODEL_ID   = var.triage_model_id
      TABLE_NAME = aws_dynamodb_table.tickets.name
    }
  }
}

resource "aws_lambda_event_source_mapping" "triage" {
  event_source_arn  = aws_dynamodb_table.tickets.stream_arn
  function_name     = aws_lambda_function.triage.arn
  starting_position = "LATEST"
  batch_size        = 1
  enabled           = false

  # A failing record is dropped after a few retries instead of blocking the shard.
  maximum_retry_attempts = 3

  # Loop guard: triage updates the ticket, which is a MODIFY stream event. Only INSERTs
  # may trigger the function, otherwise it would invoke itself forever.
  filter_criteria {
    filter {
      pattern = jsonencode({ eventName = ["INSERT"] })
    }
  }
}

resource "aws_iam_role" "approve_ticket" {
  name = "${var.project_name}-approve-ticket"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "approve_ticket_logs" {
  role       = aws_iam_role.approve_ticket.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "approve_ticket" {
  name = "tickets-table-access"
  role = aws_iam_role.approve_ticket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.tickets.arn
      },
      {
        # X-Ray write actions do not support resource-level permissions.
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetrySegments"]
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "approve_ticket" {
  type        = "zip"
  source_file = "${path.module}/lambda/approve_ticket.py"
  output_path = "${path.module}/lambda/approve_ticket.zip"
}

resource "aws_lambda_function" "approve_ticket" {
  function_name    = "${var.project_name}-approve-ticket"
  role             = aws_iam_role.approve_ticket.arn
  runtime          = "python3.12"
  handler          = "approve_ticket.handler"
  filename         = data.archive_file.approve_ticket.output_path
  source_code_hash = data.archive_file.approve_ticket.output_base64sha256
  timeout          = 10

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.tickets.name
    }
  }
}

resource "aws_apigatewayv2_integration" "approve_ticket" {
  api_id                 = aws_apigatewayv2_api.tickets.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.approve_ticket.invoke_arn
  payload_format_version = "2.0"
}

# The JWT authorizer only proves who the caller is; the Lambda checks the admin group.
resource "aws_apigatewayv2_route" "approve_ticket" {
  api_id             = aws_apigatewayv2_api.tickets.id
  route_key          = "POST /tickets/{id}/approve"
  target             = "integrations/${aws_apigatewayv2_integration.approve_ticket.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_lambda_permission" "approve_ticket_api" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.approve_ticket.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.tickets.execution_arn}/*/*"
}

output "api_url" {
  description = "Base URL of the tickets API"
  value       = aws_apigatewayv2_stage.default.invoke_url
}
