#Defining the resouce Group
resource "azurerm_resource_group" "RG" {
  name     = var.resourceaccountWin
  location = var.Location
}

#Create Virtual Network
resource "azurerm_virtual_network" "WinVirtualNetwork" {
  name                = "${random_pet.prefix.id}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
}

#Create Azure Subnet
resource "azurerm_subnet" "WinSubnet" {
  name                 = "${random_pet.prefix.id}-Subnet"
  virtual_network_name = azurerm_virtual_network.WinVirtualNetwork.name
  resource_group_name  = azurerm_resource_group.RG.name
  address_prefixes     = ["10.0.1.0/24"]
}

#Create Azure Network Interface
resource "azurerm_network_interface" "WinNetworkInterface" {
  name                = "${random_pet.prefix.id}-WinNetworkInterface"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.WinSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

#Create a Network Security Group & Rules
resource "azurerm_network_security_group" "WinNSG" {
  name                = "WinNSG"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#Create the security group to the network interface
resource "azurerm_network_interface_security_group_association" "WinNISG" {
  network_interface_id      = azurerm_network_interface.WinNetworkInterface.id
  network_security_group_id = azurerm_network_security_group.WinNSG.id
}
# Create storage account for boot diagnostics
resource "azurerm_storage_account" "WINStorageAccount" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.RG.location
  resource_group_name      = azurerm_resource_group.RG.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

#Create Virtual Machine
resource "azurerm_windows_virtual_machine" "VMWinServer" {
  name                  = "${random_pet.prefix.id}-VMWinServer"
  admin_username        = var.username
  admin_password        = random_password.password.result
  location              = azurerm_resource_group.RG.location
  resource_group_name   = azurerm_resource_group.RG.name
  network_interface_ids = [azurerm_network_interface.WinNetworkInterface.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOSDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.WINStorageAccount.primary_blob_endpoint
  }
}

#Install IIS web server to the Virtual Machine
resource "azurerm_virtual_machine_extension" "web_server_install" {
  name                       = "IIS-wsi"
  virtual_machine_id         = azurerm_windows_virtual_machine.VMWinServer.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
  {
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools"
  }
  SETTINGS 
}



# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.RG.name
  }
  byte_length = 8
}



resource "random_password" "password" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
  special     = true
}



resource "random_pet" "prefix" {
  prefix = var.prefix
  length = 1
}
