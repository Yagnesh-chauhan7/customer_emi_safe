@echo off
echo ============================================
echo   Customer EMI Safe - Auto Setup Tool
echo ============================================
echo.

:: Check adb connection
echo [1/4] Checking device connection...
adb devices
echo.

:: Check if device is connected
for /f "skip=1 tokens=1" %%d in ('adb devices') do (
    if "%%d" NEQ "" (
        set DEVICE=%%d
    )
)

if "%DEVICE%"=="" (
    echo ERROR: No device found! USB Debugging enable karo.
    pause
    exit /b 1
)

echo Device found: %DEVICE%
echo.

:: Install APK
echo [2/4] Installing Customer EMI Safe APK...
adb install -r "app-release.apk"
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: APK install failed!
    pause
    exit /b 1
)
echo APK installed successfully!
echo.

:: Set Device Owner
echo [3/4] Setting Device Owner...
adb shell dpm set-device-owner com.example.customer_emi_app/.MyDeviceAdminReceiver
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Device Owner set nahi hua!
    echo Reason: Shayad pehle se koi Google account add hai.
    echo Fix: Phone factory reset karo aur dobara try karo.
    pause
    exit /b 1
)
echo.

:: Launch app
echo [4/4] Starting Customer EMI Safe...
adb shell am start -n com.example.customer_emi_app/.MainActivity
echo.

echo ============================================
echo   SETUP COMPLETE! Device Owner set ho gaya
echo ============================================
pause
