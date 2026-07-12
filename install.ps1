# =============================================================================
#  Richtet die komplette lokale Android-Entwicklungsumgebung ein.
#
#  Aufruf: install.cmd doppelklicken. Von Hand ist nichts zu tun.
#
#  Das Skript ist idempotent: Was schon da ist, wird erkannt und nicht erneut
#  heruntergeladen. Ein zweiter Aufruf ist also unschädlich und eignet sich zum
#  Reparieren.
#
#  Alles landet im Unterordner toolchain\ dieses Repos. Am System wird nichts
#  verändert — keine Installer, keine dauerhaften Umgebungsvariablen. Wer die
#  Umgebung loswerden will, löscht diesen Ordner.
# =============================================================================

param([switch]$Force)   # -Force lädt auch Vorhandenes neu

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # macht Invoke-WebRequest um ein Vielfaches schneller

. "$PSScriptRoot\scripts\_env.ps1"

$JdkUrl = 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse'
$CmdlineToolsUrl = 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip'

$platform   = $LadSettings['ANDROID_PLATFORM']
$buildTools = $LadSettings['ANDROID_BUILD_TOOLS']

Write-Host ''
Write-Host '  Lokale Android-Entwicklungsumgebung' -ForegroundColor White
Write-Host "  Ziel: $LadToolchain" -ForegroundColor Gray

# --- Hilfsfunktion: ZIP laden und entpacken ---------------------------------
function Expand-RemoteZip {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Destination,  # Zielordner (wird zum Inhalt der ZIP-Wurzel)
        [string]$StripRoot                            # Name des Wurzelordners in der ZIP, der wegfällt
    )
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("lad-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $zip = Join-Path $tmp 'download.zip'
        Write-Info 'lädt…'
        Invoke-WebRequest -Uri $Url -OutFile $zip -UseBasicParsing

        Write-Info 'entpackt…'
        $extract = Join-Path $tmp 'x'
        Expand-Archive -Path $zip -DestinationPath $extract -Force

        # Die meisten ZIPs haben genau einen Wurzelordner (z. B. "jdk-17.0.13+11"
        # oder "cmdline-tools"). Dessen Inhalt wollen wir, nicht ihn selbst.
        $source = $extract
        $children = @(Get-ChildItem $extract)
        if ($children.Count -eq 1 -and $children[0].PSIsContainer) { $source = $children[0].FullName }
        if ($StripRoot) {
            $candidate = Join-Path $extract $StripRoot
            if (Test-Path $candidate) { $source = $candidate }
        }

        if (Test-Path $Destination) { Remove-Item $Destination -Recurse -Force }
        New-Item -ItemType Directory -Force -Path (Split-Path $Destination -Parent) | Out-Null
        Move-Item $source $Destination
    }
    finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- 1. .env ----------------------------------------------------------------
Write-Step '1/7  Lokale Einstellungen (.env)'
$envFile = Join-Path $LadRoot '.env'
if (Test-Path $envFile) {
    Write-Ok '.env ist vorhanden.'
} else {
    Copy-Item (Join-Path $LadRoot '.env.example') $envFile
    Write-Ok '.env aus .env.example angelegt.'
    Write-Info 'Für den normalen Debug-Loop musst du dort nichts ändern.'
}

# --- 2. JDK 17 --------------------------------------------------------------
Write-Step '2/7  Java (Temurin JDK 17)'
$javaExe = Join-Path $env:JAVA_HOME 'bin\java.exe'
if ((Test-Path $javaExe) -and -not $Force) {
    Write-Ok 'JDK 17 ist vorhanden.'
} else {
    Write-Info 'Wird geladen (~190 MB). Version 17 ist zwingend — das Android-Gradle-Plugin verlangt sie.'
    Expand-RemoteZip -Url $JdkUrl -Destination $env:JAVA_HOME
    Write-Ok "JDK installiert: $env:JAVA_HOME"
}

$javaVersion = (& $javaExe -version 2>&1 | Select-Object -First 1)
Write-Info $javaVersion

