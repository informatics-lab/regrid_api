provider "aws" {
  region = "${var.region}"
}

module "queue" {
  source = "modules/queue"
  //iam_role = "${var.iam_role}"
}


module "processor" {
  source = "modules/processor"
  iam_role = "${var.iam_role}"
  input_queue_name = "${module.queue.input_queue}"
}

module "api" {
  source = "modules/api"
  region = "${var.region}"
  accountId = "${var.aws_account_id}"
  lambda_zip = "${data.external.zip_lambda.result["path"]}"
  queue_name = "${module.queue.input_queue}"
  iam_role = "${var.iam_role}"
}

data "external" "zip_lambda" {
  program = ["bash", "files/build.sh"]
}

output "api_url" {
  value = "${module.api.api_url}"
}

variable "iam_role" {
    type = "map"
    default = {
        "arn" = "arn:aws:iam::536099501702:role/erdc_api"
        "name" = "erdc_api"
    } 
}