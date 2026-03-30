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
"\
  DEBIAN_FRONTEND=noninteractive

RUN apt update -y && apt install -y --no-install-recommends $PACKAGES && apt clean all

RUN systemctl enable cron vsftpd lighttpd

RUN useradd -d /home/mirror -m -s /bin/bash -U mirror

WORKDIR /home/mirror

COPY --chown=mirror:mirror --chmod=700 sync-gp sync-ba ./

RUN mkdir -p /srv/ftp && chown -R mirror:mirror /srv/ftp

COPY vsftpd.conf /etc/
COPY lighttpd.conf /etc/lighttpd/

RUN echo '7,37 * * * * mirror ./sync-gp >/dev/null' >> /etc/crontab
RUN echo '40 */2 * * * mirror ./sync-ba >/dev/null' >> /etc/crontab

ENTRYPOINT ["/usr/lib/systemd/systemd"]
