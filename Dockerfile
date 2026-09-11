FROM jenkins/jenkins:lts

USER root

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    python3 \
    python3-pip

# Installation du binaire Docker Compose
RUN curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

# Installation du client Docker
RUN curl -fsSL https://get.docker.com | sh

# Installation automatique des plugins Jenkins (Pipeline, Git, Docker, etc.)
RUN jenkins-plugin-cli --plugins \
    workflow-aggregator \
    docker-workflow \
    git \
    credentials-binding

# On repasse en utilisateur jenkins pour la sécurité
USER jenkins