# --- 3. Android SDK: cmdline-tools ------------------------------------------
Write-Step '3/7  Android SDK — Command-line Tools'
$sdkmanager = Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin\sdkmanager.bat'
if ((Test-Path $sdkmanager) -and -not $Force) {
    Write-Ok 'Command-line Tools sind vorhanden.'
} else {
    Write-Info 'Werden geladen (~150 MB).'
    # Die Verschachtelung cmdline-tools\latest\ ist Pflicht — ohne sie
    # verweigert der sdkmanager den Dienst.
    Expand-RemoteZip -Url $CmdlineToolsUrl `
                     -Destination (Join-Path $env:ANDROID_HOME 'cmdline-tools\latest') `
                     -StripRoot 'cmdline-tools'
    Write-Ok 'Command-line Tools installiert.'
}

# --- 4. SDK-Pakete + Lizenzen -----------------------------------------------
Write-Step '4/7  Android SDK — Pakete und Lizenzen'

$needed = @{
    "platform-tools"            = (Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe')
    "platforms;android-$platform" = (Join-Path $env:ANDROID_HOME "platforms\android-$platform")
    "build-tools;$buildTools"   = (Join-Path $env:ANDROID_HOME "build-tools\$buildTools")
}
$missing = @($needed.GetEnumerator() | Where-Object { $Force -or -not (Test-Path $_.Value) } | ForEach-Object { $_.Key })

if ($missing.Count -eq 0) {
    Write-Ok "Alle Pakete vorhanden (platform-tools, android-$platform, build-tools $buildTools)."
} else {
    Write-Info "Fehlt noch: $($missing -join ', ')"
    Write-Info 'Lizenzen werden automatisch akzeptiert.'

    # sdkmanager fragt jede Lizenz einzeln ab — wir beantworten alle mit "y".
    $answers = ("y`n" * 50)
    $answers | & $sdkmanager --sdk_root="$env:ANDROID_HOME" --licenses | Out-Null

    Write-Info 'Pakete werden installiert (~500 MB)…'
    & $sdkmanager --sdk_root="$env:ANDROID_HOME" @missing
    if ($LASTEXITCODE -ne 0) {
        Stop-WithHint 'Die SDK-Pakete konnten nicht installiert werden.' @(
            'Meldung siehe oben — meist ist es die Internetverbindung.',
            'install.cmd einfach erneut ausführen; bereits Geladenes bleibt erhalten.'
        )
    }
    Write-Ok 'Pakete installiert.'
}

$adbVersion = (& $LadAdb version 2>&1 | Select-Object -First 1)
Write-Info $adbVersion

# --- 5. Gradle-Home ---------------------------------------------------------
Write-Step '5/7  Gradle-Cache'
New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME | Out-Null
Write-Ok "GRADLE_USER_HOME liegt im Repo: $env:GRADLE_USER_HOME"
Write-Info 'So landet auch der mehrere GB große Gradle-Cache hier und nicht im Benutzerprofil.'

# --- 6. Apps finden und Workspace erzeugen ----------------------------------
Write-Step '6/7  Apps suchen und VS-Code-Workspace erzeugen'
& "$PSScriptRoot\scripts\generate-workspace.ps1"

# --- 7. Wegweiser in die App-Repos ------------------------------------------
Write-Step '7/7  Wegweiser für KI-Sitzungen'
& "$PSScriptRoot\scripts\write-repo-pointers.ps1"

# --- Abschluss --------------------------------------------------------------
Write-Host ''
Write-Host '  Fertig. Die Entwicklungsumgebung steht.' -ForegroundColor Green
Write-Host ''
Write-Host '  So geht es weiter:' -ForegroundColor White
Write-Host "    1. In VS Code öffnen:  $LadRoot\app-development.code-workspace" -ForegroundColor Gray
Write-Host '    2. Handy per USB anschließen, USB-Debugging einschalten.' -ForegroundColor Gray
Write-Host '    3. Im Explorer die Ansicht "NPM SCRIPTS" einblenden:' -ForegroundColor Gray
Write-Host '       Titelleiste "EXPLORER" -> Menue "..." -> Haken bei "NPM Scripts".' -ForegroundColor Gray
Write-Host '       (VS Code blendet sie bei Multi-Root-Workspaces nicht von selbst ein.)' -ForegroundColor Gray
Write-Host '    4. Beim Namen deiner App auf den Play-Button klicken. (Oder: Strg+Shift+B)' -ForegroundColor Gray
Write-Host ''
Write-Host '  Details und Fehlerbehebung: README.md' -ForegroundColor Gray
Write-Host ''
