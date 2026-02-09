@echo off
echo ================================
echo ProjectPulse - Deploy to Testers
echo ================================
echo.

echo [1/3] Building debug APK...
call flutter build apk --debug
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Build failed!
    exit /b 1
)

echo.
echo [2/3] Uploading to Firebase App Distribution...
call firebase appdistribution:distribute build/app/outputs/flutter-apk/app-debug.apk --app 1:714963430501:android:59c8f4fb867a4d80c22a84 --groups "testers" --release-notes "Latest updates"
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Upload failed!
    exit /b 1
)

echo.
echo [3/3] Done! Testers will be notified.
echo.
pause
