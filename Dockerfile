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

# Auto-start cc-switch in webtop XFCE session
RUN cp "/usr/share/applications/CC Switch.desktop" /etc/xdg/autostart/cc-switch.desktop
