# meo

Corporate remote work environment running a Check Point SSL VPN and a Windows 11 VM in Docker. VPN and VM share a network namespace so Windows traffic goes through the corporate VPN tunnel.

Split-tunnel: only RFC 1918 private subnets route through the VPN. Internet traffic goes direct through your home connection.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  meo-vpn container (snx-rs)                     │
│                                                 │
│  eth0 ──────── home internet                    │
│  snx-tun ───── corporate VPN (SSL)              │
│  docker ────── internal bridge (172.30.0.0/24)  │
│                     │                           │
│              ┌──────┴──────┐                    │
│              │ meo-windows │                    │
│              │ (Win 11 VM) │                    │
│              └─────────────┘                    │
└─────────────────────────────────────────────────┘

Corporate traffic (10/8, 172.16/12, 192.168/16) → snx-tun → VPN
Internet traffic (everything else)              → eth0    → home
DNS (all queries)                               → corporate DNS
```

## Setup

1. Copy `.env.example` to `.env` and fill in your credentials:

```bash
cp .env.example .env
```

You need: `USERNAME`, `PASSWORD` (Windows VM login), `VPN_SERVER` (gateway IP), and `VPN_PASSWORD`.

2. Start everything:

```bash
./meo.sh up
```

3. Connect VPN (prompts for 2FA code):

```bash
./meo.sh connect
```

4. Open Windows VM:

```bash
./meo.sh windows rdp    # RDP (full experience)
./meo.sh windows web    # browser viewer (quick access)
```

## Commands

```
VPN:
  ./meo.sh connect [--debug]   Connect VPN (prompts for 2FA)
  ./meo.sh disconnect          Disconnect VPN
  ./meo.sh reconnect [--debug] Disconnect + reconnect

Environment:
  ./meo.sh up                  Start all containers
  ./meo.sh down                Stop all containers
  ./meo.sh status              Show VPN + VM status
  ./meo.sh logs [vpn|windows]  Tail container logs

Windows VM:
  ./meo.sh windows start       Start the VM
  ./meo.sh windows stop        Graceful shutdown
  ./meo.sh windows restart     Stop + start
  ./meo.sh windows rdp         Open RDP session (xfreerdp3)
  ./meo.sh windows web         Open web viewer in browser
  ./meo.sh windows logs        Tail container logs
```

## How it works

- **VPN**: [snx-rs](https://github.com/ancwrd1/snx-rs) runs inside a Docker container in SSL tunnel mode. IPSec doesn't work with this server due to SCV/compliance checks.
- **Windows VM**: [dockurr/windows](https://github.com/dockur/windows) runs a Windows 11 QEMU VM sharing the VPN container's network namespace.
- **Split tunnel**: Server pushes full-tunnel routes, but `no-routing = true` ignores them. Only private subnets are routed through the VPN via `add-routes`. Internet goes direct.
- **NAT**: iptables masquerade on both `snx-tun` (corporate) and `eth0` (internet). DNS is DNAT'd to corporate DNS for both internal and external resolution.
- **RDP**: `xfreerdp3` with dynamic resolution, AVC444 graphics, clipboard, sound/mic, and Hyprland scale detection.
- **Shared folder**: `./shared/` mounts as `Shared` on the Windows desktop.

## Requirements

- Docker + Docker Compose
- KVM (`/dev/kvm`)
- `xfreerdp3` (package: `freerdp`) for RDP
- `jq` for Hyprland scale detection

## Notes

- The VPN gateway IP is not discoverable via DNS. The portal hostname resolves to a different gateway via MEP (Multiple Entry Point), but snx-rs doesn't support MEP. You need the correct gateway IP from your IT admin or Check Point client logs.
- `ignore-server-cert = true` is required because we connect by IP, causing a TLS hostname mismatch.
- `VM_NET_DEV: "eth0"` must be set so dockurr uses the right network interface (otherwise it picks up `snx-tun` and fails).
