# auto scaling

resource "aws_autoscaling_policy" "workers_on" {
  name                   = "workers_on"
  scaling_adjustment     = 3 # TODO: Be confident in the scaling adjustments
  adjustment_type        = "ExactCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.erdc_dask_workers.name}" 
}

resource "aws_autoscaling_policy" "workers_off" {
  name                   = "workers_off"
  scaling_adjustment     = 0 
  adjustment_type        = "ExactCapacity"
  cooldown               = 60 # TODO: Think about cool down, should one be just under an hour?
  autoscaling_group_name = "${aws_autoscaling_group.erdc_dask_workers.name}" 
}

resource "aws_autoscaling_policy" "processor_on" {
  name                   = "processor_on"
  scaling_adjustment     = 1 # TODO: Be confident in the scaling adjustments
  adjustment_type        = "ExactCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.processor.name}" 
}

resource "aws_autoscaling_policy" "processor_off" {
  name                   = "processor_off"
  scaling_adjustment     = 0 
  adjustment_type        = "ExactCapacity"
  cooldown               = 60 # TODO: Think about cool down, should one be just under an hour?
  autoscaling_group_name = "${aws_autoscaling_group.processor.name}" 
}

resource "aws_cloudwatch_metric_alarm" "pending_messages" {
  alarm_name          = "pending_messages"
  dimensions          = {
    QueueName         = "${var.input_queue_name}"
  }
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"

  alarm_description = "This metric monitors the erdc api 'to process' queue length"
  alarm_actions     = [
      "${aws_autoscaling_policy.workers_on.arn}",
      "${aws_autoscaling_policy.processor_on.arn}"
  ]
  ok_actions        = [
      "${aws_autoscaling_policy.workers_off.arn}",
      "${aws_autoscaling_policy.processor_off.arn}"
  ]
}

# AMI for instances

data "aws_ami" "conda" {
  filter {
    name = "name",
    values = ["*conda*ubuntu*"]
  }
  filter {
    name = "virtualization-type",
    values = ["hvm"]
  }
  owners = ["455864098378"]
  most_recent = true
}


# Scheduler / Processor

resource "aws_elb" "schd-elb" {
  name = "erdcAPISchd"

  # The same availability zone as our instances
  availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  security_groups       = ["${aws_security_group.processor.id}"]
  listener {
    instance_port     = 8786
    instance_protocol = "TCP"
    lb_port           = 8786
    lb_protocol       = "TCP"
  }

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 8787
    lb_protocol       = "HTTP"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8787/"
    interval            = 30
  }
}



data "template_file" "processor_config" {
  template = "${file("${path.module}/files/processor.bootstrap.tpl")}"
  vars {
    input_queue_name    = "${var.input_queue_name}"
    script              = "${file("../processor/process.py")}" # A better way might be to upload to s3 / pastebin and download.
  }
}

resource "aws_launch_configuration" "processor" {
  image_id           = "${data.aws_ami.conda.id}"
  instance_type = "t2.small"
  key_name      = "gateway"

  security_groups       = ["default", "${aws_security_group.processor.name}"]
  user_data = "${data.template_file.processor_config.rendered}"
  iam_instance_profile = "${var.iam_role["name"]}"
  
  root_block_device {
    volume_size = 30
  }

}

resource "aws_autoscaling_group" "processor" {
  name                  = "erdc_api_processor"
  availability_zones    = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  max_size              = 1
  min_size              = 1 # TODO: back to 0
  health_check_grace_period = 300
  health_check_type     = "EC2"
  force_delete          = true
  launch_configuration  = "${aws_launch_configuration.processor.name}"
  load_balancers       = ["${aws_elb.schd-elb.name}"]

  tag {
    key                 = "Name"
    value               = "erdc_api_processor"
    propagate_at_launch = true
  }
  tag {
    key                 = "Owner"
    value               = "theo.mccaie"
    propagate_at_launch  = true

  }
  tag {
    key                 = "EndOfLife"
    value               = "2017-07-30"
    propagate_at_launch = true

  }
}



# Worker

data "template_file" "worker_config" {
  template = "${file("${path.module}/files/worker.bootstrap.tpl")}"
  vars {
    scheduler_address = "${aws_elb.schd-elb.dns_name}:8786"
  }
}

resource "aws_launch_configuration" "erdc_dask_workers" {
  image_id              = "${data.aws_ami.conda.id}" 
  instance_type         = "t2.small"
  root_block_device = {
    volume_size = 80
  }

  key_name              = "gateway"
  user_data             = "${data.template_file.worker_config.rendered}"
  security_groups       = ["default", "${aws_security_group.processor.name}"] # TODO communicate with scheduler
}

resource "aws_autoscaling_group" "erdc_dask_workers" {
  name                  = "erdc_api_workers"
  availability_zones    = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  max_size              = 5
  min_size              = 1 # TODO: back to 0
  health_check_grace_period = 300
  health_check_type     = "EC2"
  force_delete          = true
  launch_configuration  = "${aws_launch_configuration.erdc_dask_workers.name}"
  tag {
    key                 = "Name"
    value               = "erdc_api_worker"
    propagate_at_launch = true
  }
  tag {
    key                 = "Owner"
    value               = "theo.mccaie"
    propagate_at_launch  = true

  }
  tag {
    key                 = "EndOfLife"
    value               = "2017-07-30"
    propagate_at_launch = true

  }
}

resource "aws_security_group" "processor" {
  name = "erdc_api_processor"
}

resource "aws_security_group" "sched_lb" {
  name = "erdc_scheduler_lb"
}


resource "aws_security_group_rule" "dashboard_incoming" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "http"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.sched_lb.id}"
}

resource "aws_security_group_rule" "processor_network_comms" {
  type        = "ingress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  self = true
  security_group_id = "${aws_security_group.sched_lb.id}"
}

 