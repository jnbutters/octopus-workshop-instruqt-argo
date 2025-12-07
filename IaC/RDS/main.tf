###############################################
# TERRAFORM: FULLY SELF-CONTAINED RDS SQLSERVER
###############################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2" # London
}

###############################################
# RANDOM VALUES (NO USER INPUT)
###############################################

resource "random_pet" "db_name" {
  length = 2
}

resource "random_string" "username" {
  length  = 8
  upper   = false
  special = false
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@#!"
}

###############################################
# VPC + SUBNETS + INTERNET + ROUTING
###############################################

resource "aws_vpc" "main" {
  cidr_block = "10.10.0.0/16"
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.rt.id
}

###############################################
# SECURITY GROUP – ALLOW SQLSERVER (1433)
###############################################

resource "aws_security_group" "sql_sg" {
  name        = "sql-server-sg"
  description = "Allow SQL Server access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # unrestricted since you don't care
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###############################################
# RDS SUBNET GROUP
###############################################

resource "aws_db_subnet_group" "sql_subnets" {
  name       = "rds-subnet-group"
  subnet_ids = [
    aws_subnet.subnet_a.id,
    aws_subnet.subnet_b.id
  ]
}

###############################################
# RDS SQL SERVER EXPRESS (FREE TIER)
###############################################

resource "aws_db_instance" "sqlserver" {
  identifier               = random_pet.db_name.id
  engine                   = "sqlserver-ex"
  instance_class           = "db.t3.micro"
  allocated_storage        = 20

  username = random_string.username.result
  password = random_password.password.result

  db_subnet_group_name   = aws_db_subnet_group.sql_subnets.name
  vpc_security_group_ids = [aws_security_group.sql_sg.id]

  publicly_accessible = true
  skip_final_snapshot = true
}

###############################################
# OUTPUTS
###############################################

output "rds_host" {
  value = aws_db_instance.sqlserver.address
}

output "rds_port" {
  value = aws_db_instance.sqlserver.port
}

output "username" {
  value = random_string.username.result
}

output "password" {
  value     = random_password.password.result
  sensitive = true
}

output "database_identifier" {
  value = random_pet.db_name.id
}
