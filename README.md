# iPaaS Edge Monitoring Hub

![Platform](https://img.shields.io/badge/platform-Linux-blue)
![Language](https://img.shields.io/badge/language-C%20%7C%20Bash-green)
![License](https://img.shields.io/badge/license-MIT-orange)

> A lightweight, zero-dependency Linux monitoring agent that deploys 
> on any Linux system in under 10 minutes — from edge devices to 
> enterprise servers. Reads directly from the Linux kernel, fires 
> real-time alerts via webhook API, and logs every metric with full 
> audit trail.

## The Problem

Small and medium IT environments — MSPs, Systemhäuser, edge 
deployments — need reliable infrastructure monitoring without the 
overhead of tools like Nagios or Zabbix. Heavy setup, complex 
configuration, and significant resource usage make enterprise 
monitoring tools impractical for resource-constrained or distributed 
environments.

## The Solution

A single-binary Linux monitoring agent that:
- Deploys in under 10 minutes on any Linux system
- Requires zero external dependencies
- Reads metrics directly from the Linux kernel via POSIX interfaces
- Fires instant alerts through any webhook API
- Logs every metric to SQLite for full audit trail
- Responds automatically to critical thresholds

## What It Monitors

| Metric | Source |
|--------|--------|
| 🌡️ CPU Temperature | `/sys/class/thermal/thermal_zone0/temp` |
| 💾 RAM Usage | `/proc/meminfo` |
| 💿 Disk Usage | `df /` |
| ⚡ Load Average | `/proc/loadavg` |
| ⏱️ System Uptime | `uptime -p` |
| 📁 Log File Sizes | C engine via `stat()` |

## Alert & Response System

When thresholds are breached:
- Instant webhook alert fires to Discord (Slack, Teams — coming soon)
- Graceful system shutdown executes on critical temperature threshold
- Every event logged to SQLite with full timestamp and audit trail

Default thresholds (configurable):
- CPU temperature > 80°C
- RAM usage > 85%

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Core Engine | C (POSIX — `stat`, `opendir`, `readdir`) |
| Orchestration | Bash (`set -euo pipefail`, signal trapping) |
| Transport | cURL + Webhook REST API |
| Database | SQLite |
| Automation | systemd timer (every 5 minutes) |
| Compatibility | Any Linux system — edge devices to servers |

## Quick Deploy — Under 10 Minutes

```bash
# 1. Clone
git clone https://github.com/techcrafter03/ipass-edge-hub.git
cd ipass-edge-hub

# 2. Compile the C engine
gcc -Wall -Wextra -o bin/log_reader src/log_reader.c

# 3. Configure webhook
echo 'DISCORD_WEBHOOK_URL="your_url_here"' > config/webhook.conf
chmod 600 config/webhook.conf

# 4. Make executable
chmod +x scripts/monitor.sh

# 5. Enable systemd automation
sudo cp systemd/ipass-monitor.service /etc/systemd/system/
sudo cp systemd/ipass-monitor.timer /etc/systemd/system/
sudo systemctl enable --now ipass-monitor.timer
```

Done. Your Linux system is now monitored.

## Use Cases

**MSPs and IT Systemhäuser**
Deploy on client servers for lightweight real-time monitoring 
without enterprise tool overhead.

**Edge Computing and Industry 4.0**
Monitor distributed Linux nodes at manufacturing sites, remote 
locations, and IoT deployments where resource efficiency is critical.

**Server Rooms**
Automated thermal and resource monitoring with physical response 
capability — prevents hardware damage before it happens.

**Audit-Ready Environments**
Every metric, every alert, every threshold response logged to 
SQLite — full traceability for compliance requirements.

## Architecture & Vision

This agent is the foundation of a larger vision — a distributed 
infrastructure nervous system for Linux environments. Independent 
agents deployed across an entire server network, each operating 
autonomously, each reporting to a central visibility layer.

Every action logged. Every threshold response auditable. Every 
node accountable.

The same lightweight principles that make this agent effective on 
an edge device scale directly to enterprise Linux infrastructure — 
without the complexity ceiling of traditional monitoring platforms.

## Demo

▶ [Watch full 5-minute live demo](https://youtu.be/Xi6Ed8yoJnc)

## Roadmap

- [ ] One-script setup — full deployment in under 10 minutes
- [ ] Webhook agnostic — Slack, Teams, email support
- [ ] Configurable thresholds via config file
- [ ] Auto-shutdown and cooling response on critical threshold
- [ ] Web dashboard — live metrics visualization
- [ ] Multi-machine support — central collector for distributed agents

## Author

**Yash Kale**
Self-taught developer — C, Bash, Linux, SQLite, systemd, WireGuard

🌐 [Portfolio](https://techcrafter03.github.io/portfolio)
📧 webcrafters071@gmail.com
🇩🇪 Pursuing Fachinformatiker Systemintegration Ausbildung — Germany 2026
