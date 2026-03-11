@echo off
setlocal enabledelayedexpansion

title Pipescreen

set "CONFIG_FILE=%USERPROFILE%\.pipescreen.conf.bat"
set "DATA_DIR="
set "PORT=3030"
if exist "%CONFIG_FILE%" call "%CONFIG_FILE%"
set "API=http://localhost:%PORT%"

if "%~1"=="--quick" goto :quick_start
if "%~1"=="-q" goto :quick_start

:menu
cls
echo.
echo   ========================================
echo            PIPESCREEN
echo     Screen + Life Timeline Recorder
echo   ========================================
echo.
echo   API: %API%
if defined DATA_DIR if not "!DATA_DIR!"=="" echo   Data dir: !DATA_DIR!
echo.

curl -s --max-time 2 %API%/health >nul 2>&1
if !errorlevel!==0 (
    echo   Status: [RECORDING]
) else (
    echo   Status: [STOPPED]
)
echo.
echo   [1] Start recording
echo   [2] Stop recording
echo   [3] Search screen history
echo   [4] View data info
echo   [5] Settings
echo   [6] Install / update screenpipe
echo   [q] Quit
echo.
set "choice="
set /p "choice=  > "

if "!choice!"=="1" goto :start_rec
if "!choice!"=="2" goto :stop_rec
if "!choice!"=="3" goto :search
if "!choice!"=="4" goto :data_info
if "!choice!"=="5" goto :config
if "!choice!"=="6" goto :install
if /i "!choice!"=="q" goto :quit
goto :menu

:start_rec
curl -s --max-time 2 %API%/health >nul 2>&1
if !errorlevel!==0 (
    echo.
    echo   Already running.
    timeout /t 2 >nul
    goto :menu
)

call :find_bin
if "!SP_BIN!"=="" (
    echo   screenpipe not found. Install first [option 6].
    timeout /t 3 >nul
    goto :menu
)

echo.
echo   Starting screenpipe...
if defined DATA_DIR if not "!DATA_DIR!"=="" (
    start "screenpipe" cmd /c ""!SP_BIN!" record --port %PORT% --data-dir "!DATA_DIR!""
) else (
    start "screenpipe" cmd /c ""!SP_BIN!" record --port %PORT%"
)

for /l %%i in (1,1,30) do (
    timeout /t 2 >nul
    curl -s --max-time 2 %API%/health >nul 2>&1
    if !errorlevel!==0 (
        echo   Started!
        timeout /t 1 >nul
        goto :menu
    )
)
echo   Started but API not ready yet. Check later.
timeout /t 3 >nul
goto :menu

:stop_rec
echo.
echo   Stopping screenpipe...
taskkill /F /IM screenpipe.exe >nul 2>&1
timeout /t 1 >nul
curl -s --max-time 2 %API%/health >nul 2>&1
if !errorlevel!==0 (
    echo   Failed to stop.
) else (
    echo   Stopped.
)
timeout /t 2 >nul
goto :menu

:search
curl -s --max-time 2 %API%/health >nul 2>&1
if not !errorlevel!==0 (
    echo   Not running. Start first.
    timeout /t 2 >nul
    goto :menu
)
echo.
set "query="
set "limit="
set /p "query=  Search query (empty=recent): "
set /p "limit=  Limit [5]: "
if "!limit!"=="" set "limit=5"
set "url=%API%/search?limit=!limit!"
if not "!query!"=="" set "url=!url!&q=!query!"
echo.
curl -s "!url!"
echo.
echo.
pause
goto :menu

:data_info
echo.
set "DPATH=%USERPROFILE%\.screenpipe"
if defined DATA_DIR if not "!DATA_DIR!"=="" set "DPATH=!DATA_DIR!"
echo   Data location: !DPATH!
echo.
if exist "!DPATH!\db.sqlite" (
    for %%A in ("!DPATH!\db.sqlite") do set /a "dbsize=%%~zA / 1024 / 1024"
    echo   db.sqlite: ~!dbsize! MB
) else (
    echo   No database yet.
)
if exist "!DPATH!\data" (
    set "fcount=0"
    for /f %%N in ('dir /s /b "!DPATH!\data\*" 2^>nul ^| find /c /v ""') do set "fcount=%%N"
    echo   Media files: !fcount! files
)
echo.
pause
goto :menu

:config
echo.
echo   Current config:
if defined DATA_DIR if not "!DATA_DIR!"=="" (
    echo   Data dir: !DATA_DIR!
) else (
    echo   Data dir: default
)
echo   Port: %PORT%
echo.
echo   [1] Pick data folder
echo   [2] Reset to default
echo   [3] Change port
echo   [Enter] Back
echo.
set "cchoice="
set /p "cchoice=  > "

if "!cchoice!"=="1" goto :pick_folder
if "!cchoice!"=="2" (
    set "DATA_DIR="
    echo   Reset to default.
    goto :save_config
)
if "!cchoice!"=="3" goto :change_port
goto :menu

:pick_folder
for /f "delims=" %%F in ('powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description = 'Select screenpipe data folder'; $d.ShowNewFolderButton = $true; if ($d.ShowDialog() -eq 'OK') { $d.SelectedPath } else { '' }"') do set "picked=%%F"
if "!picked!"=="" (
    echo   Cancelled.
    timeout /t 1 >nul
    goto :menu
)
set "DATA_DIR=!picked!"
echo   Set to: !DATA_DIR!
goto :save_config

:change_port
set "new_port="
set /p "new_port=  New port [%PORT%]: "
if not "!new_port!"=="" (
    set "PORT=!new_port!"
    set "API=http://localhost:!new_port!"
)
goto :save_config

:save_config
(
    echo set "DATA_DIR=!DATA_DIR!"
    echo set "PORT=!PORT!"
) > "%CONFIG_FILE%"
echo   Config saved.
timeout /t 2 >nul
goto :menu

:install
call :find_bin
if not "!SP_BIN!"=="" (
    echo   Already installed: !SP_BIN!
    "!SP_BIN!" --version 2>nul
    timeout /t 2 >nul
    goto :menu
)
echo   Installing...
npm install -g screenpipe@latest --ignore-scripts
call :find_bin
if not "!SP_BIN!"=="" (
    echo   Installed!
) else (
    echo   May need terminal restart.
)
timeout /t 3 >nul
goto :menu

:quick_start
call :find_bin
if "!SP_BIN!"=="" (
    echo screenpipe not found.
    pause
    exit /b 1
)
if defined DATA_DIR if not "!DATA_DIR!"=="" (
    "!SP_BIN!" record --port %PORT% --data-dir "!DATA_DIR!"
) else (
    "!SP_BIN!" record --port %PORT%
)
pause
exit /b 0

:quit
endlocal
exit /b 0

:find_bin
set "SP_BIN="
where screenpipe >nul 2>&1
if !errorlevel!==0 (
    set "SP_BIN=screenpipe"
    goto :eof
)
set "NPM_BIN=%APPDATA%\npm\node_modules\screenpipe\node_modules\@screenpipe\cli-win32-x64\bin\screenpipe.exe"
if exist "!NPM_BIN!" (
    set "SP_BIN=!NPM_BIN!"
    goto :eof
)
goto :eof
