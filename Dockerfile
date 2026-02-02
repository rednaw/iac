FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    jq \
    gnupg \
    python3 \
    python3-pip \
    python3-venv \
    python3-yaml \
    pipx \
    bc \
    && rm -rf /var/lib/apt/lists/*

# Install aqua (manages terraform, sops, age, yq, task, crane, hcloud, etc.)
ENV AQUA_ROOT_DIR=/opt/aqua
RUN curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v3.0.1/aqua-installer | bash -s -- -v v2.28.0
ENV PATH="${AQUA_ROOT_DIR}/bin:$PATH"

COPY aqua.yaml ${AQUA_ROOT_DIR}/aqua.yaml
ENV AQUA_GLOBAL_CONFIG=${AQUA_ROOT_DIR}/aqua.yaml
RUN aqua install --all

# Ansible via pipx (isolated from system Python)
ENV PIPX_HOME=/opt/pipx
ENV PIPX_BIN_DIR=/usr/local/bin
RUN pipx install ansible --include-deps \
    && pipx install ansible-lint

# Task completions for bash
RUN mkdir -p /etc/bash_completion.d \
    && task --completion bash > /etc/bash_completion.d/task

# Cursor CLI (agent) for terminal-based agent runs inside the devcontainer
USER vscode
RUN curl -fsSL https://cursor.com/install | bash
USER root
# Ensure agent is on PATH for vscode (install script typically uses ~/.local/bin)
ENV PATH="/home/vscode/.local/bin:${PATH}"
