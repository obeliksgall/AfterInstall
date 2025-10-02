#$logPath = "C:\AfterInstall\LOGs\AfterInstall_v02_current.txt"
#[System.IO.File]::SetLastWriteTime($logPath, [datetime]"2025-09-22 18:00")
#Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# ───── Log Setup ─────
$LogLevel = "DEBUG"
$LogPriority = @{ INFO = 1; WARN = 2; ERROR = 3; DEBUG = 4 }
$LogColor    = @{ INFO = "Green"; WARN = "Yellow"; ERROR = "Red"; DEBUG = "Cyan" }
$ScriptName  = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)
$RetentionDays = 7

# ───── Paths ─────
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogDir     = Join-Path -Path $PSScriptRoot -ChildPath "LOGs"
$InstallDir = Join-Path $ScriptRoot "INSTALLfiles"
$CurrentLog = Join-Path $LogDir "$ScriptName`_current.txt"

# ───── Create Directories ─────
foreach ($dir in @($LogDir, $InstallDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory | Out-Null
    }
}

# ───── Delete Old Logs ─────
Get-ChildItem -Path $LogDir -File | Where-Object {
    $_.Name -like "$ScriptName*_*.txt" -and $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays)
} | Remove-Item -Force

# ───── Rotate Daily Logs ─────
function Rotate-Log {
    if (Test-Path $CurrentLog) {
        $LastWriteDate = (Get-Item $CurrentLog).LastWriteTime.Date
        $Today = (Get-Date).Date
        if ($LastWriteDate -ne $Today) {
            $BaseName = "$ScriptName" + "_" + $LastWriteDate.ToString("yyyy_MM_dd")
            $ArchivedPath = Join-Path $LogDir "$BaseName.txt"
            $counter = 1
            while (Test-Path $ArchivedPath) {
                $ArchivedPath = Join-Path $LogDir "$BaseName" + "_$counter.txt"
                $counter++
            }
            Rename-Item -Path $CurrentLog -NewName (Split-Path $ArchivedPath -Leaf)
        }
    }
}

# ───── Write Log Entry ─────
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level
    )
    if ($LogPriority[$Level] -le $LogPriority[$LogLevel]) {
        Rotate-Log
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $Formatted = "$Timestamp [$Level] $Message"
        $Color = $LogColor[$Level]
        Write-Host $Formatted -ForegroundColor $Color
        Add-Content -Path $CurrentLog -Value $Formatted
    }
}

