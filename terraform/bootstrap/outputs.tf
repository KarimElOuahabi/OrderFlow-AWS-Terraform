output "state_bucket_name" {
  description = "Name of the S3 bucket holding Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}
