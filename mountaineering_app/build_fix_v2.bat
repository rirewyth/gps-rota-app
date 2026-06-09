@echo off
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "PATH=%JAVA_HOME%\bin;%PATH%"
cd /d "c:\213\mountaineering_app\android"
gradlew.bat assembleRelease --stacktrace --info > ..\gradle_log.txt 2>&1
