output "endpoint" {
  value = aws_apigatewayv2_api.lambda_proxy_api.api_endpoint
}

output "public_ip" {
  value = aws_eip.eip.public_ip
}

output "gateway_private_ip" {
  value = aws_nat_gateway.nat_gateway.private_ip
}

output "gateway_public_ip" {
  value = aws_nat_gateway.nat_gateway.public_ip
}