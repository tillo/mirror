#!/bin/bash
# Set up the mirror's /srv content store, supporting two layouts with one image:
#
#   * Legacy multi-disk: when /mnt/disk1 is a real mount (the old Longhorn
#     mirror-srv + mirror-srv-2 PVCs), union all /mnt/disk* branches at /srv
#     with mergerfs (category.create=epmfs, minfreespace=20G) — exactly the old
#     fstab behaviour.
#   * Single volume: when /mnt/disk1 is NOT mounted, /srv is expected to already
#     be a real mount (a single Ceph RBD PVC mounted there by Kubernetes) — no
#     mergerfs, no FUSE.
#
# In both cases /srv/ftp is bind-mounted onto the lighttpd docroot. Idempotent;
# ordered before the serving daemons by mirror-storage.service.
set -eu

MERGEROPTS="rw,allow_other,use_ino,cache.files=partial,dropcacheonclose=true,category.create=epmfs,minfreespace=20G,fsname=mergerfs"

if mountpoint -q /mnt/disk1; then
  # Legacy multi-disk layout — union with mergerfs (unless already mounted).
  mountpoint -q /srv || /usr/bin/mergerfs /mnt/disk* /srv -o "$MERGEROPTS"
fi

# /srv is now either the mergerfs union or the single RBD mount. Ensure the ftp
# tree exists and is owned by the mirror user that the sync jobs run as.
install -d -o mirror -g mirror /srv/ftp

# Expose /srv/ftp under the lighttpd docroot via a bind mount.
mountpoint -q /var/www/html/ftp || mount --bind /srv/ftp /var/www/html/ftp
