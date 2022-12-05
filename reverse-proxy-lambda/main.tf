provider "aws" {
  region = "us-west-2"
}

resource "aws_iam_role" "lambda_role" {
  name = "teraform_lambda_role"

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

# had to manually do this to make this work
# aws lambda add-permission \
#  --statement-id f35d4c84-8212-593d-9365-fb540b66fdc4 \
#  --action lambda:InvokeFunction \
#  --function-name "arn:aws:lambda:us-west-2:395053504835:function:reverse-proxy-arcgis-tf" \
#  --principal apigateway.amazonaws.com \
#  --source-arn "arn:aws:execute-api:us-west-2:395053504835:h5jkvbech3/*/*/{proxy+}"

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}



resource "aws_lambda_function" "lambda_function" {
  filename         = "lambda_payload.zip"
  function_name    = "reverse-proxy-arcgis-tf"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64("./lambda_payload.zip")
}

resource "aws_apigatewayv2_deployment" "deployment" {
  api_id      = aws_apigatewayv2_api.lambda_proxy_api.id
  description = "Terraform robot deployment beep boop beep!"
  depends_on = [
    aws_apigatewayv2_route.proxy_route,
    aws_apigatewayv2_integration.lambda_integration
  ]

  triggers = {
    redeployment = sha1(join(",", tolist(
      [jsonencode(aws_apigatewayv2_integration.lambda_integration),
      jsonencode(aws_apigatewayv2_route.proxy_route)]
    )))
  }

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

  connection_type        = "INTERNET"
  integration_method     = "POST"
  payload_format_version = "2.0"
  integration_uri        = aws_lambda_function.lambda_function.arn
  # integration_uri        = "https://sampleserver6.arcgisonline.com/{proxy}"


}


resource "aws_apigatewayv2_api" "lambda_proxy_api" {
  name          = "terraform-reverse-proxy-lambda"
  protocol_type = "HTTP"

}
