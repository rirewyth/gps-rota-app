Set-Location "c:\213\mountaineering_app"
$env:PATH = "C:\flutter\bin;" + $env:PATH
& "C:\flutter\bin\flutter.bat" build aab --release 2>&1 | Out-String | Write-Host
Write-Host "Exit code: $LASTEXITCODE"
# AAB'yi bul ve kopyala
$aab = Get-ChildItem -Path "c:\213\mountaineering_app\build\app\outputs\bundle\release" -Recurse -Filter "app-release.aab" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($aab) {
    Copy-Item $aab.FullName "c:\213\RotaPlus.aab" -Force
    Write-Host "AAB KOPYALANDI: c:\213\RotaPlus.aab"
} else {
    Write-Host "AAB BULUNAMADI, ciktilara bakiliyor..."
}
