# Zeigt die Live-Logs der App vom Gerät — gefiltert auf genau diese App,
# damit nicht das gesamte Systemrauschen durchläuft.
#
# Beenden mit Strg+C.

param([Parameter(Mandatory)][string]$App)

. "$PSScriptRoot\_env.ps1"
. "$PSScriptRoot\discover-apps.ps1"

$a      = Get-AppOrFail -Id $App
$serial = Get-ConnectedDevice

$processId = (& $LadAdb -s $serial shell pidof -s $a.ApplicationId 2>$null | Out-String).Trim()

Write-Step "$($a.Name): Logs (Strg+C beendet)"

if (-not $processId) {
    Write-Warn2 "$($a.Name) läuft gerade nicht auf dem Gerät."
    Write-Info  'Es werden stattdessen alle Warnungen und Fehler des Systems gezeigt.'
    Write-Info  'Starte die App auf dem Gerät, dann erscheinen ihre Meldungen hier.'
    & $LadAdb -s $serial logcat '*:W'
} else {
    Write-Info "Prozess-ID: $processId"
    & $LadAdb -s $serial logcat --pid=$processId
}
