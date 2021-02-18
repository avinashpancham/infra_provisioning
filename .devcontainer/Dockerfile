# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.134.0/containers/python-3/.devcontainer/base.Dockerfile
FROM mcr.microsoft.com/vscode/devcontainers/python:3.9

ARG USERNAME=vscode

RUN mkdir -p /home/$USERNAME/.vscode-server/extensions \
            /home/$USERNAME/.cache/pre-commit/ \
    && chown -R $USERNAME \
        /home/$USERNAME/.vscode-server \
        /home/$USERNAME/.cache/pre-commit/

# Install Terraform
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
  && rm -rf /var/lib/apt/lists/* \
  && wget --quiet https://releases.hashicorp.com/terraform/0.14.4/terraform_0.14.4_linux_amd64.zip \
  && unzip terraform_0.14.4_linux_amd64.zip \
  && mv terraform /usr/bin \
  && rm -rf terraform_0.14.4_linux_amd64.zip

# Install Python and Python package (a.o. Ansible)
COPY requirements.txt requirements-dev.txt /tmp/pip-tmp/
RUN pip3 --disable-pip-version-check --no-cache-dir install -r /tmp/pip-tmp/requirements-dev.txt \
    && rm -rf /tmp/pip-tmp \
    && ansible-galaxy collection install azure.azcollection