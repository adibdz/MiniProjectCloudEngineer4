# terraform/variables.tf

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.100.0/24"
}

variable "ami_id" {
  description = "AMI ID to use for EC2 instances"
  type        = string
  default     = "ami-785db401"  # ubuntu 16.04
}

variable "http_server_count" {
  description = "How many private HTTP servers to create"
  type        = number
  default     = 2
}