# ───── Admin & Internet Check ─────
function Ensure-AdminRightsOnly {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Script not running as administrator. Relaunching..." "WARN"
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

# ───── Interactive Menu ─────
function Show-InteractiveModuleSelector {
    $options = @(
        @{ Name = "Install Ninite"; Enabled = $true },
        @{ Name = "Install DirectX"; Enabled = $true },
        @{ Name = "Install AdGuard"; Enabled = $true },
        @{ Name = "Install Foobar2000 + plugins"; Enabled = $true },
        @{ Name = "Install Foobar2000 theme by author"; Enabled = $true },
        @{ Name = "Install SyncTrayzor"; Enabled = $true },
        @{ Name = "Configure Windows"; Enabled = $true }
    )

    $selectedIndex = 0

    do {
        Clear-Host
        Write-Host "      Select modules to run:"
        Write-Host "`nUse the up/down arrows to navigate`nTo select/deselect use SPACE or X`n         Select all - A`n        Deselect all - D`n    Install selected - ENTER`n         EXIT - ESC or 0`n"

        for ($i = 0; $i -lt $options.Count; $i++) {
            $prefix = if ($options[$i].Enabled) { "[X]" } else { "[ ]" }
            $highlight = if ($i -eq $selectedIndex) { ">>" } else { "  " }
            Write-Host "$highlight $prefix $($options[$i].Name)"
        }

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        switch ($key.VirtualKeyCode) {
            38 { if ($selectedIndex -gt 0) { $selectedIndex-- } }         # ↑ UP
            40 { if ($selectedIndex -lt ($options.Count - 1)) { $selectedIndex++ } } # ↓ DOWN
            32 { $options[$selectedIndex].Enabled = -not $options[$selectedIndex].Enabled } # SPACE
            88 { $options[$selectedIndex].Enabled = -not $options[$selectedIndex].Enabled } # X
            13 { return $options }                                        # ENTER
            27 { Write-Log "User exited via ESC."; exit }                # ESC
            48 { Write-Log "User exited via 0."; exit }                  # 0

#27 {
#    Write-Log "User exited via ESC." "INFO"
#    if (Test-Path $InstallDir) {
#        try {
#            Remove-Item -Path $InstallDir -Recurse -Force
#            Write-Log "INSTALLfiles directory removed after ESC." "DEBUG"
#        } catch {
#            Write-Log "Failed to remove INSTALLfiles: $_" "WARN"
#        }
#    }
#    exit
#}
#48 {
#    Write-Log "User exited via 0." "INFO"
#    if (Test-Path $InstallDir) {
#        try {
#            Remove-Item -Path $InstallDir -Recurse -Force
#            Write-Log "INSTALLfiles directory removed after 0." "DEBUG"
#        } catch {
#            Write-Log "Failed to remove INSTALLfiles: $_" "WARN"
#        }
#    }
#    exit
#}


            default {
                switch ($key.Character) {
                    'A' { foreach ($opt in $options) { $opt.Enabled = $true } }
                    'D' { foreach ($opt in $options) { $opt.Enabled = $false } }
                }
            }
        }
    } while ($true)
}

function Test-InternetConnection {
    $TestUri = "https://www.google.com"
    $FallbackHost = "8.8.8.8"

    try {
        $response = Invoke-WebRequest -Uri $TestUri -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Log -Message "Internet connection OK via $TestUri" -Level "INFO"
            return $true
        } else {
            Write-Log -Message "No internet connection (status code: $($response.StatusCode))" -Level "WARN"
        }
    } catch {
        Write-Log -Message "Error connecting to $TestUri $_" -Level "WARN"
    }

    try {
        $ping = Test-Connection -ComputerName $FallbackHost -Count 2 -Quiet -ErrorAction Stop
        if ($ping) {
            Write-Log -Message "Internet connection OK via $FallbackHost (ping)" -Level "INFO"
            return $true
        } else {
            Write-Log -Message "No response from $FallbackHost (ping)" -Level "ERROR"
            return $false
        }
    } catch {
        Write-Log -Message "Ping test to $FallbackHost failed: $_" -Level "ERROR"
        return $false
    }
}

function Install-NiniteBundle {
    $NiniteUrl = "https://ninite.com/.net4.8.1-.netx8-.netx9-7zip-aspnetx8-aspnetx9-chrome-discord-keepass2-notepadplusplus-putty-steam-vcredist05-vcredist08-vcredist10-vcredist12-vcredist13-vcredist15-vcredistx05-vcredistx08-vcredistx10-vcredistx12-vcredistx13-vcredistx15-vlc-winscp/ninite.exe"
    #$InstallerPath = Join-Path $env:TEMP "ninite_installer.exe"
    $InstallerPath = Join-Path $InstallDir "ninite_installer.exe"

    try {
        Write-Log -Message "Downloading Ninite installer..." -Level "INFO"
        Invoke-WebRequest -Uri $NiniteUrl -OutFile $InstallerPath -UseBasicParsing -TimeoutSec 30
        Write-Log -Message "Download completed: $InstallerPath" -Level "INFO"
    } catch {
        Write-Log -Message "Failed to download Ninite installer: $_" -Level "ERROR"
        exit 1
    }

    try {
        #Write-Log -Message "Running Ninite installer silently..." -Level "INFO"
        Write-Log -Message "Running Ninite installer..." -Level "INFO"
        #Start-Process -FilePath $InstallerPath -ArgumentList "/silent" -Wait
        Start-Process -FilePath $InstallerPath -Wait
        Write-Log -Message "Ninite installation completed." -Level "INFO"
    } catch {
        Write-Log -Message "Error during Ninite installation: $_" -Level "ERROR"
        exit 1
    }
}

