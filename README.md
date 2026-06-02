# mirror

Turnkey public-mirror container. Bundles **HTTP(S)** (lighttpd), **FTP(S)** (vsftpd) and **rsync** in a single image so one host can serve a Linux-distribution mirror over all three protocols.

This is the image behind [mirror.mdapi.ch](https://mirror.mdapi.ch/), which carries BlackArch Linux, Gentoo Portage and Tails mirrors.

## What's in it

- `lighttpd` + `lighttpd-mod-openssl` — HTTP(S) on 80/443
- `vsftpd` — anonymous FTP + FTPS on 21
- `rsync` daemon — rsync:// on 873
- `cron` jobs that pull from upstream mirrors on staggered cadences (`sync-gp` Gentoo Portage twice an hour, `sync-ba` BlackArch every 2h, `sync-tails` every 4h)
- `systemd` as PID 1 so all four services run under unit supervision

Default landing page (`index.html`) documents the available mount points; `robots.txt` allows the landing page and blocks crawlers from the `/ftp/` tree so multi-million-file package repos don't get indexed.

## Run

```bash
docker run -d \
  --name mirror \
  --tmpfs /run --tmpfs /tmp \
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  -p 80:80 -p 443:443 -p 21:21 -p 873:873 \
  -v /srv/mirror:/srv/ftp \
  ghcr.io/MDAPI-Repos/mirror:latest
```

The container needs cgroups + tmpfs for systemd; mount your mirror storage at `/srv/ftp` (it gets bind-mounted to `/var/www/html/ftp` so HTTP and FTP see the same tree).

Adjust the `sync-*` scripts and the `crontab` lines before building if you want different upstreams or a different schedule.

## Build

```bash
docker build -t mirror .
```

When building in a CI that has a pull-through cache for Docker Hub (e.g. the GitLab dependency proxy), pass `--build-arg REGISTRY=<cache-prefix>/` to route `debian:stable` through it.
