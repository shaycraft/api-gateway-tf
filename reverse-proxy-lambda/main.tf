provider "aws" {
  region = var.AWS_REGION
}

data "aws_caller_identity" "current" {

}

# iam
data "aws_iam_policy_document" "policy_document" {
  statement {
    sid    = "IssaLambdaAssumeRole"
    effect = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "policy_document_exec" {
  version = "2012-10-17"

  statement {
    sid    = "issaLambdaExecPermission"
    effect = "Allow"

    resources = ["*"]

    actions = ["lambda:InvokeFunction"]
  }
}

resource "aws_iam_policy" "policy" {
  name   = "allow-lambda-exec-policy"
  policy = data.aws_iam_policy_document.policy_document_exec.json
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.policy_document.json
}

resource "aws_iam_role_policy_attachment" "base" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.policy.arn
}

#Lambda 
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "arn:aws:lambda:us-west-2:395053504835:function:reverse-proxy-arcgis-tf"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  #source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}/*/${aws_api_gateway_method.method.http_method}/${aws_api_gateway_resource.resource.path}"
  # TODO:  try qualified? or integration?_arn?
  #source_arn = aws_lambda_function.lambda_function.arn
  source_arn = "arn:aws:execute-api:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.lambda_proxy_api.id}/*/*/{proxy+}"
}

resource "aws_lambda_function" "lambda_function" {
  filename         = "lambda_payload.zip"
  function_name    = "reverse-proxy-arcgis-tf"
  role             = aws_iam_role.iam_for_lambda.arn
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
