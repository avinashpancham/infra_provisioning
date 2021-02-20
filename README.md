# Infra provisioning

'Pets versus cattle' is an important Devops concept when it comes to handling infrastructure. 
This difference is clearly demonstrated in the case of server issues (i.e. animal becomes sick).

- In the pets service model, servers with issues are taken care of till they are healthy again ('becomes better');
- In the cattle service model, servers with issues are immediately killed and replaced by new, healthy servers.

The elasticity of the cloud enables us to adopt the cattle service model and treat servers as disposable. 
Though in order to make this service model work, we cannot rely on manually provisioning the hardware and software of the
new server. This is too labour intensive and error prone. An automated workflow is needed to provision the 
infrastructure: Infrastructure as Code (IaC).

## Infrastructure as Code

IaC can generally be split in two parts:

- Configuration/cloud orchestration: the provisioning of the hardware of the server;
- Configuration management: the provisioning of the software on the server.

[Terraform](https://www.terraform.io/) is the most popular tool for configuration orchestration, whereas 
[Chef](https://www.chef.io/), [Puppet](https://puppet.com/) and [Ansible](https://www.ansible.com/) are common choices for configuration management. It should be noted that the configuration orchestration
tools can be used for simple configuration management and vice versa, but it is always better to use the right tool for the job.
In this project we will use a combination of Terraform (for configuration orchestration) and Ansible (for configuration management) to generate two IaC workflows:

- Self-hosted [Azure Pipeline agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/agents?view=azure-devops&tabs=browser) on Azure VM scale sets;
- [Jupyterhub](https://jupyterhub.readthedocs.io/en/stable/#) server on a Azure VM.

## Dependencies

For this project the preferred setup makes use of [VScode's remote container](https://code.visualstudio.com/docs/remote/containers)
extension. This extension lets you use a Docker container as a full-featured development environment. The dependencies list is therefore pretty short:

- Azure subscription;
- [Docker](https://docs.docker.com/get-docker/);
- [VScode IDE](https://code.visualstudio.com/download) with the remote container extension.


In case it is not possible to use VScode's remote container extension, all the necessary software should be installed manually.
Below a list of dependencies together with the version used in this project is given:

- Azure subscription;
- [Ansible Azure azcollection](https://galaxy.ansible.com/azure/azcollection) (1.4.0);
- [jq](https://stedolan.github.io/jq/) (1.5);
- [Python](https://www.python.org/) (3.9);
- Third party Python packages:
    - [Ansible](https://pypi.org/project/ansible/) (3.0.0);
    - [Azure CLI](https://pypi.org/project/azure-cli/) (2.18.0);
    - [Pre-commit](https://pypi.org/project/pre-commit/) (optional, 2.10.0);
- [Terraform](https://www.terraform.io/downloads.html) (0.14.4).


## Setup

1. Clone the repository.

2. Create an Azure account and an Azure subscription.

3. Install all the dependencies mentioned in the `Dependencies` section via VScode's remote container extension or by installing all the dependencies manually.

4. Authenticate your device to Azure such that Terraform can create resources using your Azure subscription. This can be done in multiple ways:

- Azure CLI: this is the preferred authentication method for this project and is achieved by logging in via the command line. The detailed instructions to set this type of authentication up are available in the Terraform [documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli);

   ```bash
   $ az login
   ```

- Service Principal: this is the recommended method when automating Terraform in a non-interactive environment such as a CI/CD pipeline. The instructions to set this type of authentication up are available in the Terraform [documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret).

5. Create a specific SSH key for Ansible.

   ```bash
   $ ssh-keygen -t rsa -f ~/.ssh/id_rsa-ansible -N ""
   ```
## Workflows

### *Self-hosted [Azure Pipeline agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/agents?view=azure-devops&tabs=browser) on Azure VM scale sets*

Self-hosted Azure DevOps agents are VMs that acts as agent/runner in Azure Pipelines. These type of agents provide a number of advantages over Microsoft-hosted agents, such as more control of the installed software and machine-level caching. The instructions on how to set up a VM as Azure DevOps agent are available in the Azure DevOps [documentation](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops). Here an Azure VM scale set (i.e. cluster of similar VMs) with two VMs is chosen.


1. If you do not yet have an Organisation in [Azure DevOps](https://dev.azure.com), then create an Organisation through the instructions in the Azure DevOps [documentation](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/create-organization?view=azure-devops#create-an-organization).
   
2. Create a Private Access Token (PAT) for your Organization that has the authorizations:
   
   - Agents Pools (Read and Manage);
   - Code (Full and Status). 

   Instructions on how to create a PAT are available in the Azure DevOps [documentation](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page#create-a-pat). Do not forget to copy and save the PAT after creating it!

3. Create the directory `roles/azure_pipeline_agents/vars`.

   ```bash
   # Run this command from the directory infra_provisioning
   $ mkdir roles/azure_pipeline_agents/vars
   ```

4. Add the file `secrets.yaml` in `roles/azure_pipeline_agents/vars`. It should contain the earlier made Azure DevOps PAT and Organization URL, so that the Azure pipeline agent can connect to the Azure DevOps Organisation.

   ```yaml
   # secrets.yaml
   ado_token: YOUR_PAT
   ado_url: https://dev.azure.com/YOUR_ORGANIZATION_NAME
   ```
 
5. Navigate to the directory `infra/azure_pipeline_agents`.
   
   ```bash
   # Run this command from the directory infra_provisioning
   $ cd infra/azure_pipeline_agents
   ```

6. The first time Terraform should be initialized in order to download all the necessary Terraform modules.

   ```bash
   # Run this command from the directory infra_provisioning/infra/azure_pipeline_agents
   $ terraform init
   ```

7. Check and run the Terraform workflow. This should start:
   - The Terraform script [`infra/azure_pipeline_agents/main.tf`](infra/azure_pipeline_agents/main.tf) to create an Azure VM scale set;
   - The Ansible playbook [`infra/azure_pipeline_agents/playbook.yaml`](playbooks/azure_pipeline_agents/playbook.yaml) to provision the software on the created VMs.

   The variables for this workflow (a.o. instance size) are defined in [`infra/azure_pipeline_agents/terraform.tfvars`](infra/azure_pipeline_agents/terraform.tfvars).

   ```bash
   # Run these commands from the directory infra_provisioning/infra/azure_pipeline_agents
   $ terraform plan  # check workflow
   $ terraform apply  # start workflow
   ```

8.  After a few minutes you should find the new Azure Pipeline agents in your Azure DevOps organisation at `https://dev.azure.com/YOUR_ORGANIZATION_NAME/_settings/agentpools?poolId=1&view=agents` 

### *[Jupyterhub](https://jupyterhub.readthedocs.io/en/stable/#) server on a Azure VM*

JupyterHub is the best way to serve Jupyter notebook for multiple users on a server. The instructions on how to set up a VM as a Jupyterhub server are available in the Jupyterhub [documentation](https://jupyterhub.readthedocs.io/en/stable/installation-guide-hard.html). Here an Azure VM is chosen.

1. Create the directory `roles/regular_user/vars`.

   ```bash
   # Run this command from the directory infra_provisioning
   $ mkdir roles/regular_user/vars
   ```

2. Add the file `secrets.yaml` in `roles/regular_user/vars`. It should contain the `default_password` for newly created users.

   ```yaml
   # secrets.yaml
   default_password: changeme
   ```

3. Navigate to the directory `infra/jupyterhub`.
   
   ```bash
   # Run this command from the directory infra_provisioning
   $ cd infra/jupyterhub
   ```

4. The first time Terraform should be initialized in order to download all the necessary Terraform modules.

   ```bash
   # Run this command from the directory infra_provisioning/infra/jupyterhub
   $ terraform init
   ```

5. Check and run the Terraform workflow. This should start:
   - The Terraform script [`infra/jupyterhub/main.tf`](infra/jupyterhub/main.tf) to create an Azure VM;
   - The Ansible playbook [`infra/jupyterhub/playbook.yaml`](playbooks/jupyterhub/playbook.yaml) to provision the software on the created VM.

   The variables for this workflow (a.o. instance size) are defined in [`infra/jupyterhub/terraform.tfvars`](infra/jupyterhub/terraform.tfvars).

   ```bash
   # Run these commands from the directory infra_provisioning/infra/jupyterhub
   $ terraform plan  # check workflow
   $ terraform apply  # start workflow
   ```

6.  After a few minutes the Jupyterhub server is availabe at `http://YOUR_IP_ADDRESS/jupyter`. The default user is `jupyter` and has the default password specified in step 2.
   
7. Adding new users is arranged via the same Ansible playbook, but by only running the tasks with the tag `add_user`. The example below adds the users `foo` and `bar` who can login with the default password.

   ```bash
   # Run these commands from the directory infra_provisioning/playbooks/jupyterhub
   $ ansible-playbook -i inventory/azure_rm.yaml playbook.yaml --tags add_user --e '{"new_users":["foo","bar"]}'

   ```
