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