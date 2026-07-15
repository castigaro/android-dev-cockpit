# AGENTS.md — Orientierung und Regeln für KI-Assistenten

Diese Datei beschreibt, wie die Entwicklungsumgebung aufgebaut ist und welche
Regeln beim Arbeiten daran gelten. Lies sie, bevor du Dateien anlegst oder
verschiebst — die Ablage ist bewusst so gewählt und soll so bleiben.

## Das Gesamtbild

```
<projekte>\
├── android-dev-cockpit\   ← dieses Repo: die Werkzeuge. Generisch, appunabhängig.
├── <app-repo-1>\          ← ein App-Repo: der Code. Geschwister, NICHT verschachtelt.
└── <app-repo-2>\          ← beliebig viele weitere. Werden von selbst gefunden.
```

Der Ordnername dieses Repos ist frei wählbar; kein Skript hängt daran (alle
leiten ihn zur Laufzeit aus `$PSScriptRoot` ab).

Zwei getrennte Git-Repositories, nebeneinander. Ein App-Repo *innerhalb* von
`local-app-development` wäre ein Fehler (verschachtelte Repos → Submodule-Zwang).

## Wo was hingehört — verbindlich

| Was | Wohin | Warum |
| --- | --- | --- |
| Toolchain (JDK, Android SDK, Gradle-Cache) | `toolchain/` | Portabel, gitignoriert, durch Löschen entfernbar. Niemals ins System installieren. |
| Build-Skripte, Installationsskript | `scripts/`, `install.ps1` | Versioniert, laufen überall. |
| Fertige APKs, Build-Ergebnisse | `builds/` | Gitignoriert. |
| Planungen, Notizen, Mitschriften | `planning/<projekt>/` | **Gitignoriert.** Projektspezifisch und oft vertraulich — bleibt auf dem Rechner. |
| App-Quellcode | das jeweilige App-Repo | — |

**Dieses Repo ist generisch und öffentlich.** Es kennt keine bestimmte App. Es
gibt keine App-Liste, keine Namen, keine Pfade zu konkreten Projekten. Schreibe
nichts hinein, was nur für *ein* Projekt gilt — weder in die Dokumentation noch
als Beispiel in einen Skript-Kommentar. Projektwissen gehört ins jeweilige
App-Repo oder nach `planning/` (das ist gitignoriert und bleibt lokal).

**Das App-Repo bleibt frei von Werkzeug- und Build-Kram.** Keine Skripte, keine
Toolchain, keine `local.properties`, keine IDE-Konfiguration hineinschreiben.

Die einzige Datei, die die Umgebung dort ablegt, ist eine `CLAUDE.md` — der
Wegweiser auf diese Datei hier. Sie wird von `write-repo-pointers.ps1` (Schritt
7 von `install.cmd`) angelegt und im selben Zug in die **lokale** Ignorier-Liste
des App-Repos eingetragen (`.git/info/exclude`, **nicht** in die `.gitignore` —
die wäre ja versioniert). Das App-Repo bleibt dadurch bitgenau unverändert:
`git status` zeigt nichts, auf GitHub landet nichts, und auf einem neuen Rechner
legt `install.cmd` den Wegweiser einfach wieder an. Eine bereits vorhandene
`CLAUDE.md` wird nie überschrieben.

**Nichts dauerhaft am System verändern.** Kein `winget install`, kein `setx`,
keine Installer. Umgebungsvariablen werden pro Shell in `scripts/_env.ps1`
gesetzt.

**Secrets nur in die `.env`** (gitignoriert), niemals in versionierte Dateien.
Die `.env.example` dokumentiert die Schlüssel, enthält aber keine Werte.

## Die Umgebung

- Einstieg: `install.cmd` → `install.ps1`. **Idempotent** — jeder Schritt prüft
  erst, ob er nötig ist. Ein zweiter Aufruf repariert und lädt nichts neu.
- `scripts/_env.ps1` ist der gemeinsame Unterbau: lädt die `.env`, setzt
  `JAVA_HOME`, `ANDROID_HOME`, `GRADLE_USER_HOME` und den `PATH` — nur für die
  laufende Shell. Wird von allen Skripten per Dot-Sourcing eingebunden.
- `scripts/discover-apps.ps1` **findet die Apps selbst**: es sucht unterhalb von
  `PROJECTS_ROOT` nach Verzeichnissen mit `gradlew.bat` und einem `app/`-Modul und
  liest `applicationId` sowie `rootProject.name` heraus. Es gibt **keine Liste**
  von Apps, die gepflegt werden müsste — wenn du eine App hinzufügst, wird sie
  gefunden.
