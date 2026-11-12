variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "container_image" {
  type    = string
  default = "nginx:alpine"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}

variable "desired_count" {
  type = number
}

variable "db_host" {
  type = string
}

variable "db_name" {
  type = string
}
