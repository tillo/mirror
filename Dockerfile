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
  fuse3 \
  mergerfs \
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

COPY --chown=mirror:mirror --chmod=700 sync-gp sync-ba sync-tails sync-as /home/mirror

RUN mkdir -p /srv /var/www/html/ftp /mnt/disk1 /mnt/disk2 && \
    chown -R mirror:mirror /srv /var/www/html/ftp /mnt/disk1 /mnt/disk2

COPY lighttpd.conf /etc/lighttpd/
COPY vsftpd.conf motd rsyncd.conf /etc/
COPY index.html robots.txt sitemap.xml /var/www/html/

# /srv content store is set up at boot by mirror-storage.service (oneshot,
# ordered before the serving daemons), which supports two layouts from one image:
#   * legacy multi-disk -> mergerfs union of /mnt/disk* at /srv
#     (category.create=epmfs, minfreespace=20G — the old fstab behaviour), or
#   * single volume     -> /srv is a real mount (a Ceph RBD PVC), no mergerfs.
# In both cases /srv/ftp is bind-mounted onto the lighttpd docroot. This replaces
# the static fstab mergerfs+bind lines so the same :latest image serves both the
# legacy Longhorn (mergerfs) deployment and the single-RBD deployment.
COPY --chmod=755 mirror-storage.sh /usr/local/bin/mirror-storage.sh
COPY mirror-storage.service /etc/systemd/system/mirror-storage.service
RUN systemctl enable mirror-storage.service

RUN echo '7,37 * * * * mirror ./sync-gp >/dev/null' >> /etc/crontab
RUN echo '40 */2 * * * mirror ./sync-ba >/dev/null' >> /etc/crontab
# Tails wants hourly + 0..40min jitter; the jitter is implemented inside sync-tails
# (see https://tails.net/contribute/how/mirror/).
RUN echo '0 * * * * mirror ./sync-tails >/dev/null' >> /etc/crontab
# `45 0,4,8,12,16,20 * * *` silently fails to fire in Debian Vixie /etc/crontab
# (cron parses it but the scheduler never matches it). Hourly works and the
# bandwidth/disk delta vs every-4h is negligible for a 20 GB tree.
RUN echo '45 * * * * mirror ./sync-as >/dev/null' >> /etc/crontab

ENTRYPOINT ["/usr/lib/systemd/systemd"]
