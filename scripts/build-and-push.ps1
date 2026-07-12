# Baut den Debug-Build und schiebt die APK in den Downloads-Ordner des Handys.
# Installiert wird sie dann von Hand: einmal antippen, „Installieren".
#
# WOFÜR DAS GUT IST
# Xiaomi/Redmi/POCO (MIUI, HyperOS) verweigern jede Installation, die über ADB
# kommt — nachweislich jede: adb install, pm install aus der Shell, mit --user 0,
# mit vorgetäuschter Installationsquelle, session-basiert. MIUI weist noch den
# install-commit ab. Freischalten lässt sich das nur über die Entwickleroptionen
# „USB-Debugging (Sicherheitseinstellungen)" und „Über USB installieren", und die
# verlangen ein Mi-Konto UND eine eingelegte SIM-Karte.
#
# MIUI blockiert aber nur ADB — nicht den Nutzer. Eine APK, die im Dateimanager
# angetippt wird, installiert ganz normal. Genau das macht dieses Skript möglich:
# bauen, aufs Handy schieben, du tippst einmal.
#
# Auf jedem Nicht-Xiaomi-Gerät ist das unnötig — dort nimmst du "Bauen & auf
# Gerät starten", das installiert und startet vollautomatisch.

param([Parameter(Mandatory)][string]$App)

. "$PSScriptRoot\_env.ps1"
. "$PSScriptRoot\discover-apps.ps1"

$a      = Get-AppOrFail -Id $App
$serial = Get-ConnectedDevice

Write-Step "$($a.Name): bauen und aufs Handy schieben"
Write-Info "Projekt: $($a.Path)"
Write-Info "Gerät:   $serial"

# --- Bauen ------------------------------------------------------------------
Write-Step 'Gradle: assembleDebug'

$gradlew = Join-Path $a.Path 'gradlew.bat'
& $gradlew -p $a.Path 'assembleDebug' 2>&1 | Tee-Object -Variable gradleLines

if ($LASTEXITCODE -ne 0) {
    Stop-WithHint 'Der Gradle-Build ist fehlgeschlagen.' @(
        'Die Fehlermeldung steht oben im Terminal.',
        'Bleibt es unklar: Task "Build-Ordner aufräumen" ausführen und erneut bauen.'
    )
}
Write-Ok 'Build erfolgreich.'

# --- APK sichern ------------------------------------------------------------
$apk = Join-Path $a.Path 'app\build\outputs\apk\debug\app-debug.apk'
if (-not (Test-Path $apk)) {
    Stop-WithHint "Die APK liegt nicht am erwarteten Ort: $apk" @('Task "Build-Ordner aufräumen" und erneut bauen.')
}

$targetDir = Join-Path $LadBuilds $a.Id
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item $apk (Join-Path $targetDir "$($a.Id)-debug-$stamp.apk") -Force
Copy-Item $apk (Join-Path $targetDir "$($a.Id)-debug-latest.apk")  -Force
Write-Ok "APK gesichert: builds\$($a.Id)\$($a.Id)-debug-$stamp.apk"

# --- Aufs Handy schieben ----------------------------------------------------
Write-Step 'Aufs Handy schieben'

# Immer derselbe Dateiname: so überschreibt jeder Build den vorherigen und im
# Downloads-Ordner sammelt sich kein Müll an.
$remote = "/sdcard/Download/$($a.Id)-debug.apk"
& $LadAdb -s $serial push $apk $remote 2>&1 | Select-Object -Last 1 | ForEach-Object { Write-Info $_ }

if ($LASTEXITCODE -ne 0) {
    Stop-WithHint 'Die APK konnte nicht aufs Handy geschoben werden.' @('USB-Kabel prüfen.')
}
Write-Ok "Liegt auf dem Handy: Downloads/$($a.Id)-debug.apk"

# Den Dateimanager öffnen, damit der Weg dorthin kurz ist. Klappt nicht auf jedem
# Gerät — deshalb nur ein Versuch, kein Abbruch bei Misserfolg.
& $LadAdb -s $serial shell am start -a android.intent.action.VIEW_DOWNLOADS 2>&1 | Out-Null

Write-Host ''
Write-Host '  Jetzt am Handy:' -ForegroundColor White
Write-Host "    1. Dateimanager -> Downloads -> $($a.Id)-debug.apk antippen" -ForegroundColor Gray
Write-Host '    2. "Installieren" bestätigen (beim ersten Mal fragt MIUI nach der' -ForegroundColor Gray
Write-Host '       Erlaubnis, aus dieser Quelle zu installieren — einmalig zulassen)' -ForegroundColor Gray
Write-Host ''
Write-Host '  Warum von Hand? MIUI blockiert jede Installation über ADB. Details:' -ForegroundColor DarkGray
Write-Host '  README.md, Abschnitt "Wenn etwas klemmt".' -ForegroundColor DarkGray
Write-Host ''
