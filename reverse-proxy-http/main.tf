resource "aws_apigatewayv2_deployment" "default_deployment" {
  api_id      = aws_apigatewayv2_api.esri_http_proxy.id
  description = "Terraform robot deployment beep boop beep!"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id        = aws_apigatewayv2_api.esri_http_proxy.id
  name          = "$default"
  deployment_id = aws_apigatewayv2_deployment.default_deployment.id
}

resource "aws_apigatewayv2_api" "esri_http_proxy" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title       = "Esri Http Proxy (HTTP Integration)"
      version     = "1.0"
      description = "I am the terraform robot beep beep!"
      tags = {
        Name = "terraform"
      }
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
            uri                  = "${var.proxy_base_path}/{proxy}"
            connectionType       = "INTERNET"
          }
        }
      }
    }
  })

  name          = "ESRI HTTP Proxy"
  protocol_type = "HTTP"

}
