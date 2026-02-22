# BUILD THE HYTALE SERVER IMAGE
FROM eclipse-temurin:25-jdk

# ENVIRONMENT (non user-defined)
ENV HOME=/home/hytale \
    USERN=hytale \
    SERVER_FILES=/home/hytale/server-files \
    SERVER_ROOT=/home/hytale/server \
    CONFIG_DIR=/home/hytale/server/hytale-config \
    BACKUP_DIR=/home/hytale/server-files/backups \
    PATH=/home/hytale/server:${PATH}

RUN apt-get update && apt-get install -y --no-install-recommends \
    gettext-base \
    procps \
    jq \
    curl \
    gosu \
    unzip \
    wget \
    ca-certificates \
    qemu-user-static \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

LABEL maintainer="support@indifferentbroccoli.com" \
      name="indifferentbroccoli/hytale-server-docker" \
      github="https://github.com/indifferentbroccoli/hytale-server-docker" \
      dockerhub="https://hub.docker.com/r/indifferentbroccoli/hytale-server-docker"



# Create a default user (UID/GID can be adjusted at runtime by init.sh on rootful Docker)
RUN userdel -r ubuntu 2>/dev/null || true \
 && useradd -u 1000 -U -m -s /bin/bash ${USERN} \
 && mkdir -p ${SERVER_ROOT} ${SERVER_FILES} ${BACKUP_DIR} \
 && chown -R ${USERN}:${USERN} ${HOME} \
 && chmod 755 ${HOME}

# Copy some files
COPY --chown=${USERN}:${USERN} ./scripts ${SERVER_ROOT}
COPY --chown=${USERN}:${USERN} branding /branding

# Ensure scripts are executable even if we run as root and later drop privileges.
RUN chmod +x ${SERVER_ROOT}/*.sh \
 && chmod -R a+rX ${SERVER_ROOT}


# Rootless-compatible machine-id persistence
# We cannot write to /etc or /var/lib/dbus when running as non-root.
# Instead we make those paths symlinks to a file stored in the persistent volume.
RUN mkdir -p ${SERVER_FILES}/.machine-id /var/lib/dbus && \
    rm -f /etc/machine-id /var/lib/dbus/machine-id && \
    ln -s ${SERVER_FILES}/.machine-id/machine-id /etc/machine-id && \
    ln -s ${SERVER_FILES}/.machine-id/dbus-machine-id /var/lib/dbus/machine-id
    
# NOTE: We intentionally do NOT set `USER` here.
# - On rootful Docker, init.sh will drop privileges to match the bind-mounted directory ownership.
# - On rootless Docker (userns), staying as container root ensures files created on a bind mount are owned by the host user.

WORKDIR ${SERVER_ROOT}

# Health check to ensure the server is running
HEALTHCHECK --start-period=5m \
            --interval=30s \
            --timeout=10s \
            CMD pgrep -f "HytaleServer.jar" > /dev/null || exit 1

ENTRYPOINT ["/home/hytale/server/init.sh"]
