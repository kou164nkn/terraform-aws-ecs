variable "aws_access_key" {}
variable "aws_secret_key" {}


variable "vpc_cidr" {
  default = "172.16.0.0/16"
}

variable "availability_zone" {
  default = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "cert_arn" {
  default     = ""
  description = "certificateARN for TLS connection"
}
