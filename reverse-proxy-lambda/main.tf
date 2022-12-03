provider "aws" {
  region = "us-west-2"
}

resource "aws_apigatewayv2_deployment" "api_apigateway_lambda_fool_deployment" {
  api_id      = aws_apigatewayv2_api.api_gateway_lambda_fool.id
  description = "Terraform robot deployment beep boop beep!"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_apigatewayv2_stage" "api_gateway_lambda_fool_stage" {
  api_id        = aws_apigatewayv2_api.api_gateway_lambda_fool.id
  name          = "$default"
  deployment_id = aws_apigatewayv2_deployment.api_apigateway_lambda_fool_deployment.id
}

resource "aws_apigatewayv2_api" "api_gateway_lambda_fool" {
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
            httpMethod           = "POST"
            payloadFormatVersion = "2.0"
            connectionType       = "INTERNET"
            type                 = "AWS_PROXY"
            uri                  = "arn:aws:apigateway:us-west-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-west-2:395053504835:function:issa-py-reverse-proxy/invocations"
          }
        }
      }
    }
  })

  name          = "api-gateway-example-fool"
  protocol_type = "HTTP"

}
