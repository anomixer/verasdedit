@echo off
rem ============================================================
rem  verasdedit - build script
rem  Assembles verasdedit.asm + compiles startup.bas, then packs
rem  them onto a ProDOS 2.4.3 disk image (base/ProDOS_2_4_3.po)
rem  to produce verasdedit.po.
rem
rem  Prerequisite: Node.js (ESM support) on PATH.
rem ============================================================
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Node.js not found on PATH.
  echo         Install from https://nodejs.org then retry.
  exit /b 1
)

node verasdedit.mjs
if errorlevel 1 (
  echo [ERROR] Build failed - no verasdedit.po produced.
  exit /b 1
)

echo.
echo Build OK: %~dp0verasdedit.po
exit /b 0