- `scripts/generate-workspace.ps1` erzeugt daraus **zwei** Dateien:
  `app-development.code-workspace` (Ordner + Tasks) und `package.json` (dieselben
  Aktionen als npm-Skripte). Beide sind rechnerabhängig und **gitignoriert** —
  nicht von Hand bearbeiten, sie werden überschrieben.

**Die Play-Buttons kommen aus der `package.json`, nicht aus einer Extension.**
VS Code zeigt npm-Skripte in der Explorer-Ansicht „NPM SCRIPTS" mit einem
▶-Button — Bordmittel. Eine Extension wäre fremder Code mit vollem Zugriff auf
den Rechner; das wurde bewusst verworfen. Node ist reine Oberfläche: Die Logik
liegt in den PowerShell-Skripten, und ohne Node funktioniert alles weiterhin über
`Strg+Shift+B` und „Terminal → Task ausführen…".

Zwei Fallen im Generator, beide bereits einmal zugeschnappt:

- **npm-Skripte brauchen den Befehlsnamen, nicht den vollen Pfad.** npm führt sie
  auf Windows über `cmd.exe` aus, und `cmd` zerlegt `"C:\Program Files\…\pwsh.exe"`
  trotz Anführungszeichen am Leerzeichen. Deshalb dort `pwsh` (aus dem PATH) und
  relative Skriptpfade. Die VS-Code-Tasks dürfen den vollen Pfad behalten —
  `type: "process"` umgeht die Shell.
- **`"${id}:push"` mit geschweiften Klammern.** In `"$id:push"` liest PowerShell
  den Doppelpunkt als Scope-Trenner (wie `$env:PATH`) und der Schlüssel wird leer.

Wenn du die Bedienung erweiterst: **neues Skript in `scripts/`, dann den
Generator anpassen.** Nicht die generierten Dateien editieren.

## Konventionen für die Skripte

- **PowerShell, UTF-8 mit BOM.** Das BOM ist Pflicht: ohne es liest Windows
  PowerShell 5.1 (auf einem frischen Rechner die einzige verfügbare Version) die
  Umlaute falsch.
- Fehler werden **im Klartext** gemeldet, mit konkreter Handlungsanweisung —
  dafür gibt es `Stop-WithHint` in `_env.ps1`. Ein kryptischer Gradle- oder
  adb-Fehler ist ein Bug, kein akzeptables Ergebnis.
- Ausgaben laufen über `Write-Step` / `Write-Ok` / `Write-Info` / `Write-Warn2` /
  `Write-Fail` aus `_env.ps1`.
- Der Benutzer soll **keine Parameter tippen müssen**. Skripte nehmen `-App
  <id>`, aber gesetzt wird der von den generierten Tasks.

## Was ein App-Repo mitbringen muss

Damit `discover-apps.ps1` eine App findet, reicht das Übliche eines
Android-Projekts:

- ein Verzeichnis mit **`gradlew.bat`** (Gradle-Wrapper),
- darin ein Modul **`app/`** mit `build.gradle.kts`,
- darin eine **`applicationId`** — sie wird zum Starten, Deinstallieren und
  Filtern der Logs gebraucht.

Der Anzeigename kommt aus `rootProject.name` in `settings.gradle.kts`, sonst aus
dem Ordnernamen. Das Schema passt für ein Single-App-Repo (`<repo>/gradlew.bat`)
genauso wie für ein Monorepo mit mehreren eigenständigen Gradle-Projekten
(`<repo>/apps/<app>/gradlew.bat`).

Die Toolchain bringt **JDK 17** und standardmäßig **SDK-Platform 34** mit. Braucht
eine App etwas anderes, wird das in der `.env` über `ANDROID_PLATFORM` und
`ANDROID_BUILD_TOOLS` gesetzt — **nicht** im Skript hartkodiert.

## Xiaomi/MIUI: nur die Erstinstallation ist gesperrt

Auf Xiaomi/Redmi/POCO (MIUI, HyperOS) weist MIUI jede **Neu**installation über ADB
mit `INSTALL_FAILED_USER_RESTRICTED` ab. Am Redmi Note 10 (MIUI V14, Android 13)
erschöpfend nachgemessen: `adb install`, `pm install` aus der Shell, `--user 0`,
`--install-reason POLICY`, `-i <installer>` zum Vortäuschen der Quelle, sowie die
session-basierte Installation — alle identisch abgewiesen. Bei der Session
gelingen `install-create` und `install-write`, erst `install-commit` wird
abgelehnt: MIUI greift ganz am Ende ein.

Es ist **keine Android-Restriction** (`dumpsys user` zeigt null gesetzte
Restrictions), sondern MIUIs gepatchter Paketmanager.

