variable "region_1" {
  description = "Primary AWS region"
  type        = string
}

variable "region_2" {
  description = "Secondary AWS region"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name_region_1" {
  description = "Key pair name in region 1"
  type        = string
}

variable "key_name_region_2" {
  description = "Key pair name in region 2"
  type        = string
}
