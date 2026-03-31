FROM gitlab.mdapi.ch/mdapi/dependency_proxy/containers/debian:stable

ENV PACKAGES="\
  wget \
  ca-certificates \
  cron \
  procps \
  systemd \
  iptraf-ng \
  less \
  vsftpd \
  rsync \
  util-linux \
  lighttpd \
  lighttpd-mod-openssl \
  rsync \
"\
  DEBIAN_FRONTEND=noninteractive

RUN apt update -y && apt install -y --no-install-recommends $PACKAGES && apt clean all

RUN systemctl enable cron vsftpd lighttpd rsync

RUN bash -c "systemctl mask getty@tty{1,2,3,4,5,6}"

RUN useradd -d /home/mirror -m -s /bin/bash -U mirror

COPY --chown=mirror:mirror --chmod=700 sync-gp sync-ba /home/mirror

RUN mkdir -p /srv/ftp /var/www/html/ftp && chown -R mirror:mirror /srv/ftp /var/www/html/ftp

COPY lighttpd.conf /etc/lighttpd/
COPY vsftpd.conf motd rsyncd.conf /etc/
COPY index.html /var/www/html/

RUN echo '/srv/ftp /var/www/html/ftp none rw,bind 0 0' >> /etc/fstab

RUN echo '7,37 * * * * mirror ./sync-gp >/dev/null' >> /etc/crontab
RUN echo '40 */2 * * * mirror ./sync-ba >/dev/null' >> /etc/crontab

ENTRYPOINT ["/usr/lib/systemd/systemd"]
