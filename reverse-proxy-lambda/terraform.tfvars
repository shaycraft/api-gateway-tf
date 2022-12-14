aws_region = "us-west-2"

vpc_cidr_block = "10.0.0.0/16"

LAMBDA_CONFIG = {
  aws_region        = "us-west-2"
  availability_zone = "us-west-2b"
  payload_file      = "lambda_payload.zip"
  selected = {
    "ping" = {
      runtime     = "nodejs14.x"
      name        = "ping-test"
      description = "Function to test internal and external network connectivity"
      source_dir  = "src/ping-test"
      timeout     = 15
    }
    "proxy" = {
      runtime     = "python3.9"
      name        = "gis-reverse-proxy-tf"
      description = "GIS server reverse proxy"
      source_dir  = "src/gis-reverse-proxy"
    }
  }
}

SELECTED_LAMBDA = "proxy"