@echo off
setlocal

where node >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Node.js not found on PATH.
  exit /b 1
)

set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=all"
if /I "%TARGET%"=="verasdedit" goto edit
if /I "%TARGET%"=="verasdformat" goto format
if /I "%TARGET%"=="all" goto all

echo Usage: build.bat [verasdedit^|verasdformat^|all]
exit /b 1

:edit
node src\verasdedit\verasdedit.mjs
exit /b %ERRORLEVEL%

:format
node src\verasdformat\verasdformat.mjs
exit /b %ERRORLEVEL%

:all
node src\verasdedit\verasdedit.mjs
if errorlevel 1 exit /b 1
node src\verasdformat\verasdformat.mjs
exit /b %ERRORLEVEL%
