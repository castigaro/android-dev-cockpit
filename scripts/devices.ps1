# Zeigt, welche Android-Geräte per USB erreichbar sind, und welche der
# bekannten Apps dort schon installiert sind. Erste Anlaufstelle, wenn ein
# Build "kein Gerät" meldet.

. "$PSScriptRoot\_env.ps1"
. "$PSScriptRoot\discover-apps.ps1"

Test-Toolchain

Write-Step 'Verbundene Geräte'

$lines = & $LadAdb devices -l 2>&1 | Select-Object -Skip 1 | Where-Object { $_.Trim() }

if (-not $lines) {
    Write-Fail 'Kein Gerät gefunden.'
    Write-Host ''
    Write-Host '  So richtest du ein Gerät ein:' -ForegroundColor Yellow
    Write-Host '    1. Einstellungen -> Über das Telefon -> 7x auf "Buildnummer" tippen.' -ForegroundColor Yellow
    Write-Host '    2. Einstellungen -> System -> Entwickleroptionen -> USB-Debugging einschalten.' -ForegroundColor Yellow
    Write-Host '    3. Gerät per USB anschließen.' -ForegroundColor Yellow
    Write-Host '    4. Auf dem Handy "USB-Debugging zulassen?" mit "Immer vertrauen" bestätigen.' -ForegroundColor Yellow
    Write-Host '    5. Diesen Task erneut ausführen.' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

$serials = @()
foreach ($line in $lines) {
    if ($line -match '^(\S+)\s+unauthorized') {
        Write-Fail "$($Matches[1]) — noch nicht autorisiert"
        Write-Info 'Auf dem Handy den Dialog "USB-Debugging zulassen?" bestätigen.'
    }
    elseif ($line -match '^(\S+)\s+offline') {
        Write-Warn2 "$($Matches[1]) — offline. USB-Kabel neu einstecken."
    }
    elseif ($line -match '^(\S+)\s+device') {
        $serial = $Matches[1]
        $serials += $serial
        $model = if ($line -match 'model:(\S+)') { $Matches[1] } else { 'unbekannt' }
        Write-Ok "$serial  ($model)"
    }
}

if ($serials.Count -eq 0) { exit 1 }

# --- Installierte Apps ------------------------------------------------------
$apps = Get-AndroidApps
if ($apps.Count -gt 0) {
    foreach ($serial in $serials) {
        Write-Step "Bekannte Apps auf $serial"
        foreach ($a in $apps) {
            $found = & $LadAdb -s $serial shell pm list packages $a.ApplicationId 2>$null
            if ($found) {
                $version = (& $LadAdb -s $serial shell dumpsys package $a.ApplicationId 2>$null |
                            Select-String 'versionName=' | Select-Object -First 1)
                Write-Ok "$($a.Name) ist installiert  $(($version -replace '.*versionName=', 'v'))"
            } else {
                Write-Info "$($a.Name) ist nicht installiert"
            }
        }
    }
    Write-Host ''
    Write-Info 'Hinweis: Liegt hier noch die Version von der Website (Release-Signatur), lässt'
    Write-Info 'Android den lokalen Debug-Build nicht darüber installieren. Dann zuerst den Task'
    Write-Info '"<App>: App vom Gerät entfernen" ausführen.'
}
