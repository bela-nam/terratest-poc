variable "ssh_public_key" {
  type = string
}

variable "cluster_vm_count" {
  type    = number
  default = 2
}

variable "common_tags" {
  type = map(any)
  default = {
    Owner       = "belannd"
    Project     = "terratest_poc"
    Provisioner = "Terraform"
  }
}

variable "resource_group" {
  type = string
}

variable "ip_config_name" {
  type    = string
  default = "ip_config_name"
}

variable "frontend_ip_config" {
  type    = string
  default = "frontend_ip_config"
}

variable "username" {
  type    = string
  default = "belannd"
}

variable "lb_domain_name_label" {
  type    = string
  default = "terratest-poc-lb"
}