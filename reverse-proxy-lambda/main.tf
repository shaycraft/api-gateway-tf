provider "aws" {
  region = "us-west-2"
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

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



resource "aws_lambda_function" "lambda_function" {
  filename      = "lambda_payload.zip"
  function_name = "reverse-proxy-arcgis-tf"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
}

resource "aws_apigatewayv2_deployment" "deployment" {
  api_id      = aws_apigatewayv2_api.lambda_proxy_api.id
  description = "Terraform robot deployment beep boop beep!"
  depends_on = [
    aws_apigatewayv2_route.proxy_route
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id        = aws_apigatewayv2_api.lambda_proxy_api.id
  name          = "$default"
  deployment_id = aws_apigatewayv2_deployment.deployment.id
}

resource "aws_apigatewayv2_route" "proxy_route" {
  api_id    = aws_apigatewayv2_api.lambda_proxy_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.lambda_proxy_api.id
  integration_type = "AWS_PROXY"

  connection_type    = "INTERNET"
  integration_method = "POST"
  # integration_uri    = aws_lambda_function.lambda_function.invoke_arn
  integration_uri = aws_lambda_function.lambda_function.arn
  payload_format_version = "2.0"

}


resource "aws_apigatewayv2_api" "lambda_proxy_api" {
  name          = "terraform-reverse-proxy-lambda"
  protocol_type = "HTTP"

}
