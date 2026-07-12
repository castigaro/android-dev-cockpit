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

foreach ($repo in $repos) {
    $name      = Split-Path $repo -Leaf
    $claudeMd  = Join-Path $repo 'CLAUDE.md'
    $excludeFile = Join-Path $repo '.git\info\exclude'

    # Relativer Pfad von dort zu unserer AGENTS.md — die Repos sind Geschwister.
    $ladName = Split-Path $LadRoot -Leaf

    if (Test-Path $claudeMd) {
        Write-Info "$name : CLAUDE.md ist schon da, bleibt unangetastet."
    } else {
        $text = @"
# $name

## Wichtig für KI-Sitzungen

Die lokale Entwicklungsumgebung — Toolchain, Build-Skripte, der Debug-Loop aufs
Handy und die **verbindlichen Ablage-Regeln** — liegt in einem eigenen Repository
*neben* diesem hier: ``../$ladName/``.

@../$ladName/AGENTS.md

Sollte der Verweis oben nicht aufgelöst werden, lies ``../$ladName/AGENTS.md``
bitte direkt. Die Kurzfassung:

- **Dieses Repository bleibt frei von Werkzeug- und Build-Kram.** Keine Skripte,
  keine Toolchain, keine IDE-Konfiguration hier ablegen. Build-Ergebnisse und
  Planungen gehören nach ``../$ladName/``.
- **Lokal bauen und testen:** Den VS-Code-Workspace
  ``../$ladName/app-development.code-workspace`` öffnen und im Explorer unter
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

# Lokaler Wegweiser auf ../$ladName/AGENTS.md, angelegt von install.cmd.
# Bewusst hier und nicht in der .gitignore: so bleibt das Repository unverändert.
CLAUDE.md
"@
            Write-Ok "$name : in .git/info/exclude eingetragen — git status bleibt sauber."
        } else {
            Write-Info "$name : ist bereits lokal ignoriert."
        }
    }
}
