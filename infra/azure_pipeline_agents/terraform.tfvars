default_user             = "ansible"
instances                = 2
instance_size            = "Standard_B2s"
location                 = "westeurope"
name                     = "agents"
name_rg                  = "agents_rg"
ssh_key_location         = "~/.ssh/id_rsa-ansible"
whitelisted_ip_addresses = [""]
