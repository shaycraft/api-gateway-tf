output "endpoint" {
  value = aws_apigatewayv2_api.lambda_proxy_api.api_endpoint
}

output "public_ip" {
  value = module.vpc.nat_public_ips
}

output "gis_proxy_base_url" {
  value = var.gis_proxy_base_url
}