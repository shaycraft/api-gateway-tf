data "aws_caller_identity" "current" {}
data "aws_availability_zones" "az" {
  state = "available"
}

# iam
data "aws_iam_policy_document" "policy_document_assume_lambda_role" {
  statement {
    sid    = "TfLambdaAssumeRole"
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
    sid    = "TfLambdaExecPermission"
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

module "vpc" {
  source                       = "terraform-aws-modules/vpc/aws"
  name                         = "da-vpc"
  cidr                         = "10.0.0.0/16"
  public_subnets               = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets              = ["10.0.50.0/24", "10.0.51.0/24"]
  azs                          = data.aws_availability_zones.az.names
  create_database_subnet_group = false
  enable_nat_gateway           = true
  enable_dns_hostnames         = true
  default_network_acl_egress = [
    {
      protocol   = -1
      rule_no    = 100
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 0
      to_port    = 0
    }
  ]
  default_network_acl_ingress = [
    {
      protocol   = -1
      rule_no    = 100
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 0
      to_port    = 0
  }]
  tags = {
    Name      = "vpc terraform module poc"
    CreatedBy = "terraform"
  }
}

# TODO:  rename to `default_lambda_security_group`
resource "aws_default_security_group" "default_security_group" {
  vpc_id = module.vpc.vpc_id

  ingress {
    protocol    = -1
    self        = true
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "proxy-default-security-group"
    CreatedBy = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment_lambda_vpc_access_execution" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda
locals {
  selected_lambda_config = var.LAMBDA_CONFIG.selected[var.SELECTED_LAMBDA]
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "arn:aws:lambda:us-west-2:395053504835:function:${aws_lambda_function.lambda_function.function_name}"
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.lambda_proxy_api.id}/*/*/{proxy+}"
}

data "archive_file" "archive" {
  output_path = var.LAMBDA_CONFIG.payload_file
  type        = "zip"
  source_dir  = local.selected_lambda_config.source_dir
}

resource "aws_lambda_function" "lambda_function" {
  filename      = var.LAMBDA_CONFIG.payload_file
  function_name = local.selected_lambda_config.name
  description   = local.selected_lambda_config.description
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "index.handler"
  runtime       = local.selected_lambda_config.runtime
  timeout       = local.selected_lambda_config.timeout == null ? var.DEFAULT_LAMBDA_TIMEOUT : local.selected_lambda_config.timeout

  source_code_hash = data.archive_file.archive.output_base64sha256

  vpc_config {
    subnet_ids         = [module.vpc.private_subnets[0]]
    security_group_ids = [aws_default_security_group.default_security_group.id]
  }

  environment {
    variables = {
      natGatewayIp       = module.vpc.nat_public_ips[0]
      gis_proxy_base_url = var.gis_proxy_base_url
    }
  }

  tags = {
    Name = "terraform lambda"
  }
}

resource "aws_apigatewayv2_deployment" "deployment" {
  api_id      = aws_apigatewayv2_api.lambda_proxy_api.id
  description = "Terraform robot deployment beep boop beep!"
  depends_on = [
    aws_apigatewayv2_route.proxy_route,
    aws_apigatewayv2_integration.lambda_integration,
    aws_lambda_function.lambda_function
  ]

  triggers = {
    redeployment = sha1(join(",", tolist(
      [
        jsonencode(aws_apigatewayv2_integration.lambda_integration),
        jsonencode(aws_apigatewayv2_route.proxy_route),
        jsonencode(aws_lambda_function.lambda_function)
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
}

resource "aws_apigatewayv2_api" "lambda_proxy_api" {
  name          = "terraform-reverse-proxy-lambda"
  protocol_type = "HTTP"

  tags = {
    "created_by" = "terraform",
    "keywords"   = "terraform proxy vpc-test"
  }

}
