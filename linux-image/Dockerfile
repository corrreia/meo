FROM archlinux:base

RUN pacman -Syu --noconfirm \
    && pacman -S --noconfirm openssh sudo \
    && pacman -Scc --noconfirm

COPY linux-image/entrypoint.sh /usr/local/bin/work-linux-entrypoint

RUN chmod +x /usr/local/bin/work-linux-entrypoint \
    && ssh-keygen -A

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/work-linux-entrypoint"]
