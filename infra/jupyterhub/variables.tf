variable "default_user" {
  type        = string
  description = "Default user of the VMs"
}

variable "instances" {
  type        = number
  default     = 1
  description = "Number of VMs in the scale set"
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