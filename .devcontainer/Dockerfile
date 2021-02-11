
# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.134.0/containers/python-3/.devcontainer/base.Dockerfile
FROM mcr.microsoft.com/vscode/devcontainers/python:3.9

ARG USERNAME=vscode

RUN mkdir -p /home/$USERNAME/.vscode-server/extensions \
    && chown -R $USERNAME \
        /home/$USERNAME/.vscode-server

# Access your local Docker install from inside a dev container. Installs Docker extension in the container along with needed CLIs.
# https://github.com/microsoft/vscode-dev-containers/tree/master/containers/docker-from-docker
COPY .devcontainer/library-scripts/docker-debian.sh /tmp/library-scripts/
RUN apt-get update && bash /tmp/library-scripts/docker-debian.sh
ENTRYPOINT ["/usr/local/share/docker-init.sh"]
CMD ["sleep", "infinity"]

# Install Terraform
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
  && rm -rf /var/lib/apt/lists/* \
  && wget --quiet https://releases.hashicorp.com/terraform/0.14.4/terraform_0.14.4_linux_amd64.zip \
  && unzip terraform_0.14.4_linux_amd64.zip \
  && mv terraform /usr/bin \
  && rm terraform_0.14.4_linux_amd64.zip

# Install Python and Ansible dependencies
COPY requirements.txt requirements-dev.txt /tmp/pip-tmp/
RUN pip3 --disable-pip-version-check --no-cache-dir install -r /tmp/pip-tmp/requirements-dev.txt \
    && rm -rf /tmp/pip-tmp \
    && ansible-galaxy collection install azure.azcollection
