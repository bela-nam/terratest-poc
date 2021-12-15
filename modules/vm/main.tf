resource "azurerm_public_ip" "vm_public_ip" {
  count               = var.public_ip ? var.vm_count : 0
  name                = "${var.vmtag}-b1ls_vm_public_ip_name-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group
  allocation_method   = "Dynamic"
  domain_name_label   = "${var.vmtag}-${count.index}"
  tags                = merge(var.common_tags, { Name = join("-", [var.vmtag, "ip"]) })
}

resource "azurerm_network_interface" "vm_nic" {
  count                   = var.vm_count
  name                    = "${var.vmtag}-vm_nic-${count.index}"
  internal_dns_name_label = "${var.vmtag}-dnsname-${count.index}" # no underscore in the DNS name
  location                = var.location
  resource_group_name     = var.resource_group
  tags                    = merge(var.common_tags, { Name = join("-", [var.vmtag, "primary_network_interface"]) })

  ip_configuration {
    name                          = var.ip_config_name
    subnet_id                     = var.subnet
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip ? azurerm_public_ip.vm_public_ip[count.index].id : null
  }
}

resource "azurerm_network_interface_security_group_association" "vm_nsg_assoc" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.vm_nic[count.index].id
  network_security_group_id = var.nsg
}

resource "azurerm_linux_virtual_machine" "vm" {
  count                           = var.vm_count
  name                            = "${var.vmtag}-${count.index}"
  resource_group_name             = var.resource_group
  location                        = var.location
  size                            = var.size
  admin_username                  = var.username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.vm_nic[count.index].id]
  custom_data                     = var.custom_data
  tags                            = merge(var.common_tags, { Name = var.vmtag })
  availability_set_id             = var.availability_set_id
  allow_extension_operations      = false

  admin_ssh_key {
    username   = var.username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # source_image_reference {
  #   offer     = "RHEL"
  #   publisher = "RedHat"
  #   sku       = "7-LVM"
  #   version   = "latest"
  # }
  # source_image_reference {
  #   offer     = "UbuntuServer"
  #   publisher = "Canonical"
  #   sku       = "18.04-LTS"
  #   version   = "latest"
  # }
  source_image_reference {
    offer     = var.vm_image_offer
    publisher = var.vm_image_publisher
    sku       = var.vm_image_sku
    version   = var.vm_image_version
  }
}

output "public_ip" {
  value = azurerm_linux_virtual_machine.vm[*].public_ip_address
}

output "private_ip" {
  value = azurerm_linux_virtual_machine.vm[*].private_ip_address
}

output "network_interface_id" {
  value = azurerm_network_interface.vm_nic[*].id
}

output "fqdn" {
  value = azurerm_public_ip.vm_public_ip[*].fqdn
}

output "pubkey" {
  value = var.ssh_public_key
}

output "username" {
  value = var.username
}