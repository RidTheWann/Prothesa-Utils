:: PROTHESA MANAGER LAUNCHER
@echo off
chcp 65001 >nul
title Prothesa Manager - drg. Danny Hanggono
mode con: cols=100 lines=35
echo Loading Prothesa Manager...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0ProthesaManager.ps1"
pause
