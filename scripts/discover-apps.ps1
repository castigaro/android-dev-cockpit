# Findet die baubaren Android-Apps in den Repositories neben diesem Repo.
#
# Kriterium: ein Verzeichnis mit gradlew.bat. Das findet sowohl ein
# Single-App-Repo (<repo>/gradlew.bat) als auch ein Monorepo mit mehreren
# eigenstaendigen Gradle-Projekten (<repo>/apps/<app>/gradlew.bat).
#
# Direkt aufgerufen gibt das Skript die gefundenen Apps aus.

. "$PSScriptRoot\_env.ps1"

function Get-AndroidApps {
    $depth = [int]$LadSettings['DISCOVERY_DEPTH']

    if (-not (Test-Path $LadProjectsRoot)) {
        Write-Warn2 "PROJECTS_ROOT existiert nicht: $LadProjectsRoot"
        return @()
    }

    $wrappers = Get-ChildItem -Path $LadProjectsRoot -Filter 'gradlew.bat' `
                              -Recurse -Depth $depth -File -ErrorAction SilentlyContinue

    $apps = @()
    foreach ($w in $wrappers) {
        $projectDir = $w.Directory.FullName

        # Dieses Repo selbst und alles darin ignorieren (Toolchain, Builds).
        if ($projectDir.StartsWith($LadRoot, [StringComparison]::OrdinalIgnoreCase)) { continue }

        $appModule = Join-Path $projectDir 'app'
        $buildFile = Join-Path $appModule 'build.gradle.kts'
        if (-not (Test-Path $buildFile)) { continue }   # kein Standard-App-Modul

        # applicationId aus dem Build-File lesen — die brauchen wir zum
        # Starten, Deinstallieren und für die Logs.
        $applicationId = $null
        $content = Get-Content $buildFile -Raw
        if ($content -match 'applicationId\s*=\s*"([^"]+)"') { $applicationId = $Matches[1] }
        if (-not $applicationId) { continue }

        # Anzeigename bevorzugt aus settings.gradle.kts.
        $displayName = Split-Path $projectDir -Leaf
        $settingsFile = Join-Path $projectDir 'settings.gradle.kts'
        if (Test-Path $settingsFile) {
            $s = Get-Content $settingsFile -Raw
            if ($s -match 'rootProject\.name\s*=\s*"([^"]+)"') { $displayName = $Matches[1] }
        }

        # Repo-Wurzel = nächstes Elternverzeichnis mit .git
        $repoRoot = $projectDir
        while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot '.git'))) {
            $parent = Split-Path $repoRoot -Parent
            if ($parent -eq $repoRoot) { $repoRoot = $null; break }
            $repoRoot = $parent
        }

        $apps += [pscustomobject]@{
            Id            = (Split-Path $projectDir -Leaf)   # Ordnername, z. B. "meine-app"
            Name          = $displayName                     # rootProject.name, z. B. "MeineApp"
            Path          = $projectDir
            ApplicationId = $applicationId
            RepoRoot      = $repoRoot
        }
    }

    return @($apps | Sort-Object Name)
}

# Sucht eine App anhand ihrer Id (dem Ordnernamen). Bricht sonst ab.
function Get-AppOrFail {
    param([Parameter(Mandatory)][string]$Id)
    $app = Get-AndroidApps | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    if (-not $app) {
        $known = (Get-AndroidApps | ForEach-Object { $_.Id }) -join ', '
        Stop-WithHint "App '$Id' wurde nicht gefunden." @(
            "Gefunden wurden: $(if ($known) { $known } else { '(keine)' })",
            "Gesucht wurde unter: $LadProjectsRoot",
            'Liegt das App-Repository als Geschwister neben local-app-development?',
            'Danach den Task "Workspace aktualisieren" ausführen.'
        )
    }
    return $app
}

# Direktaufruf: Liste ausgeben.
if ($MyInvocation.InvocationName -ne '.') {
    Write-Step "App-Erkennung unterhalb von $LadProjectsRoot"
    $found = Get-AndroidApps
    if ($found.Count -eq 0) {
        Write-Warn2 'Keine baubaren Android-Apps gefunden.'
        Write-Info  'Erwartet wird ein Repository mit gradlew.bat und einem app/-Modul,'
        Write-Info  'z. B. ..\meine-app\ oder ..\mein-repo\apps\meine-app\'
    } else {
        foreach ($a in $found) {
            Write-Ok "$($a.Name)  [$($a.Id)]"
            Write-Info "$($a.ApplicationId)"
            Write-Info "$($a.Path)"
        }
    }
}
