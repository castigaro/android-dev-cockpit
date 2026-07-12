# Räumt das Build-Verzeichnis einer App auf. Hilft, wenn Gradle nach größeren
# Änderungen inkonsistente Zwischenstände meldet.

param([Parameter(Mandatory)][string]$App)

. "$PSScriptRoot\_env.ps1"
. "$PSScriptRoot\discover-apps.ps1"

Test-Toolchain
$a = Get-AppOrFail -Id $App

Write-Step "$($a.Name): aufräumen"

$gradlew = Join-Path $a.Path 'gradlew.bat'
& $gradlew -p $a.Path 'clean'

if ($LASTEXITCODE -eq 0) {
    Write-Ok 'Build-Verzeichnis aufgeräumt. Der nächste Build baut alles neu.'
} else {
    Stop-WithHint 'gradlew clean ist fehlgeschlagen.' @('Meldung siehe oben.')
}
