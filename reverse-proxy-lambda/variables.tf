variable "aws_region" {
  type = string
}

variable "availability_zone" {
  type = string
}

variable "LAMBDA_CONFIG" {
  type = object({
    payload_file = string
    selected = map(object({
      runtime     = string
      name        = string
      description = string
      source_dir  = string
      handler     = string

    }))
  })
}

variable "SELECTED_LAMBDA" {
  type    = string
  default = "ping"
}
