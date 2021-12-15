output "bastion-fqdn" {
  value = module.bastion.fqdn[*]
}

output "bastion-public_ip" {
  value = module.bastion.public_ip[*]
}

output "bastion-private_ip" {
  value = module.bastion.private_ip[*]
}

output "cluster-private_ip" {
  value = module.cluster.private_ip[*]
}

output "load_balancer-public_ip" {
  value = azurerm_public_ip.terratest_poc-lb.ip_address
}

output "load_balancer-fqdn" {
  value = azurerm_public_ip.terratest_poc-lb.fqdn
}