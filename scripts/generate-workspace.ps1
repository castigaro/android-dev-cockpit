# Erzeugt aus den gefundenen Apps zwei Dateien:
#
#   app-development.code-workspace  — Ordner und Tasks für VS Code
#   package.json                    — dieselben Aktionen als npm-Skripte
#
# WARUM BEIDES
# VS Code zeigt npm-Skripte in der Explorer-Ansicht "NPM SCRIPTS" mit einem
# echten Play-Button — als Bordmittel, ohne Extension. Genau die Bedienung, die
# gewünscht war, ohne fremden Code auf dem Rechner. Die npm-Skripte rufen
# dieselben PowerShell-Skripte auf wie die Tasks; Node ist reine Oberfläche,
# keine Logik. Ohne Node verliert man nichts Wesentliches: Strg+Shift+B startet
# weiterhin den Standard-Task, und "Terminal -> Task ausführen…" listet alles auf.
#
# Beide Dateien sind rechnerabhängig (absolute Pfade, gefundene Apps) und deshalb
# gitignoriert. Sie werden bei jedem Setup und über den Task "Workspace
# aktualisieren" neu erzeugt. Nicht von Hand bearbeiten — Änderungen gehören
# hierher, in den Generator.

. "$PSScriptRoot\_env.ps1"
. "$PSScriptRoot\discover-apps.ps1"

$workspaceFile = Join-Path $LadRoot 'app-development.code-workspace'
$packageFile   = Join-Path $LadRoot 'package.json'

# pwsh 7 bevorzugen, sonst die überall vorhandene Windows PowerShell.
$psExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $psExe) { $psExe = (Get-Command powershell -ErrorAction SilentlyContinue).Source }

Write-Step 'Workspace erzeugen'

$apps = Get-AndroidApps
if ($apps.Count -eq 0) {
    Write-Warn2 "Keine Apps gefunden unter $LadProjectsRoot"
    Write-Info  'Der Workspace wird trotzdem erzeugt — lege ein App-Repository daneben'
    Write-Info  'und führe danach den Task "Workspace aktualisieren" aus.'
} else {
    foreach ($a in $apps) { Write-Ok "$($a.Name)  [$($a.Id)]  $($a.Path)" }
}

# --- Ordner ----------------------------------------------------------------
$folders = @(
    [ordered]@{ path = $LadRoot; name = 'local-app-development' }
)
foreach ($repo in ($apps | Where-Object { $_.RepoRoot } | Select-Object -ExpandProperty RepoRoot -Unique)) {
    $folders += [ordered]@{ path = $repo; name = (Split-Path $repo -Leaf) }
}

# --- Tasks -----------------------------------------------------------------
function New-Task {
    param(
        [string]$Label,
        [string]$Script,
        [string[]]$ScriptArgs = @(),
        [switch]$IsDefaultBuild,
        [switch]$Interactive   # braucht Tastatureingabe -> Terminal fokussieren
    )
    $task = [ordered]@{
        label   = $Label
        type    = 'process'
        command = $psExe
        args    = @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', (Join-Path $PSScriptRoot $Script)
        ) + $ScriptArgs
        presentation = [ordered]@{
            reveal = 'always'
            panel  = 'dedicated'
            clear  = $true
            focus  = [bool]$Interactive
        }
        problemMatcher = @()
    }
    if ($IsDefaultBuild) { $task['group'] = [ordered]@{ kind = 'build'; isDefault = $true } }
    return $task
}

