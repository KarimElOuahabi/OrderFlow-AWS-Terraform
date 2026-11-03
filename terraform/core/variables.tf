variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix resource names"
  type        = string
  default     = "orderflow"
}

variable "sender_email" {
  type        = string
  description = "Verified SES address the notification emails are sent from"
}
