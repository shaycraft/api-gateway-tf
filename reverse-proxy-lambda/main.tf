provider "aws" {
  region = var.AWS_REGION
}

data "aws_caller_identity" "current" {

}

# iam
data "aws_iam_policy_document" "policy_document_assume_lambda_role" {
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
  assume_role_policy = data.aws_iam_policy_document.policy_document_assume_lambda_role.json
}

resource "aws_iam_role_policy_attachment" "base" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.policy.arn
}

# vpc
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"

  tags = {
    Name = "terraform private vpc"
  }
}
resource "aws_subnet" "subnet_public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true // makes it a public subnet
  availability_zone       = var.AVAILABILITY_ZONE

  tags = {
    Name = "terraform subnet_public"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "terraform internet_gateway"
  }
}

resource "aws_route_table" "route_table_public" {
  vpc_id = aws_vpc.vpc.id

  route {
    //associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"
    //CRT uses this IGW to reach internet
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "terraform public route_table"
  }
}

resource "aws_route_table_association" "route_table_association_public" {
  subnet_id      = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.route_table_public.id
}

resource "aws_security_group" "security_group" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol    = "-1"
    self        = true
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment_lambda_vpc_access_execution" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

#Lambda 
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "arn:aws:lambda:us-west-2:395053504835:function:${aws_lambda_function.lambda_function.function_name}"
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.lambda_proxy_api.id}/*/*/{proxy+}"
}

resource "aws_lambda_function" "lambda_function" {
  filename         = "lambda_payload.zip"
  function_name    = "small-test"
  description      = "Reverse proxy"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = var.LAMBDA_HANDLER
  runtime          = var.LAMBDA_RUNTIME
  source_code_hash = filebase64("./lambda_payload.zip")
  vpc_config {
    subnet_ids         = [aws_subnet.subnet_public.id]
    security_group_ids = [aws_security_group.security_group.id]
  }

  tags = {
    Name = "terraform lambda"
  }
}

resource "aws_apigatewayv2_deployment" "deployment" {
  api_id      = aws_apigatewayv2_api.lambda_proxy_api.id
  description = "Terraform robot deployment beep boop beep!"
  depends_on  = [
    aws_apigatewayv2_route.proxy_route,
    aws_apigatewayv2_integration.lambda_integration
  ]

  triggers = {
    redeployment = sha1(join(",", tolist(
      [
        jsonencode(aws_apigatewayv2_integration.lambda_integration),
        jsonencode(aws_apigatewayv2_route.proxy_route)
      ]
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