function Install-DirectX {
    $DirectXUrl = "https://download.microsoft.com/download/1/7/1/1718ccc4-6315-4d8e-9543-8e28a4e18c4c/dxwebsetup.exe"
    $InstallerPath = Join-Path $InstallDir "dxwebsetup.exe"

    try {
        Write-Log -Message "Downloading DirectX installer..." -Level "INFO"
        Invoke-WebRequest -Uri $DirectXUrl -OutFile $InstallerPath -UseBasicParsing -TimeoutSec 30
        Write-Log -Message "Download completed: $InstallerPath" -Level "INFO"
    } catch {
        Write-Log -Message "Failed to download DirectX installer: $_" -Level "ERROR"
        return
    }

    try {
        Write-Log -Message "Running DirectX installer..." -Level "INFO"
        Start-Process -FilePath $InstallerPath -ArgumentList "/Q" -Wait
        Write-Log -Message "DirectX installation completed." -Level "INFO"
    } catch {
        Write-Log -Message "Error during DirectX installation: $_" -Level "ERROR"
        return
    }
}

function Install-AdGuard {
    $AdGuardUrl = "https://download.adguardcdn.com/d/18675/adguardInstaller.exe"
    $InstallerPath = Join-Path $InstallDir "adguardInstaller.exe"

    try {
        Write-Log -Message "Downloading AdGuard installer..." -Level "INFO"
        Invoke-WebRequest -Uri $AdGuardUrl -OutFile $InstallerPath -UseBasicParsing -TimeoutSec 30
        Write-Log -Message "Download completed: $InstallerPath" -Level "INFO"
    } catch {
        Write-Log -Message "Failed to download AdGuard installer: $_" -Level "ERROR"
        return
    }

    try {
        #Write-Log -Message "Running AdGuard installer silently..." -Level "INFO"
        #Start-Process -FilePath $InstallerPath -ArgumentList "/silent" -Wait
        Write-Log -Message "Running AdGuard installer..." -Level "INFO"
        Start-Process -FilePath $InstallerPath -ArgumentList "/silent" -Wait
        Write-Log -Message "AdGuard installation completed." -Level "INFO"
    } catch {
        Write-Log -Message "Error during AdGuard installation: $_" -Level "ERROR"
        return
    }
}

function Stop-FoobarIfRunning {
    try {
        $foobarProcess = Get-Process -Name "foobar2000" -ErrorAction SilentlyContinue
        if ($foobarProcess) {
            Write-Log -Message "Foobar2000 is running. Attempting to close..." -Level "WARN"
            Stop-Process -Name "foobar2000" -Force
            Write-Log -Message "Foobar2000 process terminated." -Level "INFO"
        } else {
            Write-Log -Message "Foobar2000 is not running." -Level "DEBUG"
        }
    } catch {
        Write-Log -Message "Failed to stop Foobar2000: $_" -Level "ERROR"
    }
}


