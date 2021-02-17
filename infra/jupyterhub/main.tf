terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 2
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "jupyterhub" {
  name     = var.name_rg
  location = var.location
}

resource "azurerm_virtual_network" "jupyterhub" {
  name                = "${var.name}_vnet"
  depends_on          = [azurerm_resource_group.jupyterhub]
  location            = var.location
  resource_group_name = var.name_rg

  address_space = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "jupyterhub" {
  name                = "${var.name}_subnet"
  depends_on          = [azurerm_virtual_network.jupyterhub]
  resource_group_name = var.name_rg

  address_prefixes     = ["10.0.2.0/24"]
  virtual_network_name = azurerm_virtual_network.jupyterhub.name
}

resource "azurerm_public_ip" "jupyterhub" {
  name                = "${var.name}_public_ip"
  depends_on          = [azurerm_resource_group.jupyterhub]
  location            = var.location
  resource_group_name = var.name_rg

  allocation_method = "Dynamic"
}

// Get public ip
data "http" "personal_ip" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}

locals {
    depends_on = [data.http.personal_ip]
  personal_ip = jsondecode(data.http.personal_ip.body)
}

resource "azurerm_network_security_group" "jupyterhub" {
  name                = "${var.name}_nsg"
  depends_on          = [azurerm_resource_group.jupyterhub, local.personal_ip]
  location            = var.location
  resource_group_name = var.name_rg

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

  security_rule {
    name                       = "Browser"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "${local.personal_ip.ip}/32"
    destination_address_prefix = "*"
  }

}

// Create NIC to connect VM to IP, subnet and NSG
resource "azurerm_network_interface" "jupyterhub" {
  name                = "${var.name}_nic"
  depends_on          = [azurerm_resource_group.jupyterhub]
  location            = var.location
  resource_group_name = var.name_rg

  ip_configuration {
    name                          = "${var.name}_nic_configuration"
    subnet_id                     = azurerm_subnet.jupyterhub.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jupyterhub.id
  }
}

resource "azurerm_network_interface_security_group_association" "jupyterhub" {
  network_interface_id      = azurerm_network_interface.jupyterhub.id
  network_security_group_id = azurerm_network_security_group.jupyterhub.id
}

resource "azurerm_linux_virtual_machine" "jupyterhub" {
  name                = "${var.name}-${random_id.suffix.hex}"
  depends_on          = [azurerm_resource_group.jupyterhub, azurerm_network_interface.jupyterhub]
  location            = var.location
  resource_group_name = var.name_rg

  network_interface_ids = [azurerm_network_interface.jupyterhub.id]
  size                  = "Standard_B1s"

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
    public_key = file("${var.ssh_key_location}.pub")
  }
}

data "azurerm_public_ip" "ip_ref" {
  name                = "${var.name}_public_ip"
  depends_on          = [azurerm_public_ip.jupyterhub, azurerm_linux_virtual_machine.jupyterhub]
  resource_group_name = var.name_rg
}

resource "null_resource" "ansible" {
  depends_on = [data.azurerm_public_ip.ip_ref]
  provisioner "remote-exec" {
    inline = ["echo VM is configured"]
    connection {
      user        = "ansible"
      private_key = file(var.ssh_key_location)
      host        = data.azurerm_public_ip.ip_ref.ip_address
    }
  }

  provisioner "local-exec" {
    command = "ansible-playbook  --private-key ${var.ssh_key_location} -i '${data.azurerm_public_ip.ip_ref.ip_address},'  --skip-tags adduser ../../playbooks/jupyterhub/playbook.yaml"
  }
}