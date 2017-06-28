provider "aws" {
  region = "eu-west-1"
}

variable "iam_profile" {
  default = "erdc_api"
}

variable "dns" {
  default = "erdc-api.informaticslab.co.uk"
}


variable "to_process_queue_name" {
  default = "erdc-api-to-process"
}