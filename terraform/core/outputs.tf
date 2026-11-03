output "user_pool_id" {
  description = "Cognito user pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "client_id" {
  description = "Cognito app client ID used by the API"
  value       = aws_cognito_user_pool_client.api.id
}

output "issuer_uri" {
  value = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
}
