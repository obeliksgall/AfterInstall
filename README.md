## 📄 README: AfterInstall.ps1

### Overview

!!The script is under development and may not work correctly on all Windows systems.!!

`AfterInstall.ps1` is a modular PowerShell automation script designed for post-install system setup. It installs essential applications, configures system power settings, restores Foobar2000 plugins and themes, and imports playback statistics — all with robust logging, elevation handling, and optional silent execution.

---

### 🔧 Features

- ✅ Interactive startup prompt (optional)
- ✅ Elevation check and auto-relaunch with admin rights
- ✅ Internet connectivity check
- ✅ Ninite installer execution (silent by default)
- ✅ DirectX runtime installation
- ✅ AdGuard installation via direct download
- ✅ Foobar2000 32-bit installation
- ✅ Plugin installation for Foobar2000:
  - Supports `.fb2k-component` and `.zip` with `.dll`
  - Downloads from official foobar2000.org links
- ✅ Theme restoration from GitHub (`.fth`)
- ✅ Playback statistics import (`foobar2000PlaybackStatistics.xml`)
- ✅ Power configuration: disables sleep and hibernation
- ✅ Structured logging with timestamped files
- ✅ Configurable log level and retention

---

### 🚀 Usage

```powershell
powershell.exe -ExecutionPolicy Bypass -File "AfterInstall.ps1"
```

Optional switches:

| Switch               | Description                                      |
|----------------------|--------------------------------------------------|
| `-SilentStart`        | Skips the interactive startup prompt             |
| `-SkipElevation`      | Skips elevation check and relaunch               |
| `-SkipNinite`         | Skips Ninite installer execution                 |
| `-SkipDirectX`        | Skips DirectX runtime installation               |
| `-SkipPowerConfig`    | Skips disabling sleep and hibernation            |

Example:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "AfterInstall.ps1" -SilentStart -SkipDirectX -SkipPowerConfig
```

---

### 📁 File Structure

Place the following file in the same directory as the script:

- `foobar2000PlaybackStatistics.xml` — playback history backup

No fallback installer for AdGuard is required — the script downloads it directly from the official CDN.

---

### 🎵 Foobar2000 Integration

- Installs Foobar2000 32-bit silently
- Downloads and installs plugins:
  - `foo_beefweb`, `foo_openlyrics`, `foo_playcount`, `foo_wave_seekbar`, `foo_dsp_xgeq`
- Handles `.fb2k-component` and `.zip` formats
- Restores theme from GitHub:
  - [foobar2000theme_last.fth](https://github.com/obeliksgall/AfterInstall/raw/refs/heads/main/foobar2000/foobar2000theme_last.fth)
- Imports playback statistics from local XML file

---

### 📋 Logging

Logs are stored in:

```
.\Logs\AfterInstall_YYYY-MM-DD_HHMMSS.log
```

Supports log rotation and retention via `-RetentionDays`.

---

### ⚠️ Requirements

- Windows 10/11
- Administrator privileges (auto-elevated if needed)
- Internet connection (for downloads)

---
