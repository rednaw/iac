# Official Docker approach: copy mise binary from official image then run mise install
# https://mise.jdx.dev/installing-mise.html#docker
FROM jdxcode/mise:latest AS mise

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies (BuildKit cache mounts for faster repeat builds)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y \
    curl \
    unzip \
    jq \
    gnupg \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Mise: copy binary from official image, then install tools from mise.toml
COPY --from=mise /usr/local/bin/mise /usr/local/bin/mise
ENV MISE_DATA_DIR=/opt/mise
ENV MISE_GLOBAL_CONFIG_FILE=/opt/mise/mise.toml
COPY mise.toml /opt/mise/mise.toml
RUN --mount=type=cache,target=/root/.cache/mise,sharing=locked \
    mise trust -a && mise install
ENV PATH="/opt/mise/shims:${PATH}"

# Ansible + ansible-lint from declarative requirements (venv, no pipx)
COPY requirements.txt /tmp/requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip,sharing=locked \
    python3 -m venv /opt/ansible-venv \
    && /opt/ansible-venv/bin/pip install --upgrade pip \
    && /opt/ansible-venv/bin/pip install -r /tmp/requirements.txt
ENV PATH="/opt/ansible-venv/bin:${PATH}"

# Task completions for bash
RUN mkdir -p /etc/bash_completion.d \
    && task --completion bash > /etc/bash_completion.d/task

# Cursor CLI (agent) for terminal-based agent runs inside the devcontainer
USER vscode
RUN curl -fsSL https://cursor.com/install | bash
USER root
# Ensure agent is on PATH for vscode (install script typically uses ~/.local/bin)
ENV PATH="/home/vscode/.local/bin:${PATH}"
