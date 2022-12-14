variable "aws_region" {
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
      timeout     = optional(number)
    }))
  })
}

variable "SELECTED_LAMBDA" {
  type    = string
  default = "ping"
}

variable "DEFAULT_LAMBDA_TIMEOUT" {
  type        = number
  default     = 3
  description = "Default timeout (in seconds) for lambda execution"
}

variable "gis_proxy_base_url" {
  type        = string
  description = "Base path to use for reverse proxy url"
  default     = "https://localhost"
}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for VPC"
}