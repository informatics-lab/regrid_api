data "template_file" "config" {
  template = "${file("localConfig.tpl")}"
  vars {
    value = "value"
  }
}

data "template_file" "worker_config" {
  template = "${file("files/cluster.bootstrap.tpl")}"
  vars {
    scheduler_address = "${aws_instance.erdc_api.private_ip}"
  }
}

###
### Network and security. Allow instances to talk over http.
###
resource "aws_security_group" "erdc_api" {
  name = "erdc_api"
}

data "aws_ami" "debian" {
  filter {
    name = "virtualization-type",
    values = ["hvm"]
  }
  filter {
    name = "name",
    values = ["debian-jessie-*"]
  }
  owners = ["379101102735"]
  most_recent = true
}

resource "aws_security_group_rule" "outbound" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.erdc_api.id}"
}


resource "aws_security_group_rule" "http_incoming" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.erdc_api.id}"
}

resource "aws_security_group_rule" "https_incoming" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.erdc_api.id}"
}

resource "aws_security_group_rule" "scheduler_dash_board" {
  type        = "ingress"
  from_port   = 8787
  to_port     = 8787
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.erdc_api.id}"
}

resource "aws_route53_record" "api" {
  zone_id = "Z3USS9SVLB2LY1"
  name = "${var.dns}."
  type = "A"
  ttl = "60"
  records = ["${aws_instance.erdc_api.public_ip}"]
}


###
### API end point instance
###


resource "aws_instance" "erdc_api" {
  ami           = "${data.aws_ami.debian.id}"
  instance_type = "t2.micro"
  key_name      = "gateway"
  security_groups = ["default", "${aws_security_group.erdc_api.name}"]
  iam_instance_profile = "${var.iam_profile}"
  
  user_data = "${file("./files/bootstrap.sh")}"
  
  root_block_device {
    volume_size = 30
  }

  tags {
    Name        = "erdc_api"
    Owner       = "theo.mccaie"
    EndOfLife   = "2017-08-01"
  }

  connection {
    type = "ssh"
    user = "admin"
    private_key = "${file("~/.ssh/gateway/id_rsa")}"
    bastion_host = "gateway.informaticslab.co.uk"
    bastion_user = "ec2-user"
    bastion_private_key = "${file("~/.ssh/id_rsa")}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir /opt/erdc_api",
      "sudo chown admin /opt/erdc_api",
    ]
  }

  provisioner "file" {
    source = "../"
    destination = "/opt/erdc_api"
  }

  provisioner "file" {
    content = "${data.template_file.config.rendered}"
    destination = "/opt/erdc_api/api/localConfig.json"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /opt/erdc_api/api/localConfig.json",
      "while [ ! -f /usr/local/bin/docker-compose ]; do sleep 20; done",
      "echo API_DNS=${var.dns} > /opt/erdc_api/.env",
      "cd /opt/erdc_api",
      "sudo /usr/bin/docker network create nginx-proxy",
      "sudo /usr/local/bin/docker-compose up -d"
    ]
  }
}




###
### Job queue and dask cluster
###


resource "aws_sqs_queue" "to_process_queue" {
  name = "${var.to_process_queue_name}"
  delay_seconds = 2
  redrive_policy = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.to_process_queue_dlq.arn}\",\"maxReceiveCount\":5}"
}


resource "aws_sqs_queue" "to_process_queue_dlq" {
  name = "DLQ-${var.to_process_queue_name}"
}



resource "aws_autoscaling_policy" "erdic_api_cluster_scale_up_on_pending_mesages" {
  name                   = "erdic_api_cluster_scale_up_on_pending_mesages"
  scaling_adjustment     = 3 # TODO: Be confident in the scaling adjustments
  adjustment_type        = "ExactCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.erdic_dask_workers.name}" 
}

resource "aws_autoscaling_policy" "erdic_api_cluster_scale_down_on_no_pending_mesages" {
  name                   = "erdic_api_cluster_scale_down_on_no_pending_mesages"
  scaling_adjustment     = 0 
  adjustment_type        = "ExactCapacity"
  cooldown               = 60 # TODO: Think about cool down, should one be just under an hour?
  autoscaling_group_name = "${aws_autoscaling_group.erdic_dask_workers.name}" 
}

resource "aws_cloudwatch_metric_alarm" "erdc_api_pending_messages" {
  alarm_name          = "erdc_api_pending_messages"
  dimensions          = {
    QueueName         = "${var.to_process_queue_name}"
  }
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"

  alarm_description = "This metric monitors the erdc api 'to process' queue length"
  alarm_actions     = ["${aws_autoscaling_policy.erdic_api_cluster_scale_up_on_pending_mesages.arn}"]
  ok_actions        = ["${aws_autoscaling_policy.erdic_api_cluster_scale_down_on_no_pending_mesages.arn}"]
}



resource "aws_launch_configuration" "erdic_dask_workers" {
  image_id              = "${data.aws_ami.debian.id}" # TODO: use a conda AMI?
  instance_type         = "t2.small"
  root_block_device = {
    volume_size = 80
  }

  key_name              = "gateway"
  user_data             = "${data.template_file.worker_config.rendered}"
  security_groups       = ["default", "${aws_security_group.dask_wokers.name}"] # TODO communicate with scheduler
}

resource "aws_autoscaling_group" "erdic_dask_workers" {
  name                  = "erdc_api_workers"
  availability_zones    = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  max_size              = 5
  min_size              = 0
  health_check_grace_period = 300
  health_check_type     = "EC2"
  force_delete          = true
  launch_configuration  = "${aws_launch_configuration.erdic_dask_workers.name}"

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

resource "aws_security_group" "dask_wokers" {
  name = "erdc_api_worker"
}

resource "aws_security_group_rule" "scheduler_incoming" {
  type        = "ingress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["${aws_instance.erdc_api.private_ip}/32"]

  security_group_id = "${aws_security_group.dask_wokers.id}"
}