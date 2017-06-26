data "template_file" "config" {
  template = "${file("localConfig.tpl")}"
  vars {
    value = "value"
  }
}

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

resource "aws_route53_record" "api" {
  zone_id = "Z3USS9SVLB2LY1"
  name = "${var.dns}."
  type = "A"
  ttl = "60"
  records = ["${aws_instance.erdc_api.public_ip}"]
}

resource "aws_instance" "erdc_api" {
  ami           = "${data.aws_ami.debian.id}"
  instance_type = "m3.large"
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
      "echo BOT_API_DNS=${var.dns} > /opt/erdc_api/.env",
      "cd /opt/erdc_api",
      "sudo /usr/bin/docker network create nginx-proxy",
      "sudo /usr/local/bin/docker-compose up -d"
    ]
  }
}
