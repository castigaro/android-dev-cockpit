# android-dev-cockpit

Eine komplette, portable Entwicklungsumgebung für Android-Apps unter Windows —
eingerichtet per Doppelklick, ohne eine einzige Zeile Kommandozeile.

**Wozu?** Wer keine Android-Toolchain installiert hat, sieht eine Codeänderung
erst nach dem vollen Umweg über CI, Release und manuelles Herunterladen auf dem
Gerät. Mit dieser Umgebung dauert derselbe Weg **rund 30 Sekunden**: Code
ändern, in VS Code auf **Build & Run** klicken, App läuft auf dem
angeschlossenen Handy.

Das Repo kennt **keine bestimmte App**. Du legst dein eigenes App-Repository
daneben, und die Umgebung findet es von selbst.

---

## Auf einem neuen Rechner

```
1. Repository klonen              git clone <url> android-dev-cockpit
2. install.cmd doppelklicken      lädt Java, Android SDK und richtet alles ein
3. Dein App-Repo daneben legen    git clone <deine-app> ../deine-app
4. app-development.code-workspace in VS Code öffnen
```

Mehr ist es nicht. Schritt 2 lädt rund 1,5 GB und dauert ein paar Minuten.
Der Ordnername ist frei wählbar — kein Skript hängt daran.

Nach dem Klonen eines weiteren App-Repos genügt der Task
**Workspace aktualisieren** — die Umgebung findet die neue App selbst.

### Voraussetzungen

Windows, Git, und eine Internetverbindung. Sonst nichts. Weder Java noch das
Android SDK noch Android Studio müssen vorher installiert sein — genau das
erledigt `install.cmd`.

### Was die Umgebung von deiner App erwartet

Nur das Übliche eines Android-Projekts: ein `gradlew.bat`, darin ein Modul
`app/` mit `build.gradle.kts` und einer `applicationId`. Das passt sowohl für ein
Single-App-Repo (`<repo>/gradlew.bat`) als auch für ein Monorepo mit mehreren
Gradle-Projekten (`<repo>/apps/<app>/gradlew.bat`). Es gibt **nichts
einzutragen** — keine App-Liste, keine Pfade.

---

## Bedienung

Alles läuft über **Play-Buttons in VS Code** — und zwar mit Bordmitteln, ohne eine
einzige Extension.

Öffne im Explorer (linke Seitenleiste) unten die Ansicht **NPM SCRIPTS**. Dort
steht jede Aktion mit einem ▶-Button daneben. Ein Klick, fertig.

`<app>` steht dabei für den Namen deiner App, so wie die Umgebung sie gefunden
hat — heißt der Projektordner `meine-app`, heißen die Skripte `meine-app`,
`meine-app:push` und so weiter.

| Skript | Was passiert |
| --- | --- |
| **`<app>`** | Baut den Debug-Build, installiert ihn per USB und startet die App. **Der Standardweg.** |
| **`<app>:push`** | Baut und schiebt die APK in die Downloads des Handys — du tippst sie dort einmal an. Nur bei **Xiaomi/Redmi/POCO** und nur **einmal** nötig (siehe unten). |
| **`<app>:reinstall`** | Installiert den *zuletzt gebauten* Stand erneut — ohne zu bauen. |
| **`<app>:logs`** | Live-Logs der App vom Handy, gefiltert auf genau diese App. Beenden mit `Strg+C`. |
| **`<app>:clean`** | Build-Ordner leeren, bei merkwürdigen Gradle-Fehlern. |
| **`<app>:uninstall`** | App vom Handy entfernen. Fragt vorher nach — die Daten gehen verloren. |
| **device** | Prüft die USB-Verbindung und zeigt, welche Apps auf dem Handy liegen. Erste Anlaufstelle bei Problemen. |
| **workspace** | Apps neu suchen, nachdem du ein App-Repo dazugelegt hast. |
| **setup** | Entwicklungsumgebung einrichten/reparieren — dasselbe wie `install.cmd`. |

