# ECS Fargate cluster, IAM, task definition and service for order-service.

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

resource "aws_cloudwatch_log_group" "order_service" {
  name              = "/ecs/${var.project_name}-order-service"
  retention_in_days = 7
}

# Tasks only accept traffic from the ALB.
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Security group for order-service ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "order-service port from the ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-tasks-sg"
  }
}

# Execution role: used by ECS itself to pull the image, write logs and read the DB secret.
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_secret" {
  name = "read-db-master-secret"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_db_instance.db.master_user_secret[0].secret_arn
      }
    ]
  })
}

# Task role: the permissions the application code itself has.
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_put_events" {
  name = "put-events"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "events:PutEvents"
        Resource = "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:event-bus/${var.event_bus_name}"
      }
    ]
  })
}

resource "aws_ecs_task_definition" "order_service" {
  family                   = "${var.project_name}-order-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "order-service"
      image     = "${aws_ecr_repository.order_service.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [{ containerPort = 8080, protocol = "tcp" }]

      # Names are the Spring relaxed-binding forms of the properties in
      # services/order-service/src/main/resources/application.yaml and the @Value keys in the code.
      environment = [
        { name = "SPRING_DATASOURCE_URL", value = "jdbc:postgresql://${aws_db_instance.db.address}:5432/${aws_db_instance.db.db_name}" },
        { name = "SPRING_DATASOURCE_USERNAME", value = aws_db_instance.db.username },
        { name = "ORDERFLOW_AWS_REGION", value = var.aws_region },
        { name = "ORDERFLOW_EVENTBRIDGE_BUS_NAME", value = var.event_bus_name },
        { name = "COGNITO_ISSUER_URI", value = data.terraform_remote_state.core.outputs.issuer_uri },
      ]

      # application.yaml reads the password from ${DATABASE_PASSWORD}.
      # The RDS-managed secret is JSON; ":password::" selects that key.
      secrets = [
        { name = "DATABASE_PASSWORD", valueFrom = "${aws_db_instance.db.master_user_secret[0].secret_arn}:password::" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.order_service.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "order-service"
        }
      }
    }
  ])
}

# Tasks run in public subnets with public IPs so they can reach ECR, Secrets Manager
# and EventBridge without NAT or interface endpoints.
resource "aws_ecs_service" "order_service" {
  name            = "order-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.order_service.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Give Spring Boot and Flyway time to start before ALB health checks can kill the task.
  health_check_grace_period_seconds = 120

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.order_service.arn
    container_name   = "order-service"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.http]
}
