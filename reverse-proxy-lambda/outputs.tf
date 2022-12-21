output "endpoint" {
  value = aws_apigatewayv2_api.lambda_proxy_api.api_endpoint
}

output "public_ip" {
  value = aws_eip.eip.public_ip
}