function Install-Foobar2000WithPlugins {
    $FoobarUrl = "https://www.foobar2000.org/files/foobar2000_v2.25.1.exe"
    $InstallerPath = Join-Path $InstallDir "foobar2000_installer.exe"

    Stop-FoobarIfRunning

    try {
        Write-Log -Message "Downloading Foobar2000 installer..." -Level "INFO"
        Invoke-WebRequest -Uri $FoobarUrl -OutFile $InstallerPath -UseBasicParsing -TimeoutSec 30
        Write-Log -Message "Download completed: $InstallerPath" -Level "INFO"
    } catch {
        Write-Log -Message "Failed to download Foobar2000 installer: $_" -Level "ERROR"
        return
    }

    try {
        Write-Log -Message "Running Foobar2000 installer silently..." -Level "INFO"
        Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait
        Write-Log -Message "Foobar2000 installation completed." -Level "INFO"
    } catch {
        Write-Log -Message "Error during Foobar2000 installation: $_" -Level "ERROR"
        return
    }

    $FoobarComponentDir = "$env:ProgramFiles (x86)\foobar2000\components"
    if (-not (Test-Path $FoobarComponentDir)) {
        Write-Log -Message "Foobar2000 not found at expected path: $FoobarComponentDir" -Level "ERROR"
        return
    }

    $PluginUrls = @(
        "https://www.foobar2000.org/getcomponent/98881927bed68c4073b776720dcf9ec6/foo_beefweb-0.7.fb2k-component",
        "https://www.foobar2000.org/getcomponent/ed22ac55275a5ab35faebb16e7b172aa/foo_openlyrics-v1.6.fb2k-component",
        "https://www.foobar2000.org/getcomponent/4562cb1682a7de50b241ab489ebd49d2/foo_playcount.fb2k-component",
        "https://www.foobar2000.org/getcomponent/c0646634c03ffe6084a9cacda374d196/foo_wave_seekbar-0.2.45.fb2k-component",
        "https://www.foobar2000.org/getcomponent/8febb9df1bbeabf041f1965e6fbb6e96/foo_dsp_xgeq.zip"
    )

    foreach ($url in $PluginUrls) {
        $fileName = Split-Path $url -Leaf
        $tempPath = Join-Path $InstallDir $fileName

        try {
            Write-Log -Message "Downloading plugin: $fileName" -Level "INFO"
            Invoke-WebRequest -Uri $url -OutFile $tempPath -UseBasicParsing -TimeoutSec 30
        } catch {
            Write-Log -Message "Failed to download $fileName : $_" -Level "ERROR"
            continue
        }

        if ($fileName -like "*.zip") {
            $extractPath = Join-Path $InstallDir "foobar_plugin_extract"
            if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
            New-Item -Path $extractPath -ItemType Directory | Out-Null

            try {
                Write-Log -Message "Extracting ZIP: $fileName" -Level "INFO"
                Expand-Archive -Path $tempPath -DestinationPath $extractPath -Force
                $dlls = Get-ChildItem -Path $extractPath -Filter *.dll
                foreach ($dll in $dlls) {
                    Copy-Item -Path $dll.FullName -Destination $FoobarComponentDir -Force
                    Write-Log -Message "Installed DLL plugin: $($dll.Name)" -Level "INFO"
                }
            } catch {
                Write-Log -Message "Failed to extract or copy DLLs from $fileName : $_" -Level "ERROR"
            }
        } else {
            try {
                Copy-Item -Path $tempPath -Destination $FoobarComponentDir -Force
                Write-Log -Message "Installed component: $fileName" -Level "INFO"
            } catch {
                Write-Log -Message "Failed to copy component $fileName : $_" -Level "ERROR"
            }
        }


# Dodatkowe rozpakowanie do user-components dla wybranych pluginów
$UserComponentMap = @{
    "foo_openlyrics-v1.6.fb2k-component"     = "foo_openlyrics"
    "foo_wave_seekbar-0.2.45.fb2k-component" = "foo_wave_seekbar"
}

if ($UserComponentMap.ContainsKey($fileName)) {
    $pluginFolderName = $UserComponentMap[$fileName]
    $pluginTargetDir  = Join-Path $env:APPDATA "foobar2000-v2\user-components\$pluginFolderName"

    if (Test-Path $pluginTargetDir) { Remove-Item $pluginTargetDir -Recurse -Force }
    New-Item -Path $pluginTargetDir -ItemType Directory | Out-Null

    $sevenZipPath = "${env:ProgramFiles}\7-Zip\7z.exe"
    if (-not (Test-Path $sevenZipPath)) {
        $sevenZipPath = "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
    }

    if (Test-Path $sevenZipPath) {
        try {
            Write-Log -Message "Extracting $fileName to user-components using 7-Zip → $pluginTargetDir" -Level "INFO"
            Start-Process -FilePath $sevenZipPath -ArgumentList "x `"$tempPath`" -o`"$pluginTargetDir`" -y" -Wait -NoNewWindow
            Write-Log -Message "Plugin $pluginFolderName extracted to user-components via 7-Zip." -Level "INFO"
        } catch {
            Write-Log -Message "7-Zip extraction failed for $pluginFolderName : $_" -Level "ERROR"
        }
    } else {
        Write-Log -Message "7-Zip not found. Skipping extraction of $pluginFolderName to user-components." -Level "WARN"
    }
}






    }




    # Download and install user-components from GitHub
#$UserComponentsZipUrl = "https://github.com/obeliksgall/AfterInstall/archive/refs/heads/main.zip"
#$ZipPath = Join-Path $InstallDir "foobar_user_components.zip"
#$ExtractRoot = Join-Path $InstallDir "foobar_user_components_extract"
#$TargetUserComponents = Join-Path $env:APPDATA "foobar2000-v2\user-components"
#
#try {
#    Write-Log -Message "Downloading user-components archive from GitHub..." -Level "INFO"
#    Invoke-WebRequest -Uri $UserComponentsZipUrl -OutFile $ZipPath -UseBasicParsing -TimeoutSec 60
#    Write-Log -Message "Download completed: $ZipPath" -Level "INFO"
#} catch {
#    Write-Log -Message "Failed to download user-components archive: $_" -Level "ERROR"
#    return
#}
#
#try {
#    if (Test-Path $ExtractRoot) { Remove-Item $ExtractRoot -Recurse -Force }
#    Expand-Archive -Path $ZipPath -DestinationPath $ExtractRoot -Force
#    Write-Log -Message "Archive extracted to: $ExtractRoot" -Level "INFO"
#
#    $SourceUserComponents = Join-Path $ExtractRoot "AfterInstall-main\foobar2000\user-components"
#    if (-not (Test-Path $SourceUserComponents)) {
#        Write-Log -Message "Source user-components directory not found: $SourceUserComponents" -Level "ERROR"
#        return
#    }
#
#    if (-not (Test-Path $TargetUserComponents)) {
#        Write-Log -Message "Creating target user-components directory: $TargetUserComponents" -Level "INFO"
#        New-Item -Path $TargetUserComponents -ItemType Directory | Out-Null
#    }
#
#    Copy-Item -Path "$SourceUserComponents\*" -Destination $TargetUserComponents -Recurse -Force
#    Write-Log -Message "User-components installed to: $TargetUserComponents" -Level "INFO"
#} catch {
#    Write-Log -Message "Failed to extract or copy user-components: $_" -Level "ERROR"
#}



}

