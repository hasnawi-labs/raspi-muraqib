# raspi-muraqib

Grafana, Prometheus and Loki monitoring for a single Raspberry Pi. Metrics and logs in one place, 2 week retention, survives reboots.

## Requirements

64-bit Raspberry Pi OS (Bookworm or newer) on a Pi 3 or later. The 64-bit part is not optional: Grafana Alloy has no 32-bit ARM build.

## 1. Install Docker

```sh
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"
sudo systemctl enable --now docker
```

Log out and back in (or run `newgrp docker`) so your user can use Docker without `sudo`.

## 2. Make the system journal persistent

Raspberry Pi OS ships a drop-in that forces the journal into RAM, so it is wiped on every reboot and there is nothing for Loki to read. Override it:

```sh
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/99-persistent.conf >/dev/null <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=200M
EOF
sudo systemctl restart systemd-journald
sudo journalctl --flush
```

Two details that are easy to get wrong. The file must sort after Raspberry Pi OS's own `40-rpi-volatile-storage.conf`, because journald applies drop-ins in filename order regardless of which directory they live in, hence the `99-` prefix. And `journalctl --flush` is what actually moves the journal onto disk; without it journald keeps writing to RAM until the next reboot. `SystemMaxUse` caps how much of the SD card the journal may use.

If the stack is already running, pick up the change with `docker compose restart alloy`.

## 3. Start the stack

```sh
git clone https://github.com/hasnawi-labs/raspi-muraqib.git
cd raspi-muraqib
cp .env.example .env    # set a real password
docker compose up -d
```

First start pulls about 700 MB of images, so give it a few minutes.

## 4. Check it

```sh
./check.sh
```

Then open `http://<pi-ip>:3000` and log in with the credentials from `.env`. Two dashboards are already waiting for you: **Raspberry Pi Overview** for metrics and **Raspberry Pi Logs** for logs.

## What each container does

| container | job |
| --- | --- |
| grafana | the web UI, port 3000 |
| prometheus | stores metrics for 14 days, port 9090 |
| node-exporter | reads CPU, memory, disk, network and temperature from the Pi |
| loki | stores logs for 14 days, port 3100 |
| alloy | ships container logs and the system journal into Loki |

## Reboots

Nothing to do. Docker starts at boot and every container has `restart: unless-stopped`. Data lives in Docker named volumes, so it survives restarts, reboots, and `docker compose down`.

## Day to day

```sh
docker compose ps                              # what is running
docker compose logs -f alloy                   # why a container is unhappy
docker compose pull && docker compose up -d    # update images
docker compose down                            # stop, keeping all data
```

## Changing retention

Two places, both currently 14 days:

- `docker-compose.yml`, the prometheus flag `--storage.tsdb.retention.time=14d`
- `loki/loki.yml`, `retention_period: 336h`

## Adding dashboards

Drop any dashboard JSON into `grafana/dashboards/` and it shows up within 30 seconds. For a much bigger metrics dashboard, import ID `1860` from Grafana's library (Dashboards, New, Import).

## One warning about SD cards

Prometheus and Loki write continuously. On a cheap SD card that means a worn out card in a year or two. If the Pi is meant to run for a long time, boot from a USB SSD.
