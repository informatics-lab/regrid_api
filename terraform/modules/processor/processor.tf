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

resource "aws_autoscaling_policy" "scheduler_on" {
  name                   = "scheduler_on"
  scaling_adjustment     = 1 # TODO: Be confident in the scaling adjustments
  adjustment_type        = "ExactCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.scheduler.name}" 
}

resource "aws_autoscaling_policy" "scheduler_off" {
  name                   = "scheduler_off"
  scaling_adjustment     = 0 
  adjustment_type        = "ExactCapacity"
  cooldown               = 60 # TODO: Think about cool down, should one be just under an hour?
  autoscaling_group_name = "${aws_autoscaling_group.scheduler.name}" 
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
      "${aws_autoscaling_policy.scheduler_on.arn}"
  ]
  ok_actions        = [
      "${aws_autoscaling_policy.workers_off.arn}",
      "${aws_autoscaling_policy.scheduler_off.arn}"
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

# Security groups


resource "aws_security_group" "sched_lb" {
  name = "erdc_scheduler_lb"
}

resource "aws_security_group_rule" "lb_dashboard_incoming" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.sched_lb.id}"
}

resource "aws_security_group_rule" "workers_incoming" {
  type        = "ingress"
  from_port   = 8786
  to_port     = 8786
  protocol    = "tcp"
  source_security_group_id = "${aws_security_group.worker.id}"

  security_group_id = "${aws_security_group.sched_lb.id}"
}

resource "aws_security_group_rule" "load_balancer_out" {
  type        = "egress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.sched_lb.id}"
}



resource "aws_security_group" "scheduler" {
  name = "erdc_api_scheduler"
}
resource "aws_security_group_rule" "sched_dashboard" {
  type        = "ingress"
  from_port   = 8787
  to_port     = 8787
  protocol    = "tcp"
  source_security_group_id = "${aws_security_group.sched_lb.id}"

  security_group_id = "${aws_security_group.scheduler.id}"
}
resource "aws_security_group_rule" "sched_workers_inbound" {
  type        = "ingress"
  from_port   = 8786
  to_port     = 8786
  protocol    = "tcp"
  source_security_group_id = "${aws_security_group.sched_lb.id}"

  security_group_id = "${aws_security_group.scheduler.id}"
}


resource "aws_security_group" "worker" {
  name = "erdc_api_worker"
}
resource "aws_security_group_rule" "worker_allow_all_from_scheduler" {
  type        = "ingress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  source_security_group_id = "${aws_security_group.scheduler.id}"
  security_group_id = "${aws_security_group.worker.id}"
}
resource "aws_security_group_rule" "worker_all_outbound" {
  type        = "egress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.worker.id}"
}



# Scheduler

resource "aws_elb" "schd-elb-external" {
  name = "erdcAPISchdExt"

  # The same availability zone as our instances
  availability_zones  = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  security_groups     = ["${aws_security_group.sched_lb.id}"]

  

  listener {
    instance_port     = 8787
    instance_protocol = "tcp"
    lb_port           = 80
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8787/"
    interval            = 30
  }
}



resource "aws_elb" "schd-elb-internal" {
  name = "erdcAPISchdInt"

  # The same availability zone as our instances
  security_groups     = ["${aws_security_group.sched_lb.id}"]
  internal            = true
  subnets             = ["subnet-18da626f", "subnet-cd61f1a8"] # TODO: Don't hard code and don't use default?
  listener {
    instance_port     = 8786
    instance_protocol = "TCP"
    lb_port           = 8786
    lb_protocol       = "TCP"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8787/"
    interval            = 30
  }
}



data "template_file" "scheduler_config" {
  template = "${file("${path.module}/files/scheduler.bootstrap.tpl")}"
  vars {
    input_queue_name    = "${var.input_queue_name}"
    script              = "${file("../processor/process.py")}" # A better way might be to upload to s3 / pastebin and download.
    dask_ver            =  "${var.versions["dask"]}"
    distributed_ver     =  "${var.versions["distributed"]}"
    iris_ver           =  "${var.versions["iris"]}"
  }
}

resource "aws_launch_configuration" "scheduler" {
  image_id           = "${data.aws_ami.conda.id}"
  instance_type = "t2.small"
  key_name      = "gateway"

  security_groups       = ["default", "${aws_security_group.scheduler.name}"]
  user_data = "${data.template_file.scheduler_config.rendered}"
  iam_instance_profile = "${var.iam_role["name"]}"
  
  root_block_device {
    volume_size = 30
  }

}

resource "aws_autoscaling_group" "scheduler" {
  name                  = "erdc_api_scheduler"
  availability_zones    = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  max_size              = 1
  min_size              = 0 
  health_check_grace_period = 300
  health_check_type     = "EC2"
  force_delete          = true
  launch_configuration  = "${aws_launch_configuration.scheduler.name}"
  load_balancers       = ["${aws_elb.schd-elb-external.name}", "${aws_elb.schd-elb-internal.name}"]

  tag {
    key                 = "Name"
    value               = "erdc_api_scheduler"
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
    scheduler_address = "${aws_elb.schd-elb-internal.dns_name}"
    scheduler_port = "8786"
    dask_ver            =  "${var.versions["dask"]}"
    distributed_ver     =  "${var.versions["distributed"]}"
    iris_ver           =  "${var.versions["iris"]}"
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
  security_groups       = ["default", "${aws_security_group.worker.name}"]
}

resource "aws_autoscaling_group" "erdc_dask_workers" {
  name                  = "erdc_api_workers"
  availability_zones    = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  max_size              = 5
  min_size              = 0
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


 