resource "aws_iam_role" "processor" {
  name = "${var.project_name}-order-processor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "processor_logs" {
  role       = aws_iam_role.processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "processor" {
  name = "queue-and-table-access"
  role = aws_iam_role.processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.order_created.arn
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.processed_events.arn
      }
    ]
  })
}

data "archive_file" "processor" {
  type        = "zip"
  source_file = "${path.module}/lambda/processor.py"
  output_path = "${path.module}/lambda/processor.zip"
}

resource "aws_lambda_function" "processor" {
  function_name    = "${var.project_name}-order-processor"
  role             = aws_iam_role.processor.arn
  runtime          = "python3.12"
  handler          = "processor.handler"
  filename         = data.archive_file.processor.output_path
  source_code_hash = data.archive_file.processor.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.processed_events.name
    }
  }
}

resource "aws_lambda_event_source_mapping" "order_created" {
  event_source_arn = aws_sqs_queue.order_created.arn
  function_name    = aws_lambda_function.processor.arn
  batch_size       = 5
  enabled          = false
}
