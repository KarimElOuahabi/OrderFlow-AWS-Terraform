output "user_pool_id" {
  description = "Cognito user pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "client_id" {
  description = "Cognito app client ID used by the API"
  value       = aws_cognito_user_pool_client.api.id
}

# Read by the ephemeral stack so the bus name has a single source of truth.
output "event_bus_name" {
  description = "Name of the EventBridge bus the order-service publishes to"
  value       = aws_cloudwatch_event_bus.orders.name
}

output "issuer_uri" {
  value = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
}
