# Baut den Debug-Build einer App, installiert ihn per USB auf dem Gerät,
# startet ihn und sichert die APK nach builds\<app>\.
#
# Wird von den VS-Code-Tasks aufgerufen — von Hand aufrufen muss man das nicht.

param(
    [Parameter(Mandatory)][string]$App,
    [switch]$Log   # danach direkt Logcat anhängen
)

. "$PSScriptRoot\_env.ps1"
. "$PSScriptRoot\discover-apps.ps1"

$a      = Get-AppOrFail -Id $App
$serial = Get-ConnectedDevice

Write-Step "$($a.Name): bauen und auf dem Gerät starten"
Write-Info "Projekt: $($a.Path)"
Write-Info "Gerät:  $serial"

# --- Bauen und installieren -------------------------------------------------
Write-Step 'Gradle: installDebug'
Write-Info 'Beim ersten Mal dauert das einige Minuten (Gradle und Abhängigkeiten werden geladen).'

$gradlew = Join-Path $a.Path 'gradlew.bat'

# Ohne Zuweisung landet die Ausgabe auf der Konsole — der Nutzer soll sehen, was
# Gradle tut. Tee-Object hebt sie zusätzlich für die Fehlerauswertung auf.
& $gradlew -p $a.Path 'installDebug' 2>&1 | Tee-Object -Variable gradleLines
$gradleOk = $LASTEXITCODE -eq 0

if (-not $gradleOk) {
    $text = ($gradleLines | Out-String)

    if ($text -match 'INSTALL_FAILED_USER_RESTRICTED') {
        Stop-WithHint 'Das Handy verweigert die Installation über USB.' @(
            'Typisch für Xiaomi/Redmi/POCO (MIUI, HyperOS): Dort gibt es zusätzlich zum',
            'USB-Debugging eine eigene Sperre für das Installieren über USB.',
            '',
            'Einstellungen -> Weitere Einstellungen -> Entwickleroptionen, und dort:',
            '  * "Über USB installieren" einschalten',
            '  * "USB-Debugging (Sicherheitseinstellungen)" einschalten',
            '',
            'MIUI verlangt für diese Schalter eine Anmeldung mit einem Mi-Konto und eine',
            'Internetverbindung des Handys. Nach dem Umschalten das USB-Kabel einmal neu',
            'einstecken und den Task erneut starten.'
        )
    }
    if ($text -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') {
        Stop-WithHint "Auf dem Gerät liegt bereits eine anders signierte Version von $($a.Name)." @(
            'Typisch die veröffentlichte Version (Store oder Download-Seite): Sie ist mit dem',
            'Release-Schlüssel signiert, der lokale Debug-Build mit einem anderen.',
            'Android lässt ein Update zwischen unterschiedlichen Signaturen nicht zu.',
            "Lösung: Task `"$($a.Name): App vom Gerät entfernen`" ausführen, danach erneut bauen.",
            'Achtung: dabei gehen die Daten der App auf diesem Gerät verloren.'
        )
    }
    if ($text -match 'INSTALL_FAILED_CONFLICTING_PROVIDER') {
        Stop-WithHint 'Eine andere App belegt bereits denselben FileProvider.' @(
            "Task `"$($a.Name): App vom Gerät entfernen`" ausführen, danach erneut bauen."
        )
    }
    if ($text -match 'No connected devices|device .*not found') {
        Stop-WithHint 'Die Verbindung zum Gerät ist während des Builds abgerissen.' @(
            'USB-Kabel prüfen und den Task erneut starten.'
        )
    }

    Stop-WithHint 'Der Gradle-Build ist fehlgeschlagen.' @(
        'Die Fehlermeldung steht oben im Terminal.',
        'Bleibt es unklar: Task "Aufräumen (Clean)" ausführen und erneut bauen.'
    )
}

Write-Ok 'Build erfolgreich und auf dem Gerät installiert.'

# --- APK sichern ------------------------------------------------------------
$apk = Join-Path $a.Path 'app\build\outputs\apk\debug\app-debug.apk'
if (Test-Path $apk) {
    $targetDir = Join-Path $LadBuilds $a.Id
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item $apk (Join-Path $targetDir "$($a.Id)-debug-$stamp.apk") -Force
    Copy-Item $apk (Join-Path $targetDir "$($a.Id)-debug-latest.apk")  -Force

    Write-Ok "APK gesichert: builds\$($a.Id)\$($a.Id)-debug-$stamp.apk"
} else {
    Write-Warn2 "APK nicht am erwarteten Ort gefunden: $apk"
}

# --- Starten ----------------------------------------------------------------
Write-Step "$($a.Name) starten"
# monkey schwatzt seine Argumente auf stderr — das interessiert niemanden.
& $LadAdb -s $serial shell monkey -p $a.ApplicationId -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Ok "$($a.Name) läuft jetzt auf dem Gerät."
} else {
    Write-Warn2 'Die App konnte nicht automatisch gestartet werden — sie ist aber installiert.'
    Write-Info  'Einfach auf dem Gerät antippen.'
}

if ($Log) { & "$PSScriptRoot\logcat.ps1" -App $App }
