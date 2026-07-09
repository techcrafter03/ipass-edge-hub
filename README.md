# 🍓 Mini-iPaaS Edge Monitoring Hub

[![Demo Video](https://img.shields.io/badge/▶%20Watch%20Demo-YouTube-red?style=for-the-badge)](https://youtu.be/Xi6Ed8yoJnc)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)]()
[![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi%203-C51A4A?style=for-the-badge&logo=raspberry-pi)]()
[![OS](https://img.shields.io/badge/OS-Raspbian%20Bookworm%2064--bit-A22846?style=for-the-badge)]()

> A lightweight IoT monitoring system built on Raspberry Pi 3 —
> reads real Linux system data and delivers live alerts to Discord
> via Webhook API, automatically every 5 minutes.

---

## 🏗️ System Architecture
---

## 📊 What It Monitors

| Metric | Source | 
|---|---|
| 🌡️ CPU Temperature | `/sys/class/thermal/thermal_zone0/temp` |
| 💾 RAM Usage | `/proc/meminfo` |
| 💿 Disk Usage | `df /` |
| ⚡ Load Average | `/proc/loadavg` |
| ⏱️ System Uptime | `uptime -p` |
| 📁 Log File Sizes | C engine via `stat()` |

---

## 🚨 Alert System

Automatic red Discord embed fires when:
- CPU temperature exceeds **80°C**
- RAM usage exceeds **85%**

---

## 📁 Project Structure
---

## 🔧 Setup & Installation

```bash
# 1. Clone the repository
git clone https://github.com/techcrafter03/ipass-edge-hub.git
cd ipass-edge-hub

# 2. Compile the C engine
gcc -Wall -Wextra -o bin/log_reader src/log_reader.c

# 3. Add your Discord Webhook URL
echo 'DISCORD_WEBHOOK_URL="your_url_here"' > config/webhook.conf
chmod 600 config/webhook.conf

# 4. Make the script executable
chmod +x scripts/monitor.sh

# 5. Run manually
./scripts/monitor.sh

# 6. Enable systemd automation (every 5 minutes)
sudo cp systemd/ipass-monitor.service /etc/systemd/system/
sudo cp systemd/ipass-monitor.timer /etc/systemd/system/
sudo systemctl enable --now ipass-monitor.timer
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Core Engine | C (POSIX — stat, opendir, readdir) |
| Orchestration | Bash (set -euo pipefail, signal trapping) |
| Transport | cURL + Discord Webhook REST API |
| Database | SQLite |
| Automation | systemd timer |
| Hardware | Raspberry Pi 3, Raspbian Bookworm 64-bit |

---

## 🎬 Demo

Watch the full 5-minute demo video:
**[▶ https://youtu.be/Xi6Ed8yoJnc](https://youtu.be/Xi6Ed8yoJnc)**

---

## 👤 Author

**Yash Kale** — Portfolio project for Fachinformatiker Systemintegration Ausbildung
- 🌐 [Portfolio](https://techcrafter03.github.io/portfolio/)
- 📧 webcrafters071@gmail.com
- 🇩🇪 Open to Ausbildung in Germany — August/September 2026
