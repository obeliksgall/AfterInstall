param (
    [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
    [string]$LogLevel = "DEBUG",

    [int]$RetentionDays = 7,

    [switch]$SilentStart,
    [switch]$SkipNinite,
    [switch]$SkipDirectX,
    [switch]$SkipPowerConfig,
    [switch]$SkipElevation,
    [switch]$SkipAdGuard,
    [switch]$SkipFoobar2000,
    [switch]$SkipFoobar2000Plugin,
    [switch]$SkipFoobarThemeFromGitHub,
    [switch]$SkipFoobarPlaybackStats
)


# Map log levels to priorities
$LogPriority = @{
    INFO  = 1
    WARN  = 2
    ERROR = 3
    DEBUG = 4
}

# Console colors for log levels
$LogColor = @{
    INFO  = "Green"
    WARN  = "Yellow"
    ERROR = "Red"
    DEBUG = "Cyan"
}

# Get script name without extension
$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)

# Define log directory
$LogDir = Join-Path -Path $PSScriptRoot -ChildPath "LOGs"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory | Out-Null
}

# Delete old logs based on retention policy
Get-ChildItem -Path $LogDir -File | Where-Object {
    $_.Name -like "$ScriptName*_*.txt" -and $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays)
} | Remove-Item -Force

# Rotate daily logs with versioning
function Rotate-Log {
    $CurrentLog = Join-Path $LogDir "$ScriptName`_current.txt"
    if (Test-Path $CurrentLog) {
        $LastWriteDate = (Get-Item $CurrentLog).LastWriteTime.Date
        $Today = (Get-Date).Date
        if ($LastWriteDate -ne $Today) {
            $BaseName = "$ScriptName" + "_" + $LastWriteDate.ToString("yyyy_MM_dd")
            $ArchivedPath = Join-Path $LogDir "$BaseName.txt"

            # Add version suffix if file already exists
            $counter = 1
            while (Test-Path $ArchivedPath) {
                $ArchivedPath = Join-Path $LogDir "$BaseName" + "_$counter.txt"
                $counter++
            }

            Rename-Item -Path $CurrentLog -NewName (Split-Path $ArchivedPath -Leaf)
        }
    }
}

# Write log entry to console and file
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

        $LogPath = Join-Path $LogDir "$ScriptName`_current.txt"
        Add-Content -Path $LogPath -Value $Formatted
    }
}



function Ensure-Elevation {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Log -Message "Script not running as administrator. Relaunching with elevation..." -Level "WARN"

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $psi.Verb = "runas"
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            exit
        } catch {
            Write-Log -Message "User declined elevation. Script cannot continue." -Level "ERROR"
            exit 1
        }
    } else {
        Write-Log -Message "Script running with administrator privileges." -Level "INFO"
    }
}
if (-not $SkipElevation) {
    Ensure-Elevation
}



function Show-StartupPrompt {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "This script will perform the following tasks:" -ForegroundColor Cyan
    Write-Host "- Check internet connectivity"
    Write-Host "- Download and install selected applications via Ninite"
    Write-Host ".net4.8.1, .netx8, .netx9, 7zip, aspnetx8, aspnetx9, chrome"
    Write-Host "discord, keepass2, notepadplusplus, putty, steam, vcredist05"
    Write-Host "vcredist08, vcredist10, vcredist12, vcredist13, vcredist15"
    Write-Host "vcredistx05, vcredistx08, vcredistx10, vcredistx12, vcredistx13"
    Write-Host "vcredistx15, vlc, winscp"
    Write-Host "- Install DirectX runtime"
    Write-Host "- Disable sleep and hibernation modes"
    Write-Host "- Configure system for deployment"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "Press any key to continue or [0] to exit..." -ForegroundColor Yellow

    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
    if ($key -eq '0') {
        Write-Host "Exiting script as requested." -ForegroundColor Red
        exit
    }
}
if (-not $SilentStart) {
    Show-StartupPrompt
}




