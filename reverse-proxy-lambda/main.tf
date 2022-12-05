provider "aws" {
  region = "us-west-2"
}

resource "aws_iam_role" "tf_iam_for_lambda" {
  name = "tf_iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}



resource "aws_lambda_function" "tf-reverse-proxy-py" {
  filename      = "lambda_payload.zip"
  function_name = "tf-reverse-proxy-py"
  role          = aws_iam_role.tf_iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
}

resource "aws_apigatewayv2_deployment" "deployment" {
  api_id      = aws_apigatewayv2_api.lambda_proxy_api.id
  description = "Terraform robot deployment beep boop beep!"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id        = aws_apigatewayv2_api.lambda_proxy_api.id
  name          = "$default"
  deployment_id = aws_apigatewayv2_deployment.deployment.id
}

# resource "aws_apigatewayv2_integration" "integration" {
#   api_id = aws_apigatewayv2_api.lambda_proxy_api.id
# }


resource "aws_apigatewayv2_api" "lambda_proxy_api" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title       = "Terraformed Reverse Proxy Lambda"
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
            uri                  = aws_lambda_function.tf-reverse-proxy-py.invoke_arn
          }
        }
      }
    }
  })

  name          = "Terraform Reverse Proxy Lambda"
  protocol_type = "HTTP"

}
