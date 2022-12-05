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
  depends_on = [
    aws_apigatewayv2_route.default_route
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

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.lambda_proxy_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.lambda_proxy_api.id
  integration_type = "AWS_PROXY"

  connection_type    = "INTERNET"
  description        = "Lambda proxy integration"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.tf-reverse-proxy-py.invoke_arn

}


resource "aws_apigatewayv2_api" "lambda_proxy_api" {
  name          = "Terraform Reverse Proxy Lambda"
  protocol_type = "HTTP"

}
