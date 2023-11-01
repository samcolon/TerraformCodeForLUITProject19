variable "region" {
  description = "AWS region to launch infrastructure"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR blocks for the two subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "ami_id" {
  description = "AMI ID for the EC2 instances"
  default     = "ami-0fc5d935ebf8bc3bc"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "holidaygifts_user_data_file" {
  description = "Path to the user data file for bootstrapping the Apache EC2 instance"
  type        = string
  default     = "holidaygifts_userdata.sh"
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  default     = "holidaygifts-prod"

}