function Install-FoobarThemeFromGitHub {
    $ThemeUrl       = "https://github.com/obeliksgall/AfterInstall/raw/refs/heads/main/foobar2000/foobar2000theme_last.fth"
    $ThemeFileName  = "foobar2000theme_last.fth"
    $DownloadedPath = Join-Path $InstallDir $ThemeFileName
    $TargetPath     = "$env:APPDATA\foobar2000-v2\theme.fth"

    try {
        Write-Log -Message "Downloading Foobar2000 theme from GitHub..." -Level "INFO"
        Invoke-WebRequest -Uri $ThemeUrl -OutFile $DownloadedPath -UseBasicParsing -TimeoutSec 30
        Write-Log -Message "Theme downloaded to: $DownloadedPath" -Level "INFO"
    } catch {
        Write-Log -Message "Failed to download theme: $_" -Level "ERROR"
        return
    }

    try {
        if (-not (Test-Path (Split-Path $TargetPath))) {
            Write-Log -Message "Creating target theme directory: $(Split-Path $TargetPath)" -Level "INFO"
            New-Item -Path (Split-Path $TargetPath) -ItemType Directory | Out-Null
        }

        Copy-Item -Path $DownloadedPath -Destination $TargetPath -Force
        Write-Log -Message "Theme installed to: $TargetPath" -Level "INFO"
    } catch {
        Write-Log -Message "Failed to copy theme to target location: $_" -Level "ERROR"
    }
}

function Install-SyncTrayzor {
    $InstallerUrl  = "https://github.com/canton7/SyncTrayzor/releases/download/v1.1.29/SyncTrayzorSetup-x64.exe"
    $InstallerPath = Join-Path $InstallDir "SyncTrayzorSetup-x64.exe"

    try {
        Write-Log -Message "Downloading SyncTrayzor installer..." -Level "INFO"
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing -TimeoutSec 60
        Write-Log -Message "Download completed: $InstallerPath" -Level "INFO"
    } catch {
        Write-Log -Message "Failed to download SyncTrayzor installer: $_" -Level "ERROR"
        return
    }

    try {
        Write-Log -Message "Running SyncTrayzor installer..." -Level "INFO"
        Start-Process -FilePath $InstallerPath -ArgumentList "/SILENT" -Wait
        Write-Log -Message "SyncTrayzor installation completed." -Level "INFO"
    } catch {
        Write-Log -Message "Error during SyncTrayzor installation: $_" -Level "ERROR"
        return
    }
}

