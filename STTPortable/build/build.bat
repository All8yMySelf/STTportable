@echo off
setlocal ENABLEDELAYEDEXPANSION

set SCRIPT_DIR=%~dp0
set ROOT_DIR=%SCRIPT_DIR%..\
set SRC=%ROOT_DIR%src\TalkPaste.ahk
set OUT=%SCRIPT_DIR%TalkPaste.exe
set ICON=%ROOT_DIR%src\mic.ico

if not exist "%SRC%" (
    echo Source script not found: %SRC%
    exit /b 1
)

set AHK_COMPILER=Ahk2Exe.exe
where %AHK_COMPILER% >nul 2>&1
if errorlevel 1 (
    echo Ahk2Exe compiler not found in PATH.
    echo Install AutoHotkey v2 and ensure Ahk2Exe.exe is available.
    exit /b 1
)

del "%OUT%" >nul 2>&1

set CMD="%AHK_COMPILER%" /in "%SRC%" /out "%OUT%"
if exist "%ICON%" (
    set CMD=%CMD% /icon "%ICON%"
)

echo Compiling TalkPaste...
%CMD%
if errorlevel 1 (
    echo Compilation failed.
    exit /b 1
)

echo Output: %OUT%
exit /b 0
