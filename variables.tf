variable "aws_region" {
    description = "EC2 Region for the VPC"
    default = "eu-west-1"
}

variable "vpc_cidr" {
    description = "CIDR for the whole VPC"
    default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
    type = list
    description = "CIDR for the Public Subnet"
    default = ["10.0.0.0/24","10.0.1.0/24"]
}

variable "private_subnet_cidr" {
    description = "CIDR for the Private Subnet"
    default = "10.0.2.0/24"
}

variable "key_name" {
    default = "test"
}

variable "db_name" {
    default = "test"
}

variable "username" {
    default = "test"
}

variable "password" {
    default = "test"
}

variable "rds" {
    default = "test"
}
