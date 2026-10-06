@echo off
title Prothesa Util - drg. Danny Hanggono
echo Memulai Prothesa Util (GUI)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0ProthesaWinUtil.ps1"
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Prothesa Util gagal dijalankan (Exit Code: %errorlevel%).
    echo Silakan jalankan langsung di PowerShell untuk melihat pesan error detail:
    echo powershell.exe -ExecutionPolicy Bypass -STA -File "%~dp0ProthesaWinUtil.ps1"
    echo.
    pause
)