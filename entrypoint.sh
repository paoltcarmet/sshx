#!/bin/bash
set -euo pipefail

# Generate SSH host keys if missing
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
  ssh-keygen -A
fi

# Ensure user/password from env
: "${SSH_USER:=n4}"
: "${SSH_PASSWORD:=n4ssh123}"
echo "${SSH_USER}:${SSH_PASSWORD}" | chpasswd || true

# Start sshd (internal only; Cloud Run won't expose raw TCP)
echo "[N4SSH] Starting sshd on 0.0.0.0:2222"
mkdir -p /var/run/sshd
/usr/sbin/sshd -D -e -f /etc/ssh/sshd_config &
SSHD_PID=$!

# Health endpoint (simple OK on $PORT/healthz and /)
: "${PORT:=8080}"
echo "[N4SSH] Starting Web Terminal (ttyd) on :${PORT}"

# Basic auth for ttyd
: "${TTYD_BASIC_USER:=n4}"
: "${TTYD_BASIC_PASS:=n4pass}"

# ttyd command:
#  -B user:pass   -> HTTP Basic auth
#  -p $PORT       -> listen on Cloud Run port
#  login shell for ${SSH_USER}
exec ttyd -p "${PORT}" -B "${TTYD_BASIC_USER}:${TTYD_BASIC_PASS}" \
     -t title="N4 CloudRun Shell" -t rendererType=webgl \
     -t disableLeaveAlert=true -t enableZmodem=true \
     /bin/login -f "${SSH_USER}"
