provider "aws" {
  region = var.aws_region
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
  cidr_block = "10.0.0.0/16"
  #  enable_dns_support   = true
  #  enable_dns_hostnames = true
  #  instance_tenancy     = "default"

  tags = {
    Name = "terraform private vpc"
  }
}
resource "aws_subnet" "subnet_public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true // makes it a public subnet
  availability_zone       = var.availability_zone

  tags = {
    Name = "terraform subnet_public"
  }
}

resource "aws_subnet" "subnet_private" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false // private subnet
  availability_zone       = var.availability_zone

  tags = {
    Name = "terraform subnet private"
  }
}

resource "aws_route_table" "route_table_private" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "terraform route_table private"
  }
}

resource "aws_route_table_association" "route_table_association_private" {
  subnet_id      = aws_subnet.subnet_private.id
  route_table_id = aws_route_table.route_table_private.id
}


resource "aws_internet_gateway" "internet_gateway" {
  depends_on = [aws_vpc.vpc, aws_subnet.subnet_public]
  vpc_id     = aws_vpc.vpc.id

  tags = {
    Name = "terraform internet_gateway"
  }
}

resource "aws_route_table" "route_table_public" {
  depends_on = [aws_vpc.vpc, aws_internet_gateway.internet_gateway]
  vpc_id     = aws_vpc.vpc.id

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

resource "aws_default_security_group" "default_security_group" {
  vpc_id = aws_vpc.vpc.id

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

  # The below was from ec2 project config:

  #  egress = [
  #    {
  #      cidr_blocks      = ["0.0.0.0/0", ]
  #      description      = ""
  #      from_port        = 0
  #      ipv6_cidr_blocks = []
  #      prefix_list_ids  = []
  #      protocol         = "-1"
  #      security_groups  = []
  #      self             = false
  #      to_port          = 0
  #    }
  #  ]
  #  ingress = [
  #    {
  #      cidr_blocks      = ["0.0.0.0/0", ]
  #      description      = "SSH Port"
  #      from_port        = 22
  #      ipv6_cidr_blocks = []
  #      prefix_list_ids  = []
  #      protocol         = "tcp"
  #      security_groups  = []
  #      self             = false
  #      to_port          = 22
  #    },
  #    {
  #      cidr_blocks      = ["0.0.0.0/0", ]
  #      description      = "HTTP port"
  #      from_port        = 80
  #      ipv6_cidr_blocks = []
  #      prefix_list_ids  = []
  #      protocol         = "tcp"
  #      security_groups  = []
  #      self             = false
  #      to_port          = 80
  #    },
  #    {
  #      cidr_blocks      = ["0.0.0.0/0", ]
  #      description      = "HTTPS port"
  #      from_port        = 443
  #      ipv6_cidr_blocks = []
  #      prefix_list_ids  = []
  #      protocol         = "tcp"
  #      security_groups  = []
  #      self             = false
  #      to_port          = 443
  #    }
  #  ]

  tags = {
    Name      = "proxy-default-security-group"
    CreatedBy = "Terraform"
  }
}

resource "aws_default_network_acl" "default_network_acl" {
  default_network_acl_id = aws_vpc.vpc.default_network_acl_id
  subnet_ids             = [aws_subnet.subnet_public.id, aws_subnet.subnet_private.id]

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name      = "reverse-proxy-lambda-default-network-acl"
    CreatedBy = "Terraform"
  }
}

# eip and nat gateway
resource "aws_eip" "eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.internet_gateway]
  tags = {
    Name      = "proxy-eip"
    CreatedBy = "terraform"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.subnet_public.id

  tags = {
    Name      = "proxy-nat-gateway"
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
  handler       = local.selected_lambda_config.handler
  runtime       = local.selected_lambda_config.runtime
  timeout       = local.selected_lambda_config.timeout == null ? var.DEFAULT_LAMBDA_TIMEOUT : local.selected_lambda_config.timeout

  source_code_hash = data.archive_file.archive.output_base64sha256

  vpc_config {
    subnet_ids         = [aws_subnet.subnet_private.id]
    security_group_ids = [aws_default_security_group.default_security_group.id]
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
