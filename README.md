# OrderFlow-AWS-Terraform

A small event-driven order and support-ticket platform on AWS, built to practice cloud engineering with Terraform and CI/CD.

## How it works

- **Orders:** a Spring Boot `order-service` (ECS Fargate) saves orders in PostgreSQL and publishes an `OrderCreated` event to EventBridge. The event goes to SQS queues (with dead-letter queues), and Python Lambdas store it in DynamoDB and email the customer through SES.
- **Tickets:** customers open support tickets through an API Gateway and Lambda API. An AI model on Amazon Bedrock triages each ticket, and an admin approves it.
- **Login:** both APIs use Amazon Cognito JWTs. The customer identity comes from the token, never from the request body.

## Tech stack

Java 21 · Spring Boot · Python · Terraform · AWS (ECS Fargate, ECR, RDS, EventBridge, SQS, Lambda, DynamoDB, API Gateway, Cognito, SES, Bedrock) · Docker · Jenkins

## Project layout

```
services/order-service/   Spring Boot service
terraform/bootstrap/      S3 bucket for Terraform state
terraform/core/           Always-on serverless resources and Lambda code
terraform/ephemeral/      VPC, RDS, ALB, ECS (applied on demand, destroyed after use)
Jenkinsfile               CI/CD pipeline
```

The costly resources (RDS, ALB) live in the `ephemeral` stack, so they can be destroyed without touching the serverless stack.

## CI/CD

The Jenkins pipeline builds and tests the service, then runs security scans: Gitleaks (secrets), Semgrep (code), Checkov (Terraform) and Trivy (Docker image). It fails on findings. Pushing to ECR and deploying to ECS only run when the `DEPLOY` option is ticked.

## Notes

- Some Checkov checks are skipped on purpose (cost, no custom domain, no customer-managed keys). Each skip has a reason in `terraform/.checkov.yaml`.
- There is no NAT gateway, WAF or multi-AZ database, to keep costs low.
