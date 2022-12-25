variable "proxy_base_path" {
  type = list(string)
}

variable "region" {
  type        = string
  description = "AWS Region"
  default     = "us-west-2"
}