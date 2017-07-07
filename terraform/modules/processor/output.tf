output "scheduler_address" {
    value="${aws_elb.schd-elb-external.dns_name}"
}