function Disable-SleepMode {
    try {
        $activePlan = powercfg /getactivescheme
        Write-Log -Message "Active power scheme: $activePlan" -Level "INFO"

        Write-Log -Message "Disabling sleep timeout for AC and DC..." -Level "INFO"
        powercfg /change standby-timeout-ac 0
        powercfg /change standby-timeout-dc 0

        Write-Log -Message "Sleep mode disabled successfully." -Level "INFO"
    } catch {
        Write-Log -Message "Failed to disable sleep mode: $_" -Level "ERROR"
    }
}

function Disable-Hibernation {
    try {
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Log -Message "Insufficient privileges: hibernation requires elevated rights." -Level "ERROR"
            return
        }

        Write-Log -Message "Disabling system hibernation..." -Level "INFO"
        $process = Start-Process -FilePath "powercfg.exe" -ArgumentList "/hibernate off" -Wait -PassThru -WindowStyle Hidden

        if ($process.ExitCode -eq 0) {
            Write-Log -Message "Hibernation disabled successfully." -Level "INFO"
        } else {
            Write-Log -Message "powercfg exited with code $($process.ExitCode)" -Level "ERROR"
        }
    } catch {
        Write-Log -Message "Failed to disable hibernation: $_" -Level "ERROR"
    }
}

function Set-PowerActionsToDoNothing {
    try {
        $schemeGuid = (powercfg /getactivescheme) -replace '.*GUID: ([a-f0-9\-]+).*', '$1'
        Write-Log -Message "Active power scheme GUID: $schemeGuid" -Level "INFO"

        $subgroup = "4f971e89-eebd-4455-a8de-9e59040e7347"  # Power buttons and lid

        $settings = @{
            "Power button action"     = "7648efa3-dd9c-4e3e-b566-50f929386280"
            "Sleep button action"     = "96996bc0-ad50-47ec-923b-6f41874dd9eb"
            "Lid close action"        = "5ca83367-6e45-459f-a27b-476b1d01c936"
        }

        foreach ($name in $settings.Keys) {
            $settingGuid = $settings[$name]
            Write-Log -Message "Setting '$name' to 'Do nothing'..." -Level "INFO"

            powercfg /setacvalueindex $schemeGuid $subgroup $settingGuid 0
            powercfg /setdcvalueindex $schemeGuid $subgroup $settingGuid 0
        }

        powercfg /S $schemeGuid
        Write-Log -Message "All power actions set to 'Do nothing'." -Level "INFO"
    } catch {
        Write-Log -Message "Failed to configure power actions: $_" -Level "ERROR"
    }
}
#function Set-PowerActionsToDoNothing {
#    try {
#        $schemeGuid = (powercfg /getactivescheme) -replace '.*GUID: ([a-f0-9\-]+).*', '$1'
#        Write-Log -Message "Active power scheme GUID: $schemeGuid" -Level "INFO"
#
#        $subgroup = "4f971e89-eebd-4455-a8de-9e59040e7347"  # Power buttons and lid
#
#        # Wykryj typ obudowy
#        $chassisTypes = (Get-CimInstance Win32_SystemEnclosure).ChassisTypes
#        $isLaptop = $chassisTypes -contains 8 -or $chassisTypes -contains 9 -or $chassisTypes -contains 10 -or $chassisTypes -contains 14
#
#        if ($isLaptop) {
#            Write-Log -Message "Device type: Laptop" -Level "INFO"
#        } else {
#            Write-Log -Message "Device type: Desktop or other" -Level "INFO"
#        }
#
#        $settings = @{}
#
#        $settings["Power button action"] = "7648efa3-dd9c-4e3e-b566-50f929386280"
#        $settings["Sleep button action"] = "96996bc0-ad50-47ec-923b-6f41874dd9eb"
#
#        if ($isLaptop) {
#            $settings["Lid close action"] = "5ca83367-6e45-459f-a27b-476b1d01c936"
#        }
#
#        foreach ($name in $settings.Keys) {
#            $settingGuid = $settings[$name]
#            Write-Log -Message "Setting '$name' to 'Do nothing'..." -Level "INFO"
#
#            powercfg /setacvalueindex $schemeGuid $subgroup $settingGuid 0
#            powercfg /setdcvalueindex $schemeGuid $subgroup $settingGuid 0
#        }
#
#        powercfg /S $schemeGuid
#        Write-Log -Message "All applicable power actions set to 'Do nothing'." -Level "INFO"
#    } catch {
#        Write-Log -Message "Failed to configure power actions: $_" -Level "ERROR"
#    }
#}


