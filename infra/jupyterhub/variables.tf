variable "default_user" {
  type        = string
  description = "Default user of the VMs"
}

variable "instance_size" {
  type        = string
  description = "The size of the VM, see 'az vm list-sizes -l westeurope -o table' for an overview"
}

variable "location" {
  type        = string
  description = "Datacenter to provision VMs, see 'az account list-locations -o table' for an overview"
}

variable "name" {
  type        = string
  description = "Default prefix for Azure components"
}

variable "name_rg" {
  type        = string
  description = "Name or Azure resource groups where everything will be stored"
}

variable "ssh_key_location" {
  type        = string
  description = "SSH key pair that should be used"
}

variable "whitelisted_ip_addresses" {
  type        = list(string)
  default     = [""]
  description = "Whitelisted IP addresses that can connect to the VM"
}
