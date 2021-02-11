terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

// Agent resource group
resource "azurerm_resource_group" "agents" {
  name     = var.prefix
  location = var.location
}

// Virtual network and subnet
resource "azurerm_virtual_network" "agent_network" {
  name                = "${var.prefix}_vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.agents.name
}

resource "azurerm_subnet" "agent_subnet" {
  name                 = "${var.prefix}_subnet"
  resource_group_name  = azurerm_resource_group.agents.name
  virtual_network_name = azurerm_virtual_network.agent_network.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "agent_ip" {
  name                = "${var.prefix}_public_ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.agents.name
  allocation_method   = "Dynamic"
}

// Create NSG
resource "azurerm_network_security_group" "agent_nsg" {
  name                = "${var.prefix}_nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.agents.name

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

// Create NIC to connect VM to IP, subnet and NSG
resource "azurerm_network_interface" "agent_nic" {
  name                = "${var.prefix}_nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.agents.name

  ip_configuration {
    name                          = "${var.prefix}_nic_configuration"
    subnet_id                     = azurerm_subnet.agent_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.agent_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "agent_nsg_nic" {
  network_interface_id      = azurerm_network_interface.agent_nic.id
  network_security_group_id = azurerm_network_security_group.agent_nsg.id
}

// Create VM
resource "azurerm_linux_virtual_machine" "agent" {
  name                  = var.prefix
  location              = var.location
  resource_group_name   = azurerm_resource_group.agents.name
  network_interface_ids = [azurerm_network_interface.agent_nic.id]
  size                  = "Standard_B1ls"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  admin_username                  = var.default_user
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.default_user
    public_key = file("~/.ssh/id_rsa.pub")
  }

  tags = {
    "${var.default_user}" = ""
  }

}
