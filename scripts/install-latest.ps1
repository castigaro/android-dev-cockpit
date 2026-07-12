# Installiert den zuletzt gebauten Debug-Build erneut auf dem Gerät und startet
# ihn — ohne neu zu bauen. Nützlich, wenn das Gerät gewechselt oder die App
# dort deinstalliert wurde.

param([Parameter(Mandatory)][string]$App)

. "$PSScriptRoot\_env.ps1"
. "$PSScriptRoot\discover-apps.ps1"

$a      = Get-AppOrFail -Id $App
$serial = Get-ConnectedDevice

$apk = Join-Path $LadBuilds "$($a.Id)\$($a.Id)-debug-latest.apk"
if (-not (Test-Path $apk)) {
    Stop-WithHint "Es gibt noch keinen lokalen Build von $($a.Name)." @(
        "Erst den Task `"$($a.Name): Bauen und auf Gerät starten`" ausführen."
    )
}

$age = (Get-Item $apk).LastWriteTime
Write-Step "$($a.Name): letzten Build erneut installieren"
Write-Info "APK:    $apk"
Write-Info "Stand:  $age"
Write-Info "Gerät: $serial"

$out = & $LadAdb -s $serial install -r $apk 2>&1
$text = ($out | Out-String)

if ($text -match 'INSTALL_FAILED_USER_RESTRICTED') {
    Stop-WithHint 'Das Handy verweigert die Installation über USB.' @(
        'Typisch für Xiaomi/Redmi/POCO (MIUI, HyperOS): eigene Sperre zusätzlich zum USB-Debugging.',
        'Entwickleroptionen -> "Über USB installieren" und',
        '"USB-Debugging (Sicherheitseinstellungen)" einschalten, Kabel neu einstecken.'
    )
}
if ($text -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') {
    Stop-WithHint "Auf dem Gerät liegt eine anders signierte Version von $($a.Name)." @(
        "Task `"$($a.Name): App vom Gerät entfernen`" ausführen, danach erneut installieren.",
        'Achtung: dabei gehen die Daten der App auf diesem Gerät verloren.'
    )
}
if ($LASTEXITCODE -ne 0 -or $text -match 'Failure') {
    Write-Host $text
    Stop-WithHint 'Die Installation ist fehlgeschlagen.' @('Meldung siehe oben.')
}

Write-Ok 'Installiert.'

& $LadAdb -s $serial shell monkey -p $a.ApplicationId -c android.intent.category.LAUNCHER 1 | Out-Null
Write-Ok "$($a.Name) läuft jetzt auf dem Gerät."