# Check internet connectivity with fallback to 8.8.8.8
function Test-InternetConnection {
    $TestUri = "https://www.microsoft.com"
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
    $InstallerPath = Join-Path $env:TEMP "ninite_installer.exe"

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
    $InstallerPath = Join-Path $env:TEMP "dxwebsetup.exe"

    try {
        Write-Log -Message "Downloading DirectX installer..." -Level "INFO"
        Invoke-WebRequest -Uri $DirectXUrl -OutFile $InstallerPath -UseBasicParsing -TimeoutSec 30
        Write-Log -Message "Download completed: $InstallerPath" -Level "INFO"
    } catch {
        Write-Log -Message "Failed to download DirectX installer: $_" -Level "ERROR"
        exit 1
    }

    try {
        Write-Log -Message "Running DirectX installer silently..." -Level "INFO"
        Start-Process -FilePath $InstallerPath -ArgumentList "/Q" -Wait
        Write-Log -Message "DirectX installation completed." -Level "INFO"
    } catch {
        Write-Log -Message "Error during DirectX installation: $_" -Level "ERROR"
        exit 1
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
        exit 1
    }
}

#function Disable-Hibernation {
#    try {
#        Write-Log -Message "Disabling system hibernation..." -Level "INFO"
#        powercfg.exe /hibernate off
#        Write-Log -Message "Hibernation disabled successfully." -Level "INFO"
#    } catch {
#        Write-Log -Message "Failed to disable hibernation: $_" -Level "ERROR"
#        exit 1
#    }
#}
function Disable-Hibernation {
    try {
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Log -Message "Insufficient privileges: hibernation requires elevated rights." -Level "ERROR"
            exit 1
        }

        Write-Log -Message "Disabling system hibernation..." -Level "INFO"
        $process = Start-Process -FilePath "powercfg.exe" -ArgumentList "/hibernate off" -Wait -PassThru -WindowStyle Hidden

        if ($process.ExitCode -eq 0) {
            Write-Log -Message "Hibernation disabled successfully." -Level "INFO"
        } else {
            Write-Log -Message "powercfg exited with code $($process.ExitCode)" -Level "ERROR"
            exit 1
        }
    } catch {
        Write-Log -Message "Failed to disable hibernation: $_" -Level "ERROR"
        exit 1
    }
}

function Install-AdGuard {
    $AdGuardUrl = "https://download.adguardcdn.com/d/18675/adguardInstaller.exe"
    $InstallerPath = Join-Path $env:TEMP "adguardInstaller.exe"

    try {
        Write-Log -Message "Downloading AdGuard installer..." -Level "INFO"
        Invoke-WebRequest -Uri $AdGuardUrl -OutFile $InstallerPath -UseBasicParsing -TimeoutSec 30
        Write-Log -Message "Download completed: $InstallerPath" -Level "INFO"
    } catch {
        Write-Log -Message "Failed to download AdGuard installer: $_" -Level "ERROR"
        exit 1
    }

    try {
        #Write-Log -Message "Running AdGuard installer silently..." -Level "INFO"
        #Start-Process -FilePath $InstallerPath -ArgumentList "/silent" -Wait
        Write-Log -Message "Running AdGuard installer..." -Level "INFO"
        Start-Process -FilePath $InstallerPath -ArgumentList "/silent" -Wait
        Write-Log -Message "AdGuard installation completed." -Level "INFO"
    } catch {
        Write-Log -Message "Error during AdGuard installation: $_" -Level "ERROR"
        exit 1
    }
}

function Install-Foobar2000 {
    #$FoobarUrl = "https://www.foobar2000.org/getfile/foobar2000_v2.25.1.exe"
    $FoobarUrl = "https://www.foobar2000.org/files/foobar2000_v2.25.1.exe"
    $InstallerPath = Join-Path $env:TEMP "foobar2000_installer.exe"

    try {
        Write-Log -Message "Downloading Foobar2000 installer..." -Level "INFO"
        Invoke-WebRequest -Uri $FoobarUrl -OutFile $InstallerPath -UseBasicParsing -TimeoutSec 30
        Write-Log -Message "Download completed: $InstallerPath" -Level "INFO"
    } catch {
        Write-Log -Message "Failed to download Foobar2000 installer: $_" -Level "ERROR"
        exit 1
    }

    try {
        Write-Log -Message "Running Foobar2000 installer silently..." -Level "INFO"
        Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait
        Write-Log -Message "Foobar2000 installation completed." -Level "INFO"
    } catch {
        Write-Log -Message "Error during Foobar2000 installation: $_" -Level "ERROR"
        exit 1
    }
}

