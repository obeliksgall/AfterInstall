# 📦 AfterInstall PowerShell Script

**AfterInstall.ps1** is a modular, interactive PowerShell script designed to automate post-installation setup on Windows systems. It provides a user-friendly menu for installing essential software, configuring system settings, and applying customizations — all with robust logging, error handling, and traceability.

Run in powershell:
```
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\AfterInstall.ps1
```

---

## 🚀 Features

- **Interactive module selector** with arrow-key navigation, toggling, and batch selection
- **Modular installer logic** for:
  - Ninite bundle (multi-app installer)
  - DirectX runtime
  - AdGuard ad blocker
  - Foobar2000 media player + plugins + theme
  - SyncTrayzor (Syncthing GUI)
- **Windows configuration tweaks**:
  - Disable sleep and hibernation
  - Set power button, sleep button, and lid close actions to “Do nothing”
  - Apply Windows 11 registry tweak to restore classic context menu
- **Robust logging system**:
  - Color-coded console output
  - Daily log rotation with retention policy
  - Persistent log file in `LOGs` directory
- **Safe cleanup prompt** for temporary installer files

---

## 📁 Directory Structure

```
AfterInstall/
├── AfterInstall.ps1
├── LOGs/
│   └── AfterInstall_current.txt
├── INSTALLfiles/
│   └── [Downloaded installers and assets]
```

---

## 🧩 Modules Included

| Module Name                        | Description                                                                 |
|-----------------------------------|-----------------------------------------------------------------------------|
| Install Ninite                    | Downloads and runs a custom Ninite installer with preselected apps         |
| Install DirectX                   | Installs DirectX runtime silently                                          |
| Install AdGuard                   | Installs AdGuard silently                                                  |
| Install Foobar2000 + plugins      | Installs Foobar2000, official plugins, and user-components from GitHub     |
| Install Foobar2000 theme by author | Downloads and installs a custom `.fth` theme from GitHub                   |
| Install SyncTrayzor               | Installs SyncTrayzor silently                                              |
| Configure Windows                 | Applies power tweaks and Windows 11 registry fix                           |

---

## 🛠 Requirements

- Windows 10 or 11
- Administrator privileges (auto-elevated if needed)
- Internet connection (validated before execution)
- PowerShell 5.1+

---

## 🧠 How It Works

1. **Startup**: Checks for admin rights and internet connectivity.
2. **Menu**: Presents an interactive selector for modules.
3. **Execution**: Runs selected modules with logging and error handling.
4. **Cleanup**: Optionally deletes `INSTALLfiles` after completion.

---

## 📓 Logging

- Logs are saved to `LOGs/AfterInstall_current.txt`
- Daily rotation with 7-day retention
- Each entry includes timestamp, log level, and message
- Levels: `INFO`, `WARN`, `ERROR`, `DEBUG`

---

## 🧹 Cleanup Prompt

At the end of execution, the user is asked:

> “Do you want to delete the INSTALLfiles directory? [Y/N]”

Responding with `Y` or `YES` deletes all downloaded assets.

---

## 🧪 Extensibility

This script is designed for easy extension. You can:

- Add new modules to `$options` and `Run-SelectedModules`
- Use `Write-Log` for consistent logging
- Store assets in `INSTALLfiles` for traceability
- Integrate dispatcher logic for unified control

---

## 📄 License

You may modify and redistribute it freely with attribution.
