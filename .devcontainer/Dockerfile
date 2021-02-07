
# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.134.0/containers/python-3/.devcontainer/base.Dockerfile
FROM mcr.microsoft.com/vscode/devcontainers/python:3.9

# Access your local Docker install from inside a dev container. Installs Docker extension in the container along with needed CLIs.
# https://github.com/microsoft/vscode-dev-containers/tree/master/containers/docker-from-docker
COPY .devcontainer/library-scripts/docker-debian.sh /tmp/library-scripts/
RUN apt-get update && bash /tmp/library-scripts/docker-debian.sh
ENTRYPOINT ["/usr/local/share/docker-init.sh"]
CMD ["sleep", "infinity"]

# Install Python dependencies
COPY requirements.txt requirements-dev.txt /tmp/pip-tmp/
RUN pip3 --disable-pip-version-check --no-cache-dir install -r /tmp/pip-tmp/requirements-dev.txt \
    && rm -rf /tmp/pip-tmp \
    && ansible-galaxy collection install azure.azcollection
