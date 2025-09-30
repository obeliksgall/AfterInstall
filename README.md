### 📄 README: AfterInstall.ps1

### Overview

`AfterInstall.ps1` is a modular PowerShell automation script designed to streamline post-installation setup on Windows systems. It installs essential applications, configures system settings, and restores user preferences — all with robust logging, error handling, and optional silent execution.

---

### 🔧 Features

- ✅ Internet connectivity check  
- ✅ Ninite-based application installation (silent)  
- ✅ DirectX runtime installation  
- ✅ AdGuard installation (manual fallback supported)  
- ✅ Foobar2000 (32-bit) installation with plugin support  
- ✅ Automatic plugin deployment (DLL and .fb2k-component)  
- ✅ Foobar2000 theme restoration from GitHub  
- ✅ Playback statistics import (`PlaybackStatistics.xml`)  
- ✅ Power configuration: disables sleep and hibernation  
- ✅ Elevation check and auto-relaunch with admin rights  
- ✅ Configurable logging with rotation and retention  
- ✅ Interactive startup prompt (optional)

---

### 🚀 Usage

```powershell
powershell.exe -ExecutionPolicy Bypass -File "AfterInstall.ps1"
```

Optional parameters:

| Parameter             | Description                                      |
|----------------------|--------------------------------------------------|
| `-SilentStart`        | Skips the interactive startup prompt             |
| `-SkipNinite`         | Skips Ninite installer execution                 |
| `-SkipDirectX`        | Skips DirectX runtime installation               |
| `-SkipPowerConfig`    | Skips disabling sleep and hibernation            |
| `-SkipElevation`      | Skips elevation check and relaunch               |

Example:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "AfterInstall.ps1" -SilentStart -SkipDirectX
```

---

### 📁 File Structure

Place the following files in the same directory as the script:

- `foobar2000PlaybackStatistics.xml` — playback history backup
- `adguardInstaller.exe` (optional fallback if download fails)

---

### 🎵 Foobar2000 Integration

- Installs Foobar2000 32-bit silently
- Downloads plugins from official sources:
  - `foo_playcount`, `foo_wave_seekbar`, `foo_beefweb`, `foo_openlyrics`, `foo_dsp_xgeq`
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