Diesen Satz gibt es **für jede gefundene App**. Liegen zwei App-Repos daneben,
stehen dort eben zwei Sätze.

### Ohne Maus

**`Strg+Shift+B`** startet direkt den Build der ersten App — der Standard-Task.
Über **Terminal → Task ausführen…** erreichst du alle Aktionen als Auswahlliste
in Klartext.

Das funktioniert auch **ohne Node**. Node liefert nur die Play-Buttons; die
Logik steckt in PowerShell-Skripten, die VS Code direkt aufruft.

### Warum keine Extension?

Buttons in der *Statusleiste* könnte nur eine Extension liefern — und eine
Extension, die Befehle ausführt, hat vollen Zugriff auf den Rechner. Die
NPM-SCRIPTS-Ansicht ist in VS Code eingebaut und leistet dasselbe. Kein fremder
Code, nichts zu installieren, nichts zu vertrauen.

Falls du im Marketplace nach „Task Buttons" suchst: Dort gibt es
**Namensdoppelgänger von unverifizierten Anbietern**. Brauchst du nicht.

---

## Das Handy vorbereiten (einmalig)

1. **Einstellungen → Über das Telefon** → siebenmal auf **Buildnummer** tippen.
   Es erscheint „Du bist jetzt Entwickler."
2. **Einstellungen → System → Entwickleroptionen** → **USB-Debugging**
   einschalten.
3. Handy per USB anschließen.
4. Auf dem Handy erscheint **„USB-Debugging zulassen?"** → mit **„Diesem
   Computer immer vertrauen"** bestätigen.
5. In VS Code das Skript **`device`** starten. Das Handy muss dort auftauchen.

### Wichtig: Debug-Build und veröffentlichte Version schließen sich aus

Liegt auf dem Handy schon die **veröffentlichte** Version deiner App — aus dem
Play Store, von einer eigenen Download-Seite, egal woher —, dann ist sie mit
deinem Release-Schlüssel signiert. Der lokale Debug-Build ist es nicht. Android
lässt kein Update zwischen unterschiedlichen Signaturen zu.

Diese Version muss auf dem Testgerät deshalb **einmalig entfernt** werden (Skript
`<app>:uninstall`). Danach ist Ruhe: Jeder neue Debug-Build installiert sich still
über den vorherigen — kein Deinstallieren, keine Versionsnummern, nichts.

**Deshalb: ein separates Testgerät benutzen**, nicht das Handy, auf dem die App
produktiv mit echten Daten läuft.

Ein Release-Keystore wird für all das **nicht** gebraucht. Debug-Builds signiert
Gradle automatisch mit einem eigenen Debug-Keystore.

---

## Sonderfall Xiaomi / Redmi / POCO (MIUI, HyperOS)

Auf diesen Geräten brauchst du **einmalig einen Fingertipp** — danach läuft alles
wie überall sonst.

**Beim allerersten Mal**, wenn die App auf dem Handy noch gar nicht existiert:

1. Skript **`<app>:push`** starten. Es baut und legt die APK in den
   Downloads-Ordner des Handys.
2. Am Handy: Dateimanager → Downloads → APK antippen → **Installieren**.
   MIUI fragt einmal, ob es aus dieser Quelle installieren darf — zulassen.

**Ab dann** funktioniert das normale **`<app>`** vollautomatisch, in ~8 Sekunden,
ohne jedes Antippen. MIUI blockiert nämlich nur die *Erst*installation über ADB;
*Updates* einer bereits vorhandenen App lässt es anstandslos durch.

`<app>:push` brauchst du danach nie wieder — außer du deinstallierst die App
irgendwann vom Handy.

### Warum das so ist

