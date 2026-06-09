Set-Location "c:\213\mountaineering_app"
$env:PATH = "C:\flutter\bin;" + $env:PATH
& "C:\flutter\bin\flutter.bat" pub get 2>&1 | Out-String | Write-Host
& "C:\flutter\bin\flutter.bat" build apk --release 2>&1 | Out-String | Write-Host
Write-Host "Exit code: $LASTEXITCODE"
# APK'yi bul ve masaustune kopyala
$apk = Get-ChildItem -Path "c:\213\mountaineering_app\android\app\build\outputs\apk\release" -Recurse -Filter "app-release.apk" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($apk) {
    Copy-Item $apk.FullName "c:\213\RotaPlus.apk" -Force
    Write-Host "APK KOPYALANDI: c:\213\RotaPlus.apk"
} else {
    Write-Host "APK BULUNAMADI, gradle outputlarina bakiliyor..."
    Get-ChildItem -Path "c:\213\mountaineering_app\build" -Recurse -Include "*.apk" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_.FullName }
}
