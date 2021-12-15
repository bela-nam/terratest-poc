# load data source
data "azurerm_resource_group" "terratest_poc" {
  name = var.resource_group
}

# network
resource "azurerm_virtual_network" "terratest_poc-network" {
  name                = "terratest_poc-network"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.terratest_poc.location
  resource_group_name = data.azurerm_resource_group.terratest_poc.name
  tags                = merge(var.common_tags, { Name = "terratest_poc-network" })
}

# public subnet
resource "azurerm_subnet" "public" {
  name                 = "terratest_poc-public"
  resource_group_name  = data.azurerm_resource_group.terratest_poc.name
  virtual_network_name = azurerm_virtual_network.terratest_poc-network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# private subnet
resource "azurerm_subnet" "private" {
  name                 = "terratest_poc-private"
  resource_group_name  = data.azurerm_resource_group.terratest_poc.name
  virtual_network_name = azurerm_virtual_network.terratest_poc-network.name
  address_prefixes     = ["10.0.2.0/24"]
}

# NSGs and rules
resource "azurerm_network_security_group" "bastion_nsg" {
  name                = "terratest_poc-network-bastion_nsg"
  location            = data.azurerm_resource_group.terratest_poc.location
  resource_group_name = data.azurerm_resource_group.terratest_poc.name
  tags                = merge(var.common_tags, { Name = "terratest_poc-bastion_nsg" })

  # security_rule {
  #   name                       = "HTTP"
  #   priority                   = 1001
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "80"
  #   source_address_prefix      = "*"
  #   destination_address_prefix = "*"
  # }

  security_rule {
    name                       = "SSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "cluster_nsg" {
  name                = "terratest_poc-cluster_nsg"
  location            = data.azurerm_resource_group.terratest_poc.location
  resource_group_name = data.azurerm_resource_group.terratest_poc.name
  tags                = merge(var.common_tags, { Name = "terratest_poc-cluster_nsg" })

  security_rule {
    name                       = "HTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }
}

# VMs

# data "template_file" "cloudconfig" {
#   template = file("./cloud-init.txt")
# }
# data "template_cloudinit_config" "config" {
#   gzip          = true
#   base64_encode = true

#   part {
#     content_type = "text/cloud-config"
#     content      = templatefile("./cloud-init.txt")
#   }
# }

module "bastion" {
  source             = "./modules/vm"
  vm_count           = 1
  location           = data.azurerm_resource_group.terratest_poc.location
  resource_group     = data.azurerm_resource_group.terratest_poc.name
  subnet             = azurerm_subnet.public.id
  nsg                = azurerm_network_security_group.bastion_nsg.id
  username           = var.username
  ssh_public_key     = var.ssh_public_key
  vmtag              = "bastion"
  common_tags        = var.common_tags
  public_ip          = true
  vm_image_offer     = "RHEL"
  vm_image_publisher = "RedHat"
  vm_image_sku       = "7-LVM"
}

# availability set for our cluster
# only VMs in the same availability set can be added to the same backend address pool
resource "azurerm_availability_set" "terratest_poc-cluster_aset" {
  name                = "terratest_poc-cluster_aset"
  location            = data.azurerm_resource_group.terratest_poc.location
  resource_group_name = data.azurerm_resource_group.terratest_poc.name
  tags                = merge(var.common_tags, { Name = "terratest_poc-cluster_aset" })
}

module "cluster" {
  source              = "./modules/vm"
  vm_count            = var.cluster_vm_count
  location            = data.azurerm_resource_group.terratest_poc.location
  resource_group      = data.azurerm_resource_group.terratest_poc.name
  subnet              = azurerm_subnet.private.id
  nsg                 = azurerm_network_security_group.cluster_nsg.id
  username            = var.username
  ssh_public_key      = var.ssh_public_key
  vmtag               = "cluster"
  common_tags         = var.common_tags
  public_ip           = false
  custom_data         = filebase64("./httpd.sh")
  availability_set_id = azurerm_availability_set.terratest_poc-cluster_aset.id
  ip_config_name      = var.ip_config_name
}

resource "azurerm_public_ip" "terratest_poc-lb" {
  name                = "terratest_poc-lb_ip"
  location            = data.azurerm_resource_group.terratest_poc.location
  resource_group_name = data.azurerm_resource_group.terratest_poc.name
  allocation_method   = "Static"
  sku                 = "Basic" # Standard better for public IP ? 
  domain_name_label   = var.lb_domain_name_label
  tags                = merge(var.common_tags, { Name = "terratest_poc-lb_ip" })
}

# load balancer
resource "azurerm_lb" "terratest_poc-lb" {
  name                = "terratest_poc-lb"
  location            = data.azurerm_resource_group.terratest_poc.location
  resource_group_name = data.azurerm_resource_group.terratest_poc.name
  sku                 = "Basic"
  tags                = merge(var.common_tags, { Name = "terratest_poc-lb" })

  frontend_ip_configuration {
    name                 = var.frontend_ip_config
    public_ip_address_id = azurerm_public_ip.terratest_poc-lb.id
  }
}

resource "azurerm_lb_rule" "terratest_poc-lb" {
  resource_group_name            = data.azurerm_resource_group.terratest_poc.name
  loadbalancer_id                = azurerm_lb.terratest_poc-lb.id
  name                           = "terratest_poc-lb_rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = var.frontend_ip_config
  probe_id                       = azurerm_lb_probe.terratest_poc-lb.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.terratest_poc-lb.id]
}

resource "azurerm_lb_backend_address_pool" "terratest_poc-lb" {
  loadbalancer_id = azurerm_lb.terratest_poc-lb.id
  name            = "terratest_poc-lb_address_pool"
}

# this is for the 'sku = Standard' load balancer
# resource "azurerm_lb_backend_address_pool_address" "terratest_poc-lb" {
#   count                   = var.cluster_vm_count
#   name                    = "terratest_poc-lb_address_pool_address-${count.index}"
#   backend_address_pool_id = azurerm_lb_backend_address_pool.terratest_poc-lb.id
#   virtual_network_id      = azurerm_virtual_network.terratest_poc-network.id
#   ip_address              = module.cluster.private_ip[count.index]
# }

resource "azurerm_network_interface_backend_address_pool_association" "terratest_poc-lb" {
  count                   = var.cluster_vm_count
  network_interface_id    = module.cluster.network_interface_id[count.index]
  ip_configuration_name   = var.ip_config_name
  backend_address_pool_id = azurerm_lb_backend_address_pool.terratest_poc-lb.id
}

resource "azurerm_lb_probe" "terratest_poc-lb" {
  resource_group_name = data.azurerm_resource_group.terratest_poc.name
  loadbalancer_id     = azurerm_lb.terratest_poc-lb.id
  name                = "terratest_poc-lb_probe"
  port                = 80
  interval_in_seconds = 10
  number_of_probes    = 1
  protocol            = "Http"
  request_path        = "/"
}