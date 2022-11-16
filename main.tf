provider "aws" {
    region = "us-west-2"
}

resource "aws_api_gateway_rest_api" "api_gateway_example_fool" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "api_gateway_example_fool"
      version = "1.0"
      description = "I am the terraform robot beep beep!"
    }
    paths = {
      "/v1" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            uri                  = "http://mvc.samhaycraft.net/v1"
          }
        }
      }
    }
  })

  name = "api_gateway_example_fool"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}
