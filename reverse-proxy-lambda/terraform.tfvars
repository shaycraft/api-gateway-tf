aws_region        = "us-west-2"
availability_zone = "us-west-2b"

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
      handler     = "index.handler"
    }
    #    "proxy" = {
    #      runtime = "python3.9"
    #    }
  }
}