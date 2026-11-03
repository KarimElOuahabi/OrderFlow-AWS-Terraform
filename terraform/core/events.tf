resource "aws_cloudwatch_event_bus" "orders" {
  name = "${var.project_name}-orders-bus"
}

resource "aws_cloudwatch_event_rule" "order_created" {
  name           = "${var.project_name}-order-created"
  event_bus_name = aws_cloudwatch_event_bus.orders.name

  event_pattern = jsonencode({
    source        = ["orderflow.order-service"]
    "detail-type" = ["OrderCreated"]
  })
}

resource "aws_sqs_queue" "order_created_dlq" {
  name                      = "${var.project_name}-order-created-dlq"
  sqs_managed_sse_enabled   = true
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "order_created" {
  name                       = "${var.project_name}-order-created"
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_created_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_policy" "order_created" {
  queue_url = aws_sqs_queue.order_created.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.order_created.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.order_created.arn }
      }
    }]
  })
}

resource "aws_cloudwatch_event_target" "order_created_to_sqs" {
  rule           = aws_cloudwatch_event_rule.order_created.name
  event_bus_name = aws_cloudwatch_event_bus.orders.name
  arn            = aws_sqs_queue.order_created.arn
}

resource "aws_sqs_queue" "notify_dlq" {
  name                      = "${var.project_name}-notify-dlq"
  sqs_managed_sse_enabled   = true
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "notify" {
  name                       = "${var.project_name}-notify"
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = 60

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notify_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_policy" "notify" {
  queue_url = aws_sqs_queue.notify.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.notify.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.order_created.arn }
      }
    }]
  })
}

resource "aws_cloudwatch_event_target" "order_created_to_notify" {
  rule           = aws_cloudwatch_event_rule.order_created.name
  event_bus_name = aws_cloudwatch_event_bus.orders.name
  target_id      = "notify"
  arn            = aws_sqs_queue.notify.arn
}
