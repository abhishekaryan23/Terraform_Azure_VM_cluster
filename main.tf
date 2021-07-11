# Creating the resource group

resource "azurerm_resource_group" "vm-cluster-test" {
 name     = "vm-cluster-test"
 location = var.location
}

# Creating Virtual Network for the VMs

resource "azurerm_virtual_network" "vn-4-clustertest" {
 name                = "vn-4-clustertest"
 address_space       = ["10.0.0.0/16"]
 location            = azurerm_resource_group.vm-cluster-test.location
 resource_group_name = azurerm_resource_group.vm-cluster-test.name
}

# Creating subnets inside the Virtaul network

resource "azurerm_subnet" "subnet4clustertest" {
 name                 = "acctsub"
 resource_group_name  = azurerm_resource_group.vm-cluster-test.name
 virtual_network_name = azurerm_virtual_network.vn-4-clustertest.name
 address_prefix      = "10.0.2.0/24"
}

# Crating Public IP for VMs

resource "azurerm_public_ip" "public-ip-4-clustertest" {
 name                         = "publicIPForLB"
 location                     = azurerm_resource_group.vm-cluster-test.location
 resource_group_name          = azurerm_resource_group.vm-cluster-test.name
 allocation_method            = "Static"
}

# Creating Loadbalancer

resource "azurerm_lb" "lb-4-clustertest" {
 name                = "loadBalancer"
 location            = azurerm_resource_group.vm-cluster-test.location
 resource_group_name = azurerm_resource_group.vm-cluster-test.name

 frontend_ip_configuration {
   name                 = "publicIPAddress"
   public_ip_address_id = azurerm_public_ip.public-ip-4-clustertest.id
 }
}

# Creating Backend addresspool for loadbalancer

resource "azurerm_lb_backend_address_pool" "lb-bknd-pool" {
 resource_group_name = azurerm_resource_group.vm-cluster-test.name
 loadbalancer_id     = azurerm_lb.lb-4-clustertest.id
 name                = "BackEndAddressPool"
}

# Creating network interface Configuration

resource "azurerm_network_interface" "netintfs" {
 count               = 2
 name                = "acctni${count.index}"
 location            = azurerm_resource_group.vm-cluster-test.location
 resource_group_name = azurerm_resource_group.vm-cluster-test.name

 ip_configuration {
   name                          = "testConfiguration"
   subnet_id                     = azurerm_subnet.subnet4clustertest.id
   private_ip_address_allocation = "dynamic"
 }
}

# Creating disks for VM.

resource "azurerm_managed_disk" "md4clustertest" {
 count                = 2
 name                 = "datadisk_existing_${count.index}"
 location             = azurerm_resource_group.vm-cluster-test.location
 resource_group_name  = azurerm_resource_group.vm-cluster-test.name
 storage_account_type = "Standard_LRS"
 create_option        = "Empty"
 disk_size_gb         = "50"
}

# Creating Availabiliy set

resource "azurerm_availability_set" "avset-4-clustertest" {
 name                         = "avset"
 location                     = azurerm_resource_group.vm-cluster-test.location
 resource_group_name          = azurerm_resource_group.vm-cluster-test.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

# Creating the VMs

resource "azurerm_virtual_machine" "vms-4-clustertest" {
 count                 = 2
 name                  = "acctvm${count.index}"
 location              = azurerm_resource_group.vm-cluster-test.location
 availability_set_id   = azurerm_availability_set.avset-4-clustertest.id
 resource_group_name   = azurerm_resource_group.vm-cluster-test.name
 network_interface_ids = [element(azurerm_network_interface.netintfs.*.id, count.index)]
 vm_size               = "Standard_DS1_v2"

 # Uncomment this line to delete the OS disk automatically when deleting the VM
 delete_os_disk_on_termination = true

 # Uncomment this line to delete the data disks automatically when deleting the VM
 delete_data_disks_on_termination = true

 storage_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "18.04-LTS"
   version   = "latest"
 }

 storage_os_disk {
   name              = "myosdisk${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 # Optional data disks
 storage_data_disk {
   name              = "datadisk_new_${count.index}"
   managed_disk_type = "Standard_LRS"
   create_option     = "Empty"
   lun               = 0
   disk_size_gb      = "10"
 }

 storage_data_disk {
   name            = element(azurerm_managed_disk.md4clustertest.*.name, count.index)
   managed_disk_id = element(azurerm_managed_disk.md4clustertest.*.id, count.index)
   create_option   = "Attach"
   lun             = 1
   disk_size_gb    = element(azurerm_managed_disk.md4clustertest.*.disk_size_gb, count.index)
 }

 os_profile {
   computer_name  = var.hostname
   admin_username = var.admin_username
   admin_password = var.admin_password
 }

 os_profile_linux_config {
   disable_password_authentication = false
 }

 tags = {
   environment = "staging"
 }
}