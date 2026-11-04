# OrderFlow

OrderFlow is a small event-driven order and support-ticket platform built to practice production-style cloud engineering on AWS. A Spring Boot `order-service` stores orders in Postgres and publishes `OrderCreated` events through a transactional outbox to EventBridge, where serverless consumers record them and send confirmation emails. A separate serverless tickets API lets authenticated customers open support tickets, which are triaged by an AI model on Amazon Bedrock and then approved by an admin.

## Architecture

The `order-service` also validates the Cognito JWT itself, and the customer id and email come from the token claims rather than the request body.

## Tech stack

| Area | Technology |
|---|---|
| Order service | Java 21, Spring Boot 4.1.1, Spring Security OAuth2 resource server, Spring Data JPA, Flyway, hexagonal (ports and adapters) structure |
| Database | PostgreSQL on Amazon RDS |
| Messaging | Transactional outbox, Amazon EventBridge, Amazon SQS with dead-letter queues |
| Serverless | AWS Lambda (Python 3.12), API Gateway HTTP API, DynamoDB, Amazon SES, Amazon Bedrock (Converse API) |
| Auth | Amazon Cognito (user pool, `admin` group, JWT) |
| Compute and network | ECS Fargate, Application Load Balancer, ECR, VPC with public and private subnets |
| Infrastructure as code | Terraform (`hashicorp/aws ~> 5.0`), S3 remote state with lockfile locking |
| CI/CD and scanning | Jenkins, Gitleaks, Semgrep, Checkov, Trivy, Docker |

## Repository structure

```
orderflow/
├── Jenkinsfile                  # CI/CD pipeline
├── services/
│   └── order-service/           # Spring Boot service (domain, application, adapter, Flyway migrations, tests)
└── terraform/
    ├── .checkov.yaml            # Checkov config with documented skipped checks
    ├── bootstrap/               # S3 bucket for Terraform state
    ├── core/                    # Always-on serverless resources + Lambda source in lambda/
    └── ephemeral/               # VPC, RDS, ECR, ALB, ECS Fargate (demo only)
```

## Terraform stacks

| Stack | Contents | Lifecycle |
|---|---|---|
| `bootstrap` | Versioned, encrypted, private S3 bucket that holds the Terraform state for the other stacks | Created once, uses local state |
| `core` | Cognito, EventBridge bus, SQS queues and DLQs, DynamoDB tables, Lambda functions, API Gateway | Always on. Everything is pay-per-use, so idle cost is near zero |
| `ephemeral` | VPC, RDS Postgres, ECR, ALB, ECS Fargate cluster and service | Applied for the demo and destroyed the same day |

**Why the split:** the resources that cost money while idle (RDS, ALB) live in `ephemeral`, so they can be destroyed without touching the serverless stack or its data. `core` keeps running and holds the event bus that `order-service` publishes to. The ECS service starts with zero tasks (`desired_count` defaults to 0), and the ECR repository has `force_delete` and the RDS instance skips its final snapshot so `terraform destroy` is not blocked. The Lambda event source mappings (processor, notify, triage) are created disabled and switched on for the demo.

## CI/CD

The `Jenkinsfile` runs these stages:

1. **Check tools**: prints tool versions.
2. **Build and test**: `./mvnw clean package`, skipping `OrderServiceApplicationTests` (it needs a live database).
3. **Secret scan (Gitleaks)**: scans the workspace.
4. **SAST (Semgrep)**: scans the Java service and the Lambda code (report only).
5. **IaC scan (Checkov)**: scans `terraform/` using `terraform/.checkov.yaml` (soft-fail).
6. **Docker build**: builds the `order-service` image.
7. **Image scan (Trivy)**: fails the build on HIGH or CRITICAL vulnerabilities.
8. **Push to ECR** and 9. **Deploy to ECS**: run only when the `DEPLOY` checkbox is ticked (default off, so normal builds stay green). AWS credentials are injected at runtime with Jenkins `withCredentials`. The deploy stage forces a new ECS deployment.

## Security decisions

- **JWT authentication:** the order API and the tickets API both require a Cognito JWT. The customer identity (`sub`, `email`) is taken from verified token claims, never from the request body.
- **Admin-only approval:** the approve endpoint checks that the `cognito:groups` claim contains exactly `admin`, and a conditional DynamoDB update only lets a `PENDING_APPROVAL` ticket be approved.
- **Encryption and durability:** all four SQS queues use managed server-side encryption, the RDS storage is encrypted, and the two DynamoDB tables have point-in-time recovery.
- **Observability:** X-Ray tracing is active on all five Lambdas, and the tickets API stage writes access logs to CloudWatch (14-day retention).
- **Least-privilege IAM:** each Lambda has its own role with a small inline policy. For example, `create-ticket` can only `PutItem` and `approve-ticket` can only `UpdateItem` on the tickets table.
- **Safe AI output:** the triage Lambda truncates its input, asks the model for JSON only, and validates category and priority against fixed allow-lists. Anything unexpected falls back to `OTHER` and `MEDIUM`. A stream filter (INSERT only) plus an in-code check stop the Lambda from triggering itself.
- **Network:** the database sits in private subnets and only accepts traffic from the ECS tasks. The VPC default security group has no rules. There is no NAT gateway, so the Fargate tasks run in public subnets with public IPs, which is a deliberate cost trade-off.
- **Documented Checkov skips:** checks that need money, a domain or certificate, or customer-managed KMS keys are skipped in [`terraform/.checkov.yaml`](terraform/.checkov.yaml), with a one-line reason above each one.

## Cost approach

The expensive parts of the system (RDS, ALB, Fargate) are in the `ephemeral` stack, which is applied only for the demo and destroyed the same day. The always-on `core` stack uses pay-per-request services (DynamoDB on-demand, Lambda, SQS, EventBridge, API Gateway), and its event source mappings stay disabled until needed. There is no NAT gateway, no WAF and no multi-AZ database, and each of these choices is noted in the Checkov skip list.