function Install-FoobarPlugins {
    $PluginUrls = @(
        "https://www.foobar2000.org/getcomponent/98881927bed68c4073b776720dcf9ec6/foo_beefweb-0.7.fb2k-component",
        "https://www.foobar2000.org/getcomponent/ed22ac55275a5ab35faebb16e7b172aa/foo_openlyrics-v1.6.fb2k-component",
        "https://www.foobar2000.org/getcomponent/4562cb1682a7de50b241ab489ebd49d2/foo_playcount.fb2k-component",
        "https://www.foobar2000.org/getcomponent/c0646634c03ffe6084a9cacda374d196/foo_wave_seekbar-0.2.45.fb2k-component",
        "https://www.foobar2000.org/getcomponent/8febb9df1bbeabf041f1965e6fbb6e96/foo_dsp_xgeq.zip"
    )

    $FoobarComponentDir = "$env:ProgramFiles (x86)\foobar2000\components"
    if (-not (Test-Path $FoobarComponentDir)) {
        Write-Log -Message "Foobar2000 not found at expected path: $FoobarComponentDir" -Level "ERROR"
        exit 1
    }

    foreach ($url in $PluginUrls) {
        $fileName = Split-Path $url -Leaf
        $tempPath = Join-Path $env:TEMP $fileName

        try {
            Write-Log -Message "Downloading plugin: $fileName" -Level "INFO"
            Invoke-WebRequest -Uri $url -OutFile $tempPath -UseBasicParsing -TimeoutSec 30
        } catch {
            Write-Log -Message "Failed to download $fileName : $_" -Level "ERROR"
            continue
        }

        if ($fileName -like "*.zip") {
            $extractPath = Join-Path $env:TEMP "foobar_plugin_extract"
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
    }
}

function Install-FoobarThemeFromGitHub {
    $ThemeUrl = "https://github.com/obeliksgall/AfterInstall/raw/refs/heads/main/foobar2000/foobar2000theme_last.fth"
    $ThemeFileName = "foobar2000theme_last.fth"
    $FoobarThemeDir = Join-Path $env:APPDATA "foobar2000\themes"

    if (-not (Test-Path $FoobarThemeDir)) {
        Write-Log -Message "Creating theme directory: $FoobarThemeDir" -Level "INFO"
        New-Item -Path $FoobarThemeDir -ItemType Directory | Out-Null
    }

    $DestinationPath = Join-Path $FoobarThemeDir $ThemeFileName

    try {
        Write-Log -Message "Downloading theme from GitHub..." -Level "INFO"
        Invoke-WebRequest -Uri $ThemeUrl -OutFile $DestinationPath -UseBasicParsing -TimeoutSec 30
        Write-Log -Message "Theme downloaded to: $DestinationPath" -Level "INFO"
    } catch {
        Write-Log -Message "Failed to download theme: $_" -Level "ERROR"
        exit 1
    }
}

function Restore-FoobarPlaybackStats {
    $LocalFile = Join-Path $PSScriptRoot "foobar2000PlaybackStatistics.xml"
    $TargetPath = Join-Path $env:APPDATA "foobar2000\PlaybackStatistics.xml"

    if (-not (Test-Path $LocalFile)) {
        Write-Log -Message "Playback statistics file not found: $LocalFile" -Level "ERROR"
        exit 1
    }

    try {
        Write-Log -Message "Restoring playback statistics from local file..." -Level "INFO"
        Copy-Item -Path $LocalFile -Destination $TargetPath -Force
        Write-Log -Message "Playback statistics restored successfully to $TargetPath" -Level "INFO"
    } catch {
        Write-Log -Message "Failed to restore playback statistics: $_" -Level "ERROR"
        exit 1
    }
}

function Install-MSIAfterburner {
    $ZipUrl = "https://download.msi.com/uti_exe/vga/MSIAfterburnerSetup.zip"
    $TempZip = Join-Path $env:TEMP "MSIAfterburner.zip"
    $ExtractPath = Join-Path $env:TEMP "MSIAfterburnerExtract"

    try {
        Write-Log -Message "Downloading MSI Afterburner installer..." -Level "INFO"
        Invoke-WebRequest -Uri $ZipUrl -OutFile $TempZip -UseBasicParsing -TimeoutSec 60

        if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }
        New-Item -Path $ExtractPath -ItemType Directory | Out-Null

        Expand-Archive -Path $TempZip -DestinationPath $ExtractPath -Force

        $SetupExe = Get-ChildItem -Path $ExtractPath -Filter "MSIAfterburnerSetup.exe" -Recurse | Select-Object -First 1
        if (-not $SetupExe) {
            Write-Log -Message "Installer not found in archive." -Level "ERROR"
            exit 1
        }

        Write-Log -Message "Running MSI Afterburner installer..." -Level "INFO"
        Start-Process -FilePath $SetupExe.FullName -ArgumentList "/S" -Wait
        Write-Log -Message "MSI Afterburner installation completed." -Level "INFO"
    } catch {
        Write-Log -Message "Failed to install MSI Afterburner: $_" -Level "ERROR"
        exit 1
    }
}
function Install-AfterburnerOverlay {
    $OverlayUrl = "https://github.com/obeliksgall/AfterInstall/raw/refs/heads/main/MSIAfterburnerOverlay/MyOverlay.ovl"
    $OverlayName = "MyOverlay.ovl"
    $TargetDir = "$env:ProgramFiles(x86)\RivaTuner Statistics Server\Profiles"
    $TargetPath = Join-Path $TargetDir $OverlayName

    if (-not (Test-Path $TargetDir)) {
        Write-Log -Message "Overlay target folder not found: $TargetDir" -Level "ERROR"
        exit 1
    }

    try {
        Write-Log -Message "Downloading overlay from GitHub..." -Level "INFO"
        Invoke-WebRequest -Uri $OverlayUrl -OutFile $TargetPath -UseBasicParsing -TimeoutSec 30
        Write-Log -Message "Overlay installed to: $TargetPath" -Level "INFO"
    } catch {
        Write-Log -Message "Failed to install overlay: $_" -Level "ERROR"
        exit 1
    }
}

