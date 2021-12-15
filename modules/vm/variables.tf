variable "vm_count" {
  type    = number
  default = 1
}

variable "subnet" {
  type = string
}

variable "nsg" {
  type = string
}

variable "username" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "resource_group" {
  type = string
}

variable "location" {
  type = string
}

variable "custom_data" {
  type    = string
  default = null
}

variable "vmtag" {
  type    = string
  default = "generic_vm"
}

variable "common_tags" {
  type    = map(any)
  default = { Owner = "belannd" }
}

variable "public_ip" {
  type    = bool
  default = false
}

variable "availability_set_id" {
  type    = string
  default = null
}

variable "ip_config_name" {
  type    = string
  default = "ip_config_name"
}

variable "size" {
  type    = string
  default = "Standard_B1ls"
}

variable "vm_image_offer" {
  type    = string
  default = "UbuntuServer"
}

variable "vm_image_publisher" {
  type    = string
  default = "Canonical"
}

variable "vm_image_sku" {
  type    = string
  default = "18.04-LTS"
}

variable "vm_image_version" {
  type    = string
  default = "latest"
}