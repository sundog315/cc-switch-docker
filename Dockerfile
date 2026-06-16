FROM lscr.io/linuxserver/webtop:ubuntu-xfce

COPY cc-switch.deb /tmp/cc-switch.deb
RUN dpkg -i /tmp/cc-switch.deb || (apt-get update && apt-get install -yf)
RUN rm -f /tmp/cc-switch.deb

# XFCE 会话启动时自动打开 cc-switch（复用 deb 自带 desktop；文件名含空格）
RUN cp "/usr/share/applications/CC Switch.desktop" /etc/xdg/autostart/cc-switch.desktop