MIUI weist jede **Neu**installation über ADB mit `INSTALL_FAILED_USER_RESTRICTED`
ab. Das ist nachgemessen, nicht vermutet — auf einem Redmi Note 10 (MIUI Global
V14, Android 13) scheiterten vor der ersten manuellen Installation *alle* Wege
identisch:

| Versuch | Ergebnis |
| --- | --- |
| `adb install` (Streamed) | `INSTALL_FAILED_USER_RESTRICTED` |
| `pm install` direkt aus der Shell | `INSTALL_FAILED_USER_RESTRICTED` |
| `pm install --user 0` | `INSTALL_FAILED_USER_RESTRICTED` |
| `pm install --install-reason POLICY` | `INSTALL_FAILED_USER_RESTRICTED` |
| `pm install -i com.android.vending` (Quelle vortäuschen) | `INSTALL_FAILED_USER_RESTRICTED` |
| Session-basiert (`install-create`/`-write`/`-commit`) | create ✓, write ✓, **commit ✗** |
| **Nach einer manuellen Erstinstallation: `adb install -r`** | **✓ Success** |

Aufschlussreich sind die letzten beiden Zeilen. Bei der Session landen die 6 MB
sauber auf dem Gerät, und erst der `commit` wird abgewiesen — MIUI greift ganz am
Ende ein. Und sobald das Paket einmal existiert, ist die Sperre weg.

Es ist **keine Android-Beschränkung**: `dumpsys user` zeigt für den Hauptbenutzer
null gesetzte Restrictions. Es ist MIUIs eigener, gepatchter Paketmanager.

### Was du dir sparen kannst

Die Entwickleroptionen **„USB-Debugging (Sicherheitseinstellungen)"** und
**„Über USB installieren"** wären der offizielle Weg — sie sind aber ausgegraut,
solange kein **Mi-Konto** angemeldet ist, und selbst dann verlangt MIUI
zusätzlich eine **eingelegte SIM-Karte**. Auf einem SIM-losen Testgerät ist das
eine Sackgasse. **Brauchst du nicht**: Der eine Fingertipp oben ersetzt den ganzen
Zirkus.

Der frühere Ausweg, die **„MIUI-Optimierung"** abzuschalten, existiert nicht mehr —
Xiaomi hat den Schalter in MIUI 13/14 entfernt.

---

## Aufbau

```
android-dev-cockpit\
├── install.cmd            Doppelklick → richtet alles ein
├── install.ps1            die eigentliche Einrichtung (idempotent)
├── .env                   lokale Einstellungen (gitignoriert, aus .env.example)
├── AGENTS.md              Regeln und Orientierung für KI-Assistenten
├── scripts\               die Skripte hinter den Buttons
├── toolchain\             Java 17, Android SDK, Gradle-Cache   (gitignoriert)
├── builds\                die fertigen APKs                    (gitignoriert)
└── planning\<projekt>\    deine Notizen zum Projekt            (gitignoriert)

..\<dein-app-repo>\        dein App-Repository — Geschwister, nicht darin!
```