function Configure-WindowsSettings {
    Disable-SleepMode
    Disable-Hibernation
    Set-PowerActionsToDoNothing

    try {
        $osVersion = (Get-CimInstance Win32_OperatingSystem).Caption
        Write-Log -Message "Detected OS: $osVersion" -Level "INFO"

        if ($osVersion -match "Windows 11") {
            Write-Log -Message "Applying Windows 11 registry tweak..." -Level "INFO"

            $regCommand = 'reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve'
            $regProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $regCommand" -Wait -PassThru -WindowStyle Hidden

            if ($regProcess.ExitCode -eq 0) {
                Write-Log -Message "Registry tweak applied successfully." -Level "INFO"
            } else {
                Write-Log -Message "Registry command failed with exit code $($regProcess.ExitCode)" -Level "ERROR"
            }

            Write-Log -Message "Restarting explorer.exe..." -Level "INFO"
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Process -FilePath "explorer.exe"
            Write-Log -Message "explorer.exe restarted." -Level "INFO"
        }
    } catch {
        Write-Log -Message "Failed to apply Windows 11 tweak: $_" -Level "ERROR"
    }
}

# ───── Dispatcher ─────
function Run-SelectedModules($selectedModules) {
    foreach ($module in $selectedModules) {
        if (-not $module.Enabled) { continue }
        Write-Log "Executing: $($module.Name)" "INFO"

        switch ($module.Name) {
            "Install Ninite"       { Install-NiniteBundle }
            "Install DirectX"      { Install-DirectX }
            "Install AdGuard"      { Install-AdGuard }
            "Install Foobar2000 + plugins" { Install-Foobar2000WithPlugins }
            "Install Foobar2000 theme by author" { Install-FoobarThemeFromGitHub }
            "Install SyncTrayzor" { Install-SyncTrayzor }
            "Configure Windows" { Configure-WindowsSettings }
            default {
                Write-Log "No implementation for: $($module.Name)" "WARN"
                Start-Sleep -Milliseconds 500
            }
        }
    }
}

# ───── Main ─────
Ensure-AdminRightsOnly
$selected = Show-InteractiveModuleSelector

if (-not (Test-InternetConnection)) {
    Write-Log "No internet connection detected. Terminating script." "ERROR"
    Write-Host "`nNo internet connection. Press any key to exit..." -ForegroundColor Red
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Run-SelectedModules $selected

Write-Log "Script completed." "INFO"

#Write-Host "`n`nNow the INSTALLfiles directory will be deleted...`nPress any key to continue..." -ForegroundColor DarkGray
#$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#if (Test-Path $InstallDir) {
#    try {
#        Remove-Item -Path $InstallDir -Recurse -Force
#        Write-Log "INSTALLfiles directory removed after completion." "DEBUG"
#    } catch {
#        Write-Log "Failed to remove INSTALLfiles: $_" "WARN"
#    }
#}
if (Test-Path $InstallDir) {
    Write-Host "`nDo you want to delete the INSTALLfiles directory? [Y/N]" -ForegroundColor Yellow
    $response = Read-Host "Type Y or YES to confirm"

    if ($response -match '^(Y|YES)$') {
        try {
            Remove-Item -Path $InstallDir -Recurse -Force
            Write-Log "INSTALLfiles directory removed after user confirmation." "DEBUG"
        } catch {
            Write-Log "Failed to remove INSTALLfiles: $_" "WARN"
        }
    } else {
        Write-Log "INSTALLfiles directory preserved by user choice." "INFO"
    }
}

Write-Host "`n`nPress any key to exit..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
exit