function Install-SyncTrayzor {
    $InstallerUrl = "https://github.com/canton7/SyncTrayzor/releases/download/v1.1.29/SyncTrayzorSetup-x64.exe"
    $InstallerPath = Join-Path $env:TEMP "SyncTrayzorSetup-x64.exe"

    try {
        Write-Log -Message "Downloading SyncTrayzor installer..." -Level "INFO"
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing -TimeoutSec 60

        Write-Log -Message "Running SyncTrayzor installer silently..." -Level "INFO"
        Start-Process -FilePath $InstallerPath -ArgumentList "/SILENT" -Wait
        Write-Log -Message "SyncTrayzor installation completed." -Level "INFO"
    } catch {
        Write-Log -Message "Failed to install SyncTrayzor: $_" -Level "ERROR"
        exit 1
    }
}
function Install-StreamDeck {
    $InstallerUrl = "https://edge.elgato.com/egc/windows/sd/Stream_Deck_7.0.1.22055.msi"
    $InstallerPath = Join-Path $env:TEMP "StreamDeckSetup.exe"

    try {
        Write-Log -Message "Downloading Elgato Stream Deck installer..." -Level "INFO"
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing -TimeoutSec 60

        Write-Log -Message "Running Stream Deck installer silently..." -Level "INFO"
        Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait
        Write-Log -Message "Stream Deck installation completed." -Level "INFO"
    } catch {
        Write-Log -Message "Failed to install Stream Deck: $_" -Level "ERROR"
        exit 1
    }
}



# Abort script if no internet connection
if (-not (Test-InternetConnection)) {
    Write-Log -Message "No internet connection detected terminating script." -Level "ERROR"
    exit 1
}

# Proceed with installation
if (-not $SkipNinite) {
    Install-NiniteBundle
}

if (-not $SkipDirectX) {
    Install-DirectX
}

if (-not $SkipPowerConfig) {
    Disable-SleepMode
    Disable-Hibernation
}

if (-not $SkipAdguard) {
    Install-AdGuard
}

if (-not $SkipFoobar2000) {
    Install-Foobar2000
}

if (-not $SkipFoobar2000Plugin) {
    Install-FoobarPlugins
}

if (-not $SkipFoobarThemeFromGitHub) {
    Install-FoobarThemeFromGitHub
}

if (-not $SkipFoobarPlaybackStats) {
    Restore-FoobarPlaybackStats
}

Install-MSIAfterburner
Install-AfterburnerOverlay

Install-SyncTrayzor
Install-StreamDeck


# Main script logic
#for ($i = 1; $i -le 5; $i++) {
#    Write-Log -Message "This is INFO log number $i" -Level "INFO"
#    Write-Log -Message "This is WARN log number $i" -Level "WARN"
#    Write-Log -Message "This is ERROR log number $i" -Level "ERROR"
#    Write-Log -Message "This is DEBUG log number $i" -Level "DEBUG"
#    Start-Sleep -Seconds 5
#}
