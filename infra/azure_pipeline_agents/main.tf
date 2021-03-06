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
  depends_on          = [azurerm_resource_group.agents]
  location            = var.location
  resource_group_name = var.name_rg

  address_space = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "agents" {
  name                = "${var.name}_subnet"
  depends_on          = [azurerm_virtual_network.agents]
  resource_group_name = var.name_rg

  address_prefixes     = ["10.0.2.0/24"]
  virtual_network_name = azurerm_virtual_network.agents.name
}

// Get public ip of the current device
data "http" "personal_ip" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}

locals {
  depends_on  = [data.http.personal_ip]
  personal_ip = jsondecode(data.http.personal_ip.body)
}

resource "azurerm_network_security_group" "agents" {
  name                = "${var.name}_nsg"
  depends_on          = [azurerm_resource_group.agents, local.personal_ip]
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
    source_address_prefixes    = compact(concat(["${local.personal_ip.ip}/32"], var.whitelisted_ip_addresses))
    destination_address_prefix = "*"
  }
}

resource "azurerm_storage_account" "agents" {
  name                = "${var.name}${random_id.suffix.hex}"
  depends_on          = [azurerm_resource_group.agents]
  location            = var.location
  resource_group_name = var.name_rg

  account_replication_type = "LRS"
  account_tier             = "Standard"
}

resource "azurerm_linux_virtual_machine_scale_set" "agents" {
  name                = "${var.name}-${random_id.suffix.hex}"
  depends_on          = [azurerm_network_security_group.agents, azurerm_storage_account.agents]
  location            = var.location
  resource_group_name = var.name_rg

  admin_username = var.default_user
  instances      = var.instances
  sku            = var.instance_size

  admin_ssh_key {
    username   = var.default_user
    public_key = file("${var.ssh_key_location}.pub")
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.agents.primary_blob_endpoint
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

  tags = {
    "${var.default_user}" = var.name
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
    command = "ansible-playbook -i '${keys(data.external.ip.result)[count.index]},'  ../../playbooks/azure_pipeline_agents/playbook.yaml"
  }
}