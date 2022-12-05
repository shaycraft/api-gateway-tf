provider "aws" {
  region = "us-west-2"
}

resource "aws_apigatewayv2_deployment" "api_apigateway_example_fool_deployment" {
  api_id      = aws_apigatewayv2_api.api_gateway_example_fool.id
  description = "Terraform robot deployment beep boop beep!"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_apigatewayv2_stage" "api_gateway_example_fool_stage" {
  api_id = aws_apigatewayv2_api.api_gateway_example_fool.id
  name = "$default"
  deployment_id = aws_apigatewayv2_deployment.api_apigateway_example_fool_deployment.id
}

resource "aws_apigatewayv2_api" "api_gateway_example_fool" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title       = "api-gateway-example-fool"
      version     = "1.0"
      description = "I am the terraform robot beep beep!"
    }
    paths = {
      "/{proxy+}" = {
        parameters = {
          "proxy" = {
            description = "Path parameter for proxy+"
            name        = "proxy"
            in          = "path"
            required    = true
            schema = {
              type = "string"
            }
          }
        },
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            uri                  = "https://sampleserver6.arcgisonline.com/{proxy}"
            connectionType       = "INTERNET"
          }
        }
      }
    }
  })

  name          = "api-gateway-example-fool"
  protocol_type = "HTTP"

}
