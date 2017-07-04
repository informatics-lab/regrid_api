
variable "region" {
  default = "eu-west-1"
}

variable "iam_profile" {
  default = "erdc_api"
}

variable "dns" {
  default = "erdc-api.informaticslab.co.uk"
}

variable "aws_account_id" {}

variable "bucket_name" {
  default = "regrid-api-result"
}

variable "versions" {
  type = "map"
  default = {
    distributed = "1.17.1"
    dask        = "0.15.0"
  }
}