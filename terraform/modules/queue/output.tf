output "input_queue" {
  value = "${aws_sqs_queue.input_queue.name}"
}