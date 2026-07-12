# Entfernt eine App vollständig vom Gerät.
#
# Nötig, wenn dort noch die von der Website installierte Release-Version liegt:
# sie ist anders signiert als der lokale Debug-Build, und Android lässt ein
# Update zwischen unterschiedlichen Signaturen nicht zu.
#
# ACHTUNG: Die Daten der App auf diesem Gerät gehen dabei verloren.

param([Parameter(Mandatory)][string]$App)

. "$PSScriptRoot\_env.ps1"
. "$PSScriptRoot\discover-apps.ps1"

$a      = Get-AppOrFail -Id $App
$serial = Get-ConnectedDevice

Write-Step "$($a.Name) vom Gerät entfernen"
Write-Warn2 "Die Daten von $($a.Name) auf diesem Gerät gehen dabei verloren."
Write-Info  "Paket: $($a.ApplicationId)"
Write-Info  "Gerät: $serial"

$answer = Read-Host "`nWirklich entfernen? [j/N]"
if ($answer -notmatch '^[jJyY]') {
    Write-Info 'Abgebrochen — es wurde nichts verändert.'
    exit 0
}

$out = & $LadAdb -s $serial uninstall $a.ApplicationId 2>&1 | Out-String
if ($out -match 'Success') {
    Write-Ok "$($a.Name) wurde entfernt. Jetzt lässt sich der Debug-Build installieren."
} elseif ($out -match 'DELETE_FAILED_INTERNAL_ERROR|not installed') {
    Write-Info "$($a.Name) war gar nicht installiert."
} else {
    Write-Host $out
    Stop-WithHint 'Das Entfernen ist fehlgeschlagen.' @('Meldung siehe oben.')
}
