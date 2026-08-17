@echo off
REM 本脚本由 install.ps1 承载主体逻辑；直接双击本文件会调起 PowerShell 执行。
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
