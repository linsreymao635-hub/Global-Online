@echo off
REM ============================================================
REM  Global Online - run the two frontends independently
REM
REM  Both apps share ONE backend (the Supabase cloud database),
REM  so everything you change in the admin app appears in the
REM  user app instantly, and the other way around.
REM
REM  NOTE: On this computer the admin app runs in Chrome because
REM  Visual Studio (Windows desktop builds) is not installed.
REM ============================================================

if "%1"=="admin" goto admin
if "%1"=="user" goto user
if "%1"=="phone" goto phone
if "%1"=="both" goto both

echo Usage: run.bat admin ^| user ^| phone ^| both
echo.
echo   run.bat admin           - ADMIN dashboard in Chrome
echo   run.bat user            - USER shop app in Chrome
echo   run.bat phone           - USER shop app on a connected Android phone
echo   run.bat both            - ADMIN in Chrome + USER in Chrome together
goto :eof

:admin
REM --web-port pins the address (e.g. http://localhost:53336) so it can be
REM registered once as an "Authorized JavaScript origin" for Google Sign-In.
flutter run -d chrome --web-port=53336 -t lib/main_admin.dart
goto :eof

:user
flutter run -d chrome --web-port=53335 -t lib/main_user.dart
goto :eof

:phone
flutter run -t lib/main_user.dart
goto :eof

:both
start "Global Online - ADMIN" cmd /k flutter run -d chrome --web-port=53336 -t lib/main_admin.dart
start "Global Online - USER" cmd /k flutter run -d chrome --web-port=53335 -t lib/main_user.dart
goto :eof
