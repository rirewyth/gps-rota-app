@echo off
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "PATH=%JAVA_HOME%\bin;%PATH%"
cd /d "c:\213\mountaineering_app"
call C:\flutter\bin\flutter.bat build apk --release --no-pub
pause
