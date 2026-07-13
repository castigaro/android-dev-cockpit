# Führt die Unit-Tests einer App aus (JVM-Tests, kein Gerät nötig).
# Läuft über den Gradle-Wrapper der App mit der portablen Toolchain.

param([Parameter(Mandatory)][string]$App)

. "$PSScriptRoot\_env.ps1"
. "$PSScriptRoot\discover-apps.ps1"

Test-Toolchain
$a = Get-AppOrFail -Id $App

Write-Step "$($a.Name): Unit-Tests ausführen"
Write-Info 'Beim ersten Mal dauert das länger (Test-Abhängigkeiten werden geladen).'

$gradlew = Join-Path $a.Path 'gradlew.bat'
& $gradlew -p $a.Path 'testDebugUnitTest'

if ($LASTEXITCODE -eq 0) {
    Write-Ok 'Alle Unit-Tests bestanden.'
} else {
    Stop-WithHint 'Mindestens ein Unit-Test ist fehlgeschlagen.' @(
        'Die fehlgeschlagenen Tests stehen oben im Terminal.',
        'Details (HTML-Report): app/build/reports/tests/testDebugUnitTest/index.html im App-Ordner'
    )
}
