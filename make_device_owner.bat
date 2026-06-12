@echo off
title EMI Locker - Device Owner Setup
color 0A
echo ===================================================================
echo          EMI Locker - Device Owner Setup Tool
echo ===================================================================
echo.
echo INSTRUCTIONS:
echo 1. Remove ALL accounts from the phone (Settings -^> Accounts -^> Remove).
echo 2. Enable Developer Options and turn on USB Debugging.
echo 3. Connect the phone to the computer via USB cable.
echo 4. Install the app on the phone first if not already installed.
echo.
echo Waiting for device... Please allow the USB Debugging popup on the phone!
adb wait-for-device
echo.
echo Device connected! Setting Device Owner...
adb shell dpm set-device-owner com.example.customer_emi_app/.MyDeviceAdminReceiver
echo.
echo ===================================================================
echo DONE! Read the message above.
echo - If it says "Success", the app is now permanently locked!
echo - If it says "Not allowed", you forgot to remove Google/Samsung accounts.
echo ===================================================================
pause
