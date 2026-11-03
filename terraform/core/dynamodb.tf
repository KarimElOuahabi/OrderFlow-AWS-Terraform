resource "aws_dynamodb_table" "processed_events" {
  name         = "${var.project_name}-processed-events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "event_id"
    type = "S"
  }
}
