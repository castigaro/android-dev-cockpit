# Gemeinsamer Unterbau. Wird von allen anderen Skripten per Dot-Sourcing geladen:
#   . "$PSScriptRoot\_env.ps1"
#
# Setzt die Umgebungsvariablen der portablen Toolchain NUR für die aktuelle
# Shell. Es wird nichts dauerhaft am System verändert.

$ErrorActionPreference = 'Stop'

$LadRoot      = Split-Path -Parent $PSScriptRoot
$LadToolchain = Join-Path $LadRoot 'toolchain'
$LadBuilds    = Join-Path $LadRoot 'builds'

# --- .env laden ------------------------------------------------------------
$LadSettings = @{
    PROJECTS_ROOT        = '..'
    DISCOVERY_DEPTH      = '3'
    ANDROID_PLATFORM     = '34'
    ANDROID_BUILD_TOOLS  = '34.0.0'
    WORKSPACE_EXTRA_DIRS = ''
}

$envFile = Join-Path $LadRoot '.env'
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $parts = $trimmed -split '=', 2
        if ($parts.Count -ne 2) { continue }
        $key = $parts[0].Trim()
        $val = $parts[1].Trim()
        if ($key) { $LadSettings[$key] = $val }
    }
}

# PROJECTS_ROOT zu einem absoluten Pfad auflösen.
$LadProjectsRoot = $LadSettings['PROJECTS_ROOT']
if (-not [System.IO.Path]::IsPathRooted($LadProjectsRoot)) {
    $LadProjectsRoot = Join-Path $LadRoot $LadProjectsRoot
}
$LadProjectsRoot = [System.IO.Path]::GetFullPath($LadProjectsRoot)

# --- Toolchain-Variablen (nur für diese Shell) ----------------------------
$env:JAVA_HOME        = Join-Path $LadToolchain 'jdk-17'
$env:ANDROID_HOME     = Join-Path $LadToolchain 'android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:GRADLE_USER_HOME = Join-Path $LadToolchain 'gradle-home'

$env:PATH = @(
    (Join-Path $env:JAVA_HOME 'bin')
    (Join-Path $env:ANDROID_HOME 'platform-tools')
    (Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin')
    $env:PATH
) -join ';'

$LadAdb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'

# --- Ausgabe-Helfer --------------------------------------------------------
function Write-Step  { param([string]$Text) Write-Host "`n=== $Text" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Text) Write-Host "  OK   $Text" -ForegroundColor Green }
function Write-Info  { param([string]$Text) Write-Host "       $Text" -ForegroundColor Gray }
function Write-Warn2 { param([string]$Text) Write-Host "  !    $Text" -ForegroundColor Yellow }
function Write-Fail  { param([string]$Text) Write-Host "  X    $Text" -ForegroundColor Red }

# Bricht mit einer verständlichen Meldung ab, statt einen kryptischen
# Folgefehler zu produzieren.
function Stop-WithHint {
    param([string]$Problem, [string[]]$Hints)
    Write-Host ''
    Write-Fail $Problem
    foreach ($h in $Hints) { Write-Host "       -> $h" -ForegroundColor Yellow }
    Write-Host ''
    exit 1
}

function Test-Toolchain {
    if (-not (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
        Stop-WithHint 'Die Toolchain ist nicht eingerichtet (kein JDK gefunden).' @(
            'Task "Entwicklungsumgebung einrichten/reparieren" ausführen,',
            "oder install.cmd im Ordner $LadRoot doppelklicken."
        )
    }
    if (-not (Test-Path $LadAdb)) {
        Stop-WithHint 'Die Toolchain ist unvollständig (adb fehlt).' @(
            'Task "Entwicklungsumgebung einrichten/reparieren" ausführen.'
        )
    }
}

# Liefert die Seriennummer des einzigen verbundenen Geräts — oder bricht mit
# einer Anleitung ab.
function Get-ConnectedDevice {
    Test-Toolchain
    $lines = & $LadAdb devices 2>&1 | Select-Object -Skip 1
    $devices     = @()
    $unauthorized = @()
    foreach ($line in $lines) {
        if ($line -match '^(\S+)\s+device$')       { $devices += $Matches[1] }
        elseif ($line -match '^(\S+)\s+unauthorized$') { $unauthorized += $Matches[1] }
    }

    if ($unauthorized.Count -gt 0 -and $devices.Count -eq 0) {
        Stop-WithHint 'Das Gerät ist verbunden, hat den Rechner aber noch nicht autorisiert.' @(
            'Auf dem Handy erscheint ein Dialog "USB-Debugging zulassen?".',
            'Mit "Diesem Computer immer vertrauen" bestätigen.',
            'Erscheint kein Dialog: USB-Kabel neu einstecken.'
        )
    }
    if ($devices.Count -eq 0) {
        Stop-WithHint 'Kein Android-Gerät per USB gefunden.' @(
            'Gerät per USB anschließen.',
            'Entwickleroptionen freischalten: Einstellungen -> Über das Telefon -> 7x auf "Buildnummer" tippen.',
            'Dann: Entwickleroptionen -> USB-Debugging einschalten.',
            'Danach den Task "Gerät prüfen (USB)" nochmal ausführen.'
        )
    }
    if ($devices.Count -gt 1) {
        Write-Warn2 "Mehrere Geräte verbunden. Es wird das erste benutzt: $($devices[0])"
    }
    return $devices[0]
}
