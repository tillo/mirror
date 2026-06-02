ARG REGISTRY=
FROM ${REGISTRY}debian:stable

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

# ARG changes daily (passed from CI as $(date +%Y%m%d)) so this RUN's
# cache key invalidates once per day, picking up newly-published security
# patches via `apt upgrade` against current debian repos.
ARG CACHEBUST_DAY=unset
RUN echo "cache day: ${CACHEBUST_DAY}" && \
    apt update -y && apt -y upgrade && \
    apt install -y --no-install-recommends $PACKAGES && apt clean all

RUN systemctl enable cron vsftpd lighttpd rsync

RUN bash -c "systemctl mask getty@tty{1,2,3,4,5,6}"

RUN useradd -d /home/mirror -m -s /bin/bash -U mirror

COPY --chown=mirror:mirror --chmod=700 sync-gp sync-ba sync-tor sync-tails sync-wh sync-ow /home/mirror

RUN mkdir -p /srv/ftp /var/www/html/ftp && chown -R mirror:mirror /srv/ftp /var/www/html/ftp

COPY lighttpd.conf /etc/lighttpd/
COPY vsftpd.conf motd rsyncd.conf /etc/
COPY index.html robots.txt sitemap.xml /var/www/html/

RUN echo '/srv/ftp /var/www/html/ftp none rw,bind 0 0' >> /etc/fstab

RUN echo '7,37 * * * * mirror ./sync-gp >/dev/null' >> /etc/crontab
RUN echo '40 */2 * * * mirror ./sync-ba >/dev/null' >> /etc/crontab
RUN echo '5,35 * * * * mirror ./sync-ow >/dev/null' >> /etc/crontab
RUN echo '12 0,4,8,12,16,20 * * * mirror ./sync-tor >/dev/null' >> /etc/crontab
RUN echo '17 0,4,8,12,16,20 * * * mirror ./sync-tails >/dev/null' >> /etc/crontab
RUN echo '22 0,4,8,12,16,20 * * * mirror ./sync-wh >/dev/null' >> /etc/crontab

ENTRYPOINT ["/usr/lib/systemd/systemd"]
