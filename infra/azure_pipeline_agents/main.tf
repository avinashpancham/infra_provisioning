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

resource "azurerm_resource_group" "agents" {
  name     = var.name_rg
  location = var.location
}

resource "azurerm_virtual_network" "agents" {
  name                = "${var.name}_vnet"
  resource_group_name = var.name_rg
  depends_on          = [azurerm_resource_group.agents]
  address_space       = ["10.0.0.0/16"]
  location            = var.location
}

resource "azurerm_subnet" "agents" {
  name                 = "${var.name}_subnet"
  resource_group_name  = var.name_rg
  depends_on           = [azurerm_virtual_network.agents]
  address_prefixes     = ["10.0.2.0/24"]
  virtual_network_name = azurerm_virtual_network.agents.name
}

resource "azurerm_network_security_group" "agents" {
  name                = "${var.name}_nsg"
  resource_group_name = var.name_rg
  depends_on          = [azurerm_resource_group.agents]
  location            = var.location

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

resource "azurerm_linux_virtual_machine_scale_set" "agents" {
  name                = "${var.name}-${random_id.suffix.hex}"
  resource_group_name = var.name_rg
  depends_on          = [azurerm_network_security_group.agents]
  admin_username      = var.default_user
  instances           = var.instances
  location            = var.location
  sku                 = "Standard_B1ls"

  admin_ssh_key {
    username   = var.default_user
    public_key = file("${var.ssh_key_location}.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    // Add VMs to NSG
    name                      = "${var.name}_nic"
    primary                   = true
    network_security_group_id = azurerm_network_security_group.agents.id

    ip_configuration {
      name      = "public-ip"
      primary   = true
      subnet_id = azurerm_subnet.agents.id

      public_ip_address {
        name = "${var.name}_public_ip"
      }
    }
  }
}

// Retrieve Azure VM SS IPs via Azure CLI. Terraform cannot retrieve them
data "external" "ip" {
  depends_on = [azurerm_linux_virtual_machine_scale_set.agents]
  program = ["sh", "-c",
  "az vmss list-instance-public-ips -g ${var.name_rg} -n ${var.name}-${random_id.suffix.hex} |  jq 'map( { (.ipAddress): .ipAddress } ) | add'"]
}

// Configure VMs with Ansible. 
// First to a remote-exec so that we are sure the VM is configured once we run Ansible
resource "null_resource" "ansible" {
  depends_on = [data.external.ip]
  count      = var.instances

  provisioner "remote-exec" {
    inline = ["echo VM is configured"]
    connection {
      user        = var.default_user
      private_key = file(var.ssh_key_location)
      host        = keys(data.external.ip.result)[count.index]
    }
  }

  provisioner "local-exec" {
    command = "ansible-playbook  --private-key ${var.ssh_key_location} -i '${keys(data.external.ip.result)[count.index]},'  ../../playbooks/azure_pipeline_agents/playbook.yaml"
  }
}