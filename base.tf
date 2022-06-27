variable "subscription_id"   { type = string }
variable "client_id"         { type = string }
variable "client_secret"     { type = string }
variable "tenant_id"         { type = string }
variable "location"          { type = string }
variable "tags"              { type = map }
variable "vm_size"           { type = string }
variable "vm_count"          { type = number }
variable "n_data_disk"       { type =  number }
variable "data_disk_size_gb" { type =  number }
variable "data_disk_type"    { type =  string }

resource "azurerm_resource_group" "vmgroup" {
    name     = "vm_rg"
    location = var.location
    tags     = var.tags
}

resource "azurerm_storage_account" "sa" {
    name =  "puzzlesa"
    resource_group_name = azurerm_resource_group.vmgroup.name
    location = var.location
    account_kind = "StorageV2"
    account_tier = "Standard"
    account_replication_type = "LRS"
    enable_https_traffic_only = true
    large_file_share_enabled  = false

    tags = var.tags
    depends_on = [azurerm_resource_group.vmgroup]
}

# Create vnet + subnets
module "network" {
  source              = "Azure/network/azurerm"
  resource_group_name = azurerm_resource_group.vmgroup.name
  address_spaces      = ["10.0.0.0/16"]
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  subnet_names        = ["subnet1", "subnet2", "subnet3"]

  subnet_service_endpoints = {}

  tags       = var.tags
  depends_on = [azurerm_resource_group.vmgroup]
}

module "linuxservers" {
  count                            = var.vm_count
  nb_instances                     = 1
  vm_hostname                      = "vm${count.index}"
  source                           = "Azure/compute/azurerm"
  resource_group_name              = azurerm_resource_group.vmgroup.name
  vm_os_publisher                  = "Canonical"
  vm_os_offer                      = "UbuntuServer"
  vm_os_sku                        = "18.04-LTS"
  vm_size                          = var.vm_size
  nb_data_disk                     = var.n_data_disk
  data_disk_size_gb                = var.data_disk_size_gb
  data_sa_type                     = var.data_disk_type
  public_ip_dns                    = ["ml${count.index}"]
  remote_port                      = "22"
  enable_ssh_key                   = true
  vnet_subnet_id                   = module.network.vnet_subnets[count.index]
  ssh_key_values                   = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCWNQkDtUSJXJzbOBaWK+tLmmXfYVBLnD9nYmHTDabI4JJ354Hy+256fAQXpjSG2CqoLGEEoRqUoKAUu+16W9uV6Je6wi9RKEG2FnV39EhdFaknHVLdSkkdwJTjvnindGk3pvtGQzKXT+cd9e2CI5gwO45YYSIudyYWMEXMRNOg0yC4ixYTdnDBJV/Py1+aEQZXBcHca81zUpzW2yGIyUUZZuDNOwnmC+n3axenkbKh/o6IiWAR8krVWmSjUh7NZyWklFlD8vPr5y/oohCBn5kM0SWYMkGyNe91QLjEwsjveJ+1fJLss5/wlmwoyPb3r1jgjXRYEfxNRxdvp1VfwdJ4Ck2hWhkMaI/+5QPmTnEEcbwyPihF0DWLFdk4MW/6M4a2gCnaR3ljFO9jJeyJBClywY2Tg2u8ap4KY0wo6AEBlW64e+nn1gZsCfx6SAG0zrZnMewjk1ttKA6SfEAiXWdGnPsaVIxfUGGh2ujv59fB3Uo5Bdj6av1RWpME1d1+u4PIeShpwlKVhWKqKB1Z76VLSFyWSYlMdu7ScPl6Ef9xqpNUBQqCpQjKB9fSM/NQBhJYqzYNfcnNoBAV1flt72AqDDb65ui/T8rdFyZgAkkJCMseyPAHWjB1kJ15d0ctv29QhaGKg+c6ZkjOqVcP1p0dWvN5Siwzj+e4vDsU3dUCYQ=="]
  delete_data_disks_on_termination = true

  custom_data = base64encode(data.local_file.cloudinit.content)
  tags        = var.tags
  depends_on  = [azurerm_resource_group.vmgroup]
}

data "local_file" "cloudinit" {
    filename = "${path.module}/cloud-init.conf"
}

# resource "azurerm_dev_test_global_vm_shutdown_schedule" "shutdown" {
#   virtual_machine_id    = 
#   location              = var.location
#   enabled               = true
#   daily_recurrence_time = "0000"
#   timezone              = "W. Europe Standard Time"

#   notification_settings {
#     enabled         = true
#     time_in_minutes = "60"
#     email           = "joe@average.com"
#     webhook_url     = "https://sample-webhook-url.example.com"
#   }
# }
