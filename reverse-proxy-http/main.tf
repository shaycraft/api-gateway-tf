module "api-gateway" {
  source                 = "terraform-aws-modules/apigateway-v2/aws"
  name                   = "test-second-api"
  create_api_domain_name = false
  create_default_stage   = true

  protocol_type = "HTTP"

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
            uri                  = "${var.proxy_base_path[0]}/{proxy}"
            connectionType       = "INTERNET"
          }
        }
      }
    }
  })

  tags = {
    Name      = "terraform api"
    CreatedBy = "terraform"
  }
}


