@echo off
rem ============================================================
rem  verasdformat - build script
rem  Assembles verasdformat.asm + compiles verasdformat_startup.bas,
rem  then packs them onto a ProDOS 2.4.3 disk image
rem  (base/ProDOS_2_4_3.po) to produce verasdformat.po.
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

node verasdformat.mjs
if errorlevel 1 (
  echo [ERROR] Build failed - no verasdformat.po produced.
  exit /b 1
)

echo.
echo Build OK: %~dp0verasdformat.po
exit /b 0
