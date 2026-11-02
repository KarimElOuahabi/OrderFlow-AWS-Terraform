output "alb_dns_name" {
  description = "Public DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for order-service images"
  value       = aws_ecr_repository.order_service.repository_url
}

output "rds_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = aws_db_instance.db.endpoint
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.order_service.name
}
