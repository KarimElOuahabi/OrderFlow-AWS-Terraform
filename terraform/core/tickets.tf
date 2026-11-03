resource "aws_dynamodb_table" "tickets" {
  name         = "${var.project_name}-tickets"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ticket_id"

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
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:PutItem"]
      Resource = aws_dynamodb_table.tickets.arn
    }]
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

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.tickets.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "create_ticket_api" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_ticket.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.tickets.execution_arn}/*/*"
}

output "api_url" {
  description = "Base URL of the tickets API"
  value       = aws_apigatewayv2_stage.default.invoke_url
}
