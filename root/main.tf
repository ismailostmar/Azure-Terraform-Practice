
resource "azurerm_resource_group" "myRG" {
  name     = var.resourceaccount
  location = var.location
}

#create virtual network
resource "azurerm_virtual_network" "network" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.myRG.location
  resource_group_name = azurerm_resource_group.myRG.name
}

#create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "mySubnet"
  virtual_network_name = azurerm_virtual_network.network.name
  resource_group_name  = azurerm_resource_group.myRG.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "linuxkey" {
  content  = tls_private_key.key.private_key_pem
  filename = "linuxkey.pem"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "networksg" {

  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.myRG.location
  resource_group_name = azurerm_resource_group.myRG.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "terraformNIC" {
  name                = "myNIC"
  location            = azurerm_resource_group.myRG.location
  resource_group_name = azurerm_resource_group.myRG.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.terraformNIC.id
  network_security_group_id = azurerm_network_security_group.networksg.id
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "my_terraform_vm" {
  name                  = "myVM"
  location              = azurerm_resource_group.myRG.location
  resource_group_name   = azurerm_resource_group.myRG.name
  network_interface_ids = [azurerm_network_interface.terraformNIC.id]
  size                  = "Standard_B1s"
  computer_name         = "hostname"
  admin_username        = var.username

  admin_ssh_key {
    username   = var.username
    public_key = tls_private_key.key.public_key_openssh
  }

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  depends_on = [azurerm_network_interface.terraformNIC,
    tls_private_key.key
  ]
}
