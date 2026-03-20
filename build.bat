@echo off
cd /d C:\Users\garro\TEC\Paradigmas\BankTec

echo [1/2] Ensamblando con OpenWatcom WASM...
C:\WATCOM\binnt\wasm.exe -ms banktec.asm
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Fallo el ensamblado.
    pause
    exit /b 1
)

echo [2/2] Enlazando para DOS con WLINK...
C:\WATCOM\binnt\wlink.exe @banktec.lnk
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Fallo el enlace.
    pause
    exit /b 1
)

echo.
echo ============================
echo  Listo! banktec.exe generado
echo  Abrelo en DOSBox con:
echo    abrir_dosbox.bat
echo    banktec
echo ============================
pause
