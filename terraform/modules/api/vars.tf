variable "region" {}
variable "accountId" {}
variable "lambda_zip" {}
variable "queue_name" {}
variable "iam_role" {
    type = "map"
}
variable "bucket" {}