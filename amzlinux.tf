data "aws_ami" "awslinux" {
  most_recent      = true
  owners           = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

}


resource "aws_instance" "web" {
  ami           = data.aws_ami.awslinux.id 
  instance_type = "t3.small"
  count = 1

  user_data = "${file("nginx.sh")}"
  user_data_replace_on_change = true

#   key_name = "helloworld"

  security_groups = [aws_security_group.allow_all.name]

  tags = {
    Name = "HelloWorld"
  }
}


output "instances" {
  value       = "${aws_instance.web.*.public_ip}"
  description = "PublicIP address details"
}
