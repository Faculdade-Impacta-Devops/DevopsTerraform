# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0
# Fiap MBA SCJ

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.52.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
  }
  required_version = ">= 1.1.0"

  cloud {
    organization = "DevopsFiap"

    workspaces {
      name = "gh-actions"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "random_pet" "sg" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web-sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apache2
              sed -i -e 's/80/8080/' /etc/apache2/ports.conf
              echo "<style> body {background-color: black;}</style><img src="https://www.impacta.edu.br/themes/wc_agenciar3/images/banners/graduacao/2024/banner-desktop-vestibular-2024-1.png">" > /var/www/html/index.html
              systemctl restart apache2
              EOF
}

resource "aws_security_group" "web-sg" {
  name = "${random_pet.sg.id}-sg"
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  // connectivity to ubuntu mirrors is required to run `apt-get update` and `apt-get install apache2`
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_user" "new_user" {
  name = "example_user" # Nome do novo usuário

  tags = {
    Name = "User Impacta"
  }
}

resource "aws_iam_access_key" "new_user_access_key" {
  user = aws_iam_user.new_user.name

  # Garanta que as chaves de acesso sejam geradas apenas uma vez
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_user_policy_attachment" "new_user_policy_attachment" {
  user       = aws_iam_user.new_user.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess" # Política de exemplo (permissão de acesso total ao Amazon S3)
}

output "web-address" {
  value = "${aws_instance.web.public_dns}:8080"
}
