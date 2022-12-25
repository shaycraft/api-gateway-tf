output "endpoint" {
  value = aws_apigatewayv2_api.lambda_proxy_api.api_endpoint
}

output "public_ip" {
  value = module.vpc.nat_public_ips
}

output "proxy_base_path" {
  value = var.proxy_base_path
}