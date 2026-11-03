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

variable "triage_model_id" {
  type        = string
  default     = "us.anthropic.claude-haiku-5-5"
  description = "Bedrock model ID used for ticket triage. Haiku 5.5 only supports inference profiles, so this is the \"us.\" profile ID, not the plain model ID."
}