Die Toolchain liegt **im Repo-Ordner**, nicht im System: kein Installer, keine
dauerhaften Umgebungsvariablen, kein Android Studio. Die Umgebung ist durch
Löschen von `toolchain\` restlos entfernbar. `install.cmd` baut sie neu auf.

Die App-Repositories liegen **daneben**, nicht darin — verschachtelte
Git-Repositories wären sonst die Folge.

### Wie die Apps gefunden werden

Die Skripte suchen unterhalb von `PROJECTS_ROOT` (aus der `.env`, standardmäßig
das Elternverzeichnis) nach Verzeichnissen mit `gradlew.bat` und einem
`app/`-Modul und lesen `applicationId` und `rootProject.name` selbst heraus. So
werden ein Single-App-Repo und ein Monorepo mit mehreren Gradle-Projekten
gleichermaßen erkannt — ohne dass irgendwo etwas eingetragen werden muss.

### `planning\`

Ein Ort für deine eigenen Notizen zum jeweiligen Projekt. Der Inhalt ist
**gitignoriert** und bleibt auf deinem Rechner: Projektnotizen sind selten für
die Öffentlichkeit gedacht, und dieses Repo soll neutral bleiben.

### `.env`

Für den normalen Debug-Loop ist dort **nichts** einzustellen. Interessant wird
sie erst, wenn deine App eine andere SDK-Version braucht (`ANDROID_PLATFORM`,
`ANDROID_BUILD_TOOLS`) oder die App-Repos woanders liegen (`PROJECTS_ROOT`).

Optional lassen sich `RELEASE_KEYSTORE_PATH` und `RELEASE_STORE_PASSWORD`
eintragen. Die `.env` ist gitignoriert; der Keystore selbst gehört **nicht** in
dieses Repository, nur sein Pfad.

---

## Wenn etwas klemmt

**„Kein Android-Gerät per USB gefunden"**
USB-Debugging eingeschaltet? Kabel überträgt Daten (manche Ladekabel können nur
Strom)? Handy einmal ab- und wieder anstecken, dann **`device`** starten.

**„Das Gerät hat den Rechner noch nicht autorisiert"**
Auf dem Handy erscheint ein Dialog. Er lässt sich leicht übersehen — Bildschirm
entsperren und nachsehen. Erscheint er nicht: Kabel neu einstecken.

**`INSTALL_FAILED_USER_RESTRICTED` — „Install canceled by user"**
Betrifft **Xiaomi, Redmi und POCO** (MIUI/HyperOS). → Nimm einmalig
**`<app>:push`** statt **`<app>`**. Warum, steht oben im Abschnitt „Sonderfall
Xiaomi".

**`INSTALL_FAILED_UPDATE_INCOMPATIBLE`**
Auf dem Handy liegt die veröffentlichte, anders signierte Version deiner App.
`<app>:uninstall` ausführen, dann erneut bauen. (Siehe oben.)

**`INSTALL_FAILED_CONFLICTING_PROVIDER`**
Zwei Apps beanspruchen dieselbe Provider-Authority (meist der FileProvider, im
`AndroidManifest.xml` als Literal statt `${applicationId}.fileprovider`
eingetragen). Die kollidierende App vom Gerät entfernen.

**Gradle meckert über die Java-Version**
Es muss Java 17 sein. `install.cmd` erneut ausführen — es prüft und repariert.

**Merkwürdige Gradle-Fehler nach größeren Änderungen**
Task **Build-Ordner aufräumen**, dann neu bauen.

**Erster Build dauert ewig**
Ist so. Gradle und alle Abhängigkeiten werden einmalig geladen (5–10 Minuten).
Danach dauert ein Durchlauf 20–40 Sekunden.

---

## Was mit deinem App-Repository passiert

**Nichts** — `git status` bleibt dort leer.

Gradle legt seinen Build-Ordner innerhalb des App-Repos an, aber der steht dort
ohnehin in der `.gitignore`. Die fertigen APKs werden zusätzlich nach `builds\`
kopiert.

Die einzige Datei, die die Umgebung ablegt, ist eine `CLAUDE.md` — ein Wegweiser,
damit KI-Sitzungen die Regeln aus `AGENTS.md` finden. Sie wird bei der
Installation angelegt und im selben Zug in `.git/info/exclude` eingetragen, also
in Gits **lokale**, nicht versionierte Ignorier-Liste. Sie taucht damit weder in
`git status` noch auf GitHub auf. Eine bereits vorhandene `CLAUDE.md` wird nie
überschrieben. Auf einem neuen Rechner legt `install.cmd` sie einfach wieder an.

Dein bisheriger Release-Weg bleibt unangetastet — was immer deine CI tut, tut sie
weiter. Lokale Debug-Builds berühren sie nicht.

---

## Lizenz

MIT — siehe [LICENSE](LICENSE). Nimm es, bau es um, mach damit, was du willst.