$tasks = @()
$first = $true
foreach ($a in $apps) {
    $tasks += New-Task -Label "$($a.Name): Bauen & auf Gerät starten" `
                       -Script 'build-and-run.ps1' -ScriptArgs @('-App', $a.Id) `
                       -IsDefaultBuild:$first
    $tasks += New-Task -Label "$($a.Name): Bauen & aufs Handy schieben (Xiaomi)" `
                       -Script 'build-and-push.ps1' -ScriptArgs @('-App', $a.Id)
    $tasks += New-Task -Label "$($a.Name): Letzten Build erneut installieren" `
                       -Script 'install-latest.ps1' -ScriptArgs @('-App', $a.Id)
    $tasks += New-Task -Label "$($a.Name): Logs anzeigen (Logcat)" `
                       -Script 'logcat.ps1' -ScriptArgs @('-App', $a.Id)
    $tasks += New-Task -Label "$($a.Name): App vom Gerät entfernen" `
                       -Script 'uninstall.ps1' -ScriptArgs @('-App', $a.Id) -Interactive
    $tasks += New-Task -Label "$($a.Name): Build-Ordner aufräumen" `
                       -Script 'clean.ps1' -ScriptArgs @('-App', $a.Id)
    $first = $false
}

$tasks += New-Task -Label 'Gerät prüfen (USB)'                     -Script 'devices.ps1'
$tasks += New-Task -Label 'Workspace aktualisieren'                -Script 'generate-workspace.ps1'
$tasks += New-Task -Label 'Entwicklungsumgebung einrichten/reparieren' -Script '..\install.ps1'

# --- Workspace schreiben ----------------------------------------------------
# Bewusst OHNE Extension-Empfehlung: Die Play-Buttons liefert die eingebaute
# NPM-SCRIPTS-Ansicht (siehe package.json weiter unten). Keine Extension nötig,
# kein fremder Code.
$workspace = [ordered]@{
    folders = $folders
    settings = [ordered]@{
        # Blendet die NPM-SCRIPTS-Ansicht im Explorer ein — dort sitzen die Play-Buttons.
        'npm.enableScriptExplorer' = $true
        'npm.packageManager'       = 'npm'
    }
    tasks = [ordered]@{
        version = '2.0.0'
        tasks   = $tasks
    }
}

$json = $workspace | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText($workspaceFile, $json, [System.Text.UTF8Encoding]::new($false))
Write-Ok "Workspace geschrieben: $workspaceFile"

# --- package.json schreiben -------------------------------------------------
# Jedes Skript hier wird in VS Code zu einer Zeile mit Play-Button.
# Die Namen sind bewusst kurz und shell-sicher — sie sind das, was du im
# Explorer siehst.
$npmScripts = [ordered]@{}

# npm führt seine Skripte auf Windows über cmd.exe aus — und cmd zerlegt einen
# Pfad wie "C:\Program Files\...\pwsh.exe" trotz Anführungszeichen am Leerzeichen.
# Deshalb hier NUR der Befehlsname (liegt im PATH) statt des vollen Pfads, und
# relative Skriptpfade (npm startet im Verzeichnis der package.json).
# Die VS-Code-Tasks oben dürfen den vollen Pfad behalten: type "process" umgeht
# die Shell und hat das Problem nicht.
$psCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }

function Add-NpmScript {
    param([string]$Name, [string]$RelPath, [string[]]$ScriptArgs = @())
    $npmScripts[$Name] = (@($psCmd, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $RelPath) + $ScriptArgs) -join ' '
}

foreach ($a in $apps) {
    $id = $a.Id
    # ACHTUNG: Die geschweiften Klammern sind Pflicht. In "$id:push" wäre der
    # Doppelpunkt für PowerShell ein Scope-Trenner (wie in $env:PATH) — der
    # Schlüssel käme leer heraus.
    Add-NpmScript -Name $id               -RelPath 'scripts/build-and-run.ps1'  -ScriptArgs @('-App', $id)
    Add-NpmScript -Name "${id}:push"      -RelPath 'scripts/build-and-push.ps1' -ScriptArgs @('-App', $id)
    Add-NpmScript -Name "${id}:reinstall" -RelPath 'scripts/install-latest.ps1' -ScriptArgs @('-App', $id)
    Add-NpmScript -Name "${id}:logs"      -RelPath 'scripts/logcat.ps1'         -ScriptArgs @('-App', $id)
    Add-NpmScript -Name "${id}:clean"     -RelPath 'scripts/clean.ps1'          -ScriptArgs @('-App', $id)
    Add-NpmScript -Name "${id}:uninstall" -RelPath 'scripts/uninstall.ps1'      -ScriptArgs @('-App', $id)
}
Add-NpmScript -Name 'device'    -RelPath 'scripts/devices.ps1'
Add-NpmScript -Name 'workspace' -RelPath 'scripts/generate-workspace.ps1'
Add-NpmScript -Name 'setup'     -RelPath 'install.ps1'

$package = [ordered]@{
    name        = 'local-app-development'
    version     = '1.0.0'
    private     = $true
    description = 'Play-Buttons fuer die lokale Android-Entwicklungsumgebung. Generiert - nicht von Hand bearbeiten.'
    scripts     = $npmScripts
}

$pkgJson = $package | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($packageFile, $pkgJson, [System.Text.UTF8Encoding]::new($false))
Write-Ok "package.json geschrieben: $($npmScripts.Count) Play-Buttons"

Write-Info "Shell für die Tasks: $psExe"
Write-Host ''
Write-Info 'In VS Code: Explorer öffnen, unten die Ansicht "NPM SCRIPTS" aufklappen.'
Write-Info 'Jedes Skript hat dort einen Play-Button. Strg+Shift+B startet den Standard-Build.'
