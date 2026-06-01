# terraform/outputs.tf

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "jump_server_id" {
  description = "Jump server instance ID"
  value       = aws_instance.jump.id
}

output "jump_server_public_ip" {
  description = "Jump server elastic IP"
  value       = aws_eip.jump.public_ip
}

output "http_server_ids" {
  description = "Private HTTP server instance IDs"
  value       = aws_instance.http_server[*].id
}

output "http_server_private_ips" {
  description = "Private HTTP server IPs"
  value       = aws_instance.http_server[*].private_ip
}

output "caller_identity" {
  description = "Who Terraform is running as"
  value       = data.aws_caller_identity.current.arn
}