**Der Ausweg — und er ist gutartig:** MIUI blockiert nur ADB, nicht den Nutzer.
Ist die App **einmal** von Hand installiert, lässt MIUI jedes weitere `adb install
-r` (also `installDebug`) anstandslos durch. Dafür gibt es `build-and-push.ps1`
(npm-Skript `<app>:push`): bauen, APK in die Downloads des Handys schieben, der Nutzer tippt
einmal. **Danach läuft `build-and-run.ps1` vollautomatisch**, in ~8 s.

**Such hier nicht nach einer ADB-Lösung für die Erstinstallation — es gibt keine.**
Die Entwickleroptionen „USB-Debugging (Sicherheitseinstellungen)" und „Über USB
installieren" verlangen ein Mi-Konto *und* eine eingelegte SIM-Karte; der frühere
Ausweg „MIUI-Optimierung abschalten" existiert seit MIUI 13/14 nicht mehr. Beides
ist unnötig, der eine Fingertipp ersetzt es.

## Xiaomi/MIUI: Eingabe-Injection per ADB ist ebenfalls gesperrt

Ohne aktivierte „USB-Debugging (Sicherheitseinstellungen)" (siehe oben: Mi-Konto
+ SIM nötig) weist MIUI **jede** Eingabe-Injection ab: `adb shell input
tap/swipe/keyevent` scheitert mit `SecurityException … INJECT_EVENTS`, und auch
`am start` auf nicht-exportierte Activities wird verweigert. Ein Agent kann das
Gerät also **nicht selbst bedienen**.

**Erprobter Ausweg — beobachtender Test-Workflow:** Der Mensch bedient das
Gerät, der Agent schaut zu:

- Bildschirm ansehen: `adb exec-out screencap -p > shot.png` (bei Bedarf als
  Schleife alle paar Sekunden in einen Sitzungsordner) — es gibt kein scrcpy in
  der Toolchain, und das ist auch nicht nötig.
- Vom Nutzer selbst erstellte Screenshots liegen unter
  `/sdcard/DCIM/Screenshots/` und lassen sich per `adb pull` holen.
- Parallel gefiltertes Logcat mitlesen (`<app>:logs` bzw. `adb logcat`).
- Pinch-/Multitouch-Gesten lassen sich grundsätzlich nicht per `input`
  injizieren — Zoom-Gesten bleiben immer ein Handtest.

## Duplikat-App-Ids durch Archiv-Kopien

`discover-apps.ps1` findet **jede** Kopie eines App-Ordners unterhalb von
`PROJECTS_ROOT` — auch Archiv-/Backup-Kopien (z. B. in einem `old\`-Ordner).
Gleiche Ordnernamen ergeben dieselbe App-Id; `Get-AppOrFail` nimmt stillschweigend
den ersten Treffer. Vor dem Bauen im Zweifel prüfen, welcher Pfad gewinnt
(`(Get-AppOrFail -Id '<id>').Path`), und Archiv-Kopien umbenennen oder deren
`gradlew.bat` entfernen, damit sie nicht mehr entdeckt werden.

## Lokaler Debug-Loop

`gradlew installDebug` → APK per USB aufs Gerät → starten. Debug-Builds signiert
Gradle automatisch mit einem eigenen Debug-Keystore. Daraus folgen zwei Dinge,
die regelmäßig für Verwirrung sorgen:

- Ein Debug-Build **kann nicht** über eine anders signierte Version derselben App
  installiert werden — etwa die aus dem Store oder von einer eigenen Download-Seite
  (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). Auf dem Testgerät muss sie einmalig
  entfernt werden. Ein Release-Keystore wird für den Debug-Loop **nie** gebraucht;
  er gehört nicht in dieses Repo (allenfalls sein Pfad in die ignorierte `.env`).
- Sollen Release- und Debug-Version **nebeneinander** liegen, genügt ein
  `applicationIdSuffix = ".debug"` allein oft nicht: Ist irgendeine
  Provider-Authority im `AndroidManifest.xml` als Literal eingetragen (typisch beim
  FileProvider), kollidieren beide Apps darüber
  (`INSTALL_FAILED_CONFLICTING_PROVIDER`). Sie müsste dann auf
  `${applicationId}.fileprovider` umgestellt werden — eine Änderung **im App-Repo**,
  die diese Umgebung bewusst niemandem aufzwingt. Der einfachere Weg ist ein
  separates Testgerät.

## Arbeitsweise

- Vor dem Anlegen neuer Dateien: prüfen, ob es dafür schon einen Ort gibt.
- Änderungen an den Skripten immer gegen den echten Fall testen (Gerät
  angeschlossen, Build läuft durch), nicht nur „sieht richtig aus".
- Nach Änderungen an der Ablagestruktur: **diese Datei aktualisieren.**
