# Legt in jedem gefundenen App-Repository eine CLAUDE.md ab, die auf die
# AGENTS.md dieses Repos verweist — und trägt sie in die LOKALE Ignorier-Liste
# des jeweiligen Repos ein (.git/info/exclude).
#
# WARUM SO
# Claude Code lädt Kontextdateien aus dem Arbeitsverzeichnis, also aus dem
# App-Repo. Die Regeln stehen aber hier drüben in der AGENTS.md. Ohne Wegweiser
# findet eine KI-Sitzung sie nicht und fängt an, Werkzeug-Kram ins App-Repo zu
# legen oder längst geklärte Sackgassen neu zu erforschen.
#
# Der Eintrag geht bewusst in .git/info/exclude und NICHT in die .gitignore:
# .git/info/exclude wird nicht versioniert. Das App-Repo bleibt dadurch bitgenau
# unverändert — kein Commit, kein Diff, nichts auf GitHub. Auf einem neuen Rechner
# legt install.cmd den Wegweiser einfach wieder an.
#
# Eine bereits vorhandene CLAUDE.md wird NICHT überschrieben.

. "$PSScriptRoot\_env.ps1"
. "$PSScriptRoot\discover-apps.ps1"

Write-Step 'Wegweiser für KI-Sitzungen in die App-Repos legen'

$repos = Get-AndroidApps |
         Where-Object { $_.RepoRoot } |
         Select-Object -ExpandProperty RepoRoot -Unique

if (-not $repos) {
    Write-Info 'Keine App-Repositories gefunden — nichts zu tun.'
    return
}

# Relativer Pfad zwischen zwei Ordnern, mit Vorwärts-Schrägstrichen (Markdown).
# Über Uri.MakeRelativeUri statt Path.GetRelativePath — Letzteres fehlt in
# Windows PowerShell 5.1 (.NET Framework).
function Get-RelativeDir {
    param([string]$From, [string]$To)
    $fromUri = [Uri]($From.TrimEnd('\') + '\')
    $toUri   = [Uri]($To.TrimEnd('\') + '\')
    $rel = [Uri]::UnescapeDataString($fromUri.MakeRelativeUri($toUri).ToString())
    return $rel.TrimEnd('/')
}

foreach ($repo in $repos) {
    $name      = Split-Path $repo -Leaf
    $claudeMd  = Join-Path $repo 'CLAUDE.md'
    $excludeFile = Join-Path $repo '.git\info\exclude'

    # Relativer Pfad von dort zu unserer AGENTS.md. App-Repos können direkte
    # Geschwister sein (../<cockpit>) oder tiefer liegen, z. B. in einem
    # Sammelordner (../../<cockpit>) — deshalb wird er berechnet.
    $ladName = Split-Path $LadRoot -Leaf
    $ladRel  = Get-RelativeDir -From $repo -To $LadRoot

    if (Test-Path $claudeMd) {
        Write-Info "$name : CLAUDE.md ist schon da, bleibt unangetastet."
    } else {
        $text = @"
# $name

## Wichtig für KI-Sitzungen

Die lokale Entwicklungsumgebung — Toolchain, Build-Skripte, der Debug-Loop aufs
Handy und die **verbindlichen Ablage-Regeln** — liegt in einem eigenen Repository
neben diesem hier: ``$ladRel/``.

@$ladRel/AGENTS.md

Sollte der Verweis oben nicht aufgelöst werden, lies ``$ladRel/AGENTS.md``
bitte direkt. Die Kurzfassung:

- **Dieses Repository bleibt frei von Werkzeug- und Build-Kram.** Keine Skripte,
  keine Toolchain, keine IDE-Konfiguration hier ablegen. Build-Ergebnisse und
  Planungen gehören nach ``$ladRel/``.
- **Lokal bauen und testen:** Den VS-Code-Workspace
  ``$ladRel/app-development.code-workspace`` öffnen und im Explorer unter
  **NPM SCRIPTS** den Play-Button der App klicken. Nicht von Hand mit Gradle
  hantieren.
- **Den Release-/CI-Weg dieses Repos nicht anfassen.** Lokale Debug-Builds
  laufen vollständig an ihm vorbei.

Diese Datei wird von ``$ladName/install.cmd`` angelegt und ist nur lokal
sichtbar (Eintrag in ``.git/info/exclude``) — sie verändert das Repository nicht.
"@
        [System.IO.File]::WriteAllText($claudeMd, $text, [System.Text.UTF8Encoding]::new($false))
        Write-Ok "$name : CLAUDE.md angelegt."
    }

    # Lokal ignorieren, damit das Repo sauber bleibt.
    if (Test-Path (Join-Path $repo '.git')) {
        $current = if (Test-Path $excludeFile) { Get-Content $excludeFile -Raw } else { '' }
        if ($current -notmatch '(?m)^CLAUDE\.md\s*$') {
            New-Item -ItemType Directory -Force -Path (Split-Path $excludeFile -Parent) | Out-Null
            Add-Content -Path $excludeFile -Value @"

# Lokaler Wegweiser auf $ladRel/AGENTS.md, angelegt von install.cmd.
# Bewusst hier und nicht in der .gitignore: so bleibt das Repository unverändert.
CLAUDE.md
"@
            Write-Ok "$name : in .git/info/exclude eingetragen — git status bleibt sauber."
        } else {
            Write-Info "$name : ist bereits lokal ignoriert."
        }
    }
}
