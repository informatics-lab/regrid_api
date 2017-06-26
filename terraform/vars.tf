provider "aws" {
  region = "eu-west-1"
}

variable "iam_profile" {
  default = "climate-bot"
}

variable "dns" {
  default = "erdc-api.informaticslab.co.uk"
}
