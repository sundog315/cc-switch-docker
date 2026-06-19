FROM lscr.io/linuxserver/webtop:ubuntu-xfce

# ──────────────────────────────────────────────
# Install cc-switch
# Before building, download the correct .deb for
# your architecture from:
#   https://github.com/farion1231/cc-switch/releases
# and place it next to this Dockerfile.
# ──────────────────────────────────────────────
COPY cc-switch.deb /tmp/cc-switch.deb
RUN dpkg -i /tmp/cc-switch.deb || (apt-get update && apt-get install -yf) && \
    rm -f /tmp/cc-switch.deb

# ──────────────────────────────────────────────
# Auto-start cc-switch via an s6-rc longrun service.
# The service waits for the X server (svc-xorg) to be ready, then runs
# cc-switch in the foreground — so its LLM proxy on :15721 comes up on
# container boot with no manual launch or browser login needed.
# (s6-rc recompiles /etc/s6-overlay/s6-rc.d into the live database on
# every container start, so these files are picked up automatically.)
# ──────────────────────────────────────────────
COPY rootfs/ /
RUN chmod +x /etc/s6-overlay/s6-rc.d/cc-switch/run
