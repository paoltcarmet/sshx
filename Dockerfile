FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
# Default ENV (override at deploy-time)
ENV PORT=8080 \
    TTYD_BASIC_USER=n4 \
    TTYD_BASIC_PASS=n4pass \
    SSH_USER=n4 \
    SSH_PASSWORD=n4ssh123

# Base tools + OpenSSH + ttyd deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server curl wget ca-certificates sudo \
    bash coreutils netcat-openbsd iproute2 procps tini \
    && rm -rf /var/lib/apt/lists/*

# Create SSH user
RUN useradd -m -s /bin/bash ${SSH_USER} \
 && echo "${SSH_USER}:${SSH_PASSWORD}" | chpasswd \
 && adduser ${SSH_USER} sudo \
 && echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-cloud

# SSHD setup
RUN mkdir -p /var/run/sshd /var/log/ssh
COPY sshd_config /etc/ssh/sshd_config

# Install ttyd (static)
ARG TTYD_VERSION=1.7.7
RUN ARCH=$(dpkg --print-architecture) \
 && case "$ARCH" in \
      amd64)  TTYD_ARCH="x86_64" ;; \
      arm64)  TTYD_ARCH="aarch64" ;; \
      *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac \
 && curl -fsSL -o /usr/local/bin/ttyd \
      "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${TTYD_ARCH}" \
 && chmod +x /usr/local/bin/ttyd

# Health/entry
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/entrypoint.sh"]
