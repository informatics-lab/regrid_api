resource "aws_sqs_queue" "input_queue" {
  name = "${var.input_queue_name}"
  delay_seconds = 2
  redrive_policy = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.input_queue_dlq.arn}\",\"maxReceiveCount\":5}"
}


resource "aws_sqs_queue" "input_queue_dlq" {
  name = "DLQ-${var.input_queue_name}"
}