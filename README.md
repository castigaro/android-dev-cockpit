**English** | [Deutsch](README.de.md)

# android-dev-cockpit

A complete, portable Android development environment for Windows — set up by
double-click, without typing a single command line.

**What for?** If you have no Android toolchain installed, a code change only
becomes visible on your phone after the full detour through CI, a release, and a
manual download onto the device. With this environment the same trip takes
**about 30 seconds**: change the code, click **Build & Run** in VS Code, and the
app is running on the phone plugged into your USB port.

This repo knows **no particular app**. You put your own app repository next to
it, and the environment finds it by itself.

> **A note on language.** The documentation exists in English and German, but the
> tool itself speaks **German**: the console output of `install.cmd`, every error
> message, and the VS Code task labels. Everything is documented here, so you can
> follow along — but you have been warned. If you would like the tool in English,
> open an issue; it is a mechanical change, and I will happily make it if anyone
> actually wants it.

---

## On a new machine

```
1. Clone this repository        git clone <url> android-dev-cockpit
2. Double-click install.cmd     downloads Java and the Android SDK, sets up everything
3. Put your app repo next to it git clone <your-app> ../your-app
4. Open app-development.code-workspace in VS Code
```

That is all. Step 2 downloads about 1.5 GB and takes a few minutes. The folder
name is yours to choose — no script depends on it.

After cloning a further app repo, just run the **workspace** script — the
environment discovers the new app on its own.

### Requirements

Windows, Git, and an internet connection. Nothing else. Neither Java nor the
Android SDK nor Android Studio needs to be installed beforehand — that is exactly
what `install.cmd` takes care of.

### What the environment expects from your app

Only what an Android project has anyway: a `gradlew.bat`, containing an `app/`
module with a `build.gradle.kts` and an `applicationId`. That works for a
single-app repo (`<repo>/gradlew.bat`) as well as for a monorepo holding several
Gradle projects (`<repo>/apps/<app>/gradlew.bat`). There is **nothing to
configure** — no list of apps, no paths.

---

## Using it

Everything runs from **play buttons in VS Code** — using built-in features, with
no extension whatsoever.

In the Explorer (left sidebar), open the **NPM SCRIPTS** view at the bottom. Every
action sits there with a ▶ button next to it. One click, done.

> **Don't see the view? That is normal — it is merely hidden.**
> Hover over the Explorer title bar ("EXPLORER"), click the **`…`** menu on the
> right, and tick **NPM Scripts**. It appears at the very bottom, below "Outline"
> and "Timeline".
>
> Why: the generated workspace contains several folders (this one plus your app
> repos). In such a multi-root workspace, VS Code does not consider `package.json`
> to be at the "top level", and then it will not surface the view by itself. Once
> ticked, it stays visible.

`<app>` below stands for the name of your app as the environment discovered it —
if the project folder is called `my-app`, the scripts are called `my-app`,
`my-app:push`, and so on.

| Script | What happens |
| --- | --- |
| **`<app>`** | Builds the debug build, installs it over USB, and launches the app. **The default path.** |
| **`<app>:push`** | Builds and pushes the APK into the phone's Downloads folder — you tap it there once. Only needed on **Xiaomi/Redmi/POCO**, and only **once** (see below). |
| **`<app>:reinstall`** | Installs the *last build* again — without rebuilding. |
| **`<app>:logs`** | Live logs from the phone, filtered down to this app alone. Stop with `Ctrl+C`. |
| **`<app>:clean`** | Empties the build folder, for when Gradle behaves strangely. |
| **`<app>:uninstall`** | Removes the app from the phone. Asks first — its data will be lost. |
| **device** | Checks the USB connection and shows which apps are on the phone. The first place to look when something is wrong. |
| **workspace** | Re-discovers apps after you have added an app repo. |
| **setup** | Set up or repair the environment — the same as `install.cmd`. |

You get this set **for every app found**. With two app repos next to you, there
are simply two sets.

### Without a mouse

**`Ctrl+Shift+B`** builds the first app straight away — it is the default task.
Via **Terminal → Run Task…** you reach every action as a plain-text list.

This works **without Node**, too. Node only supplies the play buttons; the logic
lives in PowerShell scripts that VS Code invokes directly.

### Why no extension?

Buttons in the *status bar* could only come from an extension — and an extension
that executes commands has full access to your machine. The NPM SCRIPTS view is
built into VS Code and does the same job. No foreign code, nothing to install,
nothing to trust.

And should you go looking for "Task Buttons" in the marketplace: there are
**name-alike packages from unverified publishers** there. You don't need them.

---

## Preparing the phone (once)

1. **Settings → About phone** → tap **Build number** seven times. It will say
   "You are now a developer."
2. **Settings → System → Developer options** → enable **USB debugging**.
3. Connect the phone over USB.
4. The phone shows **"Allow USB debugging?"** → confirm with **"Always allow from
   this computer"**.
5. In VS Code, run the **`device`** script. Your phone has to show up there.

### Important: a debug build and a published version are mutually exclusive

If the **published** version of your app is already on the phone — from the Play
Store, from your own download page, wherever — then it is signed with your release
key. The local debug build is not. Android does not allow an update across
different signatures.

That version therefore has to be **removed once** from the test device (script
`<app>:uninstall`). After that you are done: every new debug build installs
silently over the previous one — no uninstalling, no version numbers, nothing.

**So use a separate test device**, not the phone where the app runs in production
with real data.

A release keystore is **not** needed for any of this. Gradle signs debug builds
automatically with a debug keystore of its own.

---

## Special case: Xiaomi / Redmi / POCO (MIUI, HyperOS)

On these devices you need **one tap of your finger, once** — after that everything
runs like anywhere else.

**The very first time**, when the app does not exist on the phone at all yet:

1. Run the **`<app>:push`** script. It builds and drops the APK into the phone's
   Downloads folder.
2. On the phone: file manager → Downloads → tap the APK → **Install**. MIUI asks
   once whether it may install from this source — allow it.

**From then on** the ordinary **`<app>`** works fully automatically, in ~8 seconds,
with no tapping at all. MIUI only blocks the *first* installation over ADB;
*updates* to an app that already exists pass through without complaint.

You will never need `<app>:push` again — unless you uninstall the app from the
phone at some point.

### Why this happens

MIUI rejects every **fresh** installation over ADB with
`INSTALL_FAILED_USER_RESTRICTED`. This was measured, not guessed — on a Redmi Note
10 (MIUI Global V14, Android 13), *every* route failed identically before the
first manual install:

| Attempt | Result |
| --- | --- |
| `adb install` (streamed) | `INSTALL_FAILED_USER_RESTRICTED` |
| `pm install` straight from the shell | `INSTALL_FAILED_USER_RESTRICTED` |
| `pm install --user 0` | `INSTALL_FAILED_USER_RESTRICTED` |
| `pm install --install-reason POLICY` | `INSTALL_FAILED_USER_RESTRICTED` |
| `pm install -i com.android.vending` (faking the source) | `INSTALL_FAILED_USER_RESTRICTED` |
| Session-based (`install-create`/`-write`/`-commit`) | create ✓, write ✓, **commit ✗** |
| **After one manual first install: `adb install -r`** | **✓ Success** |

The last two rows are the revealing ones. In the session-based route the 6 MB land
on the device cleanly and only the `commit` is refused — MIUI steps in right at the
very end. And as soon as the package exists once, the block is gone.

This is **not an Android restriction**: `dumpsys user` reports zero restrictions
set for the primary user. It is MIUI's own, patched package manager.

### What you can save yourself

The developer options **"USB debugging (Security settings)"** and **"Install via
USB"** would be the official route — but they stay greyed out unless a **Mi
account** is signed in, and even then MIUI additionally demands an **inserted SIM
card**. On a SIM-less test device that is a dead end. **You don't need it:** the
single tap above replaces the whole circus.

The old workaround of turning off **"MIUI optimization"** no longer exists — Xiaomi
removed the switch in MIUI 13/14.

---

## Layout

```
android-dev-cockpit\
├── install.cmd            double-click → sets up everything
├── install.ps1            the actual setup (idempotent)
├── .env                   local settings (gitignored, from .env.example)
├── AGENTS.md              rules and orientation for AI assistants
├── scripts\               the scripts behind the buttons
├── toolchain\             Java 17, Android SDK, Gradle cache   (gitignored)
├── builds\                the finished APKs                    (gitignored)
└── planning\<project>\    your notes on the project            (gitignored)

..\<your-app-repo>\        your app repository — a sibling, not inside!
```

The toolchain lives **inside the repo folder**, not in the system: no installer, no
permanent environment variables, no Android Studio. Delete `toolchain\` and the
environment is gone without a trace; `install.cmd` rebuilds it.

App repositories sit **next to** this one, not inside it — nested Git repositories
would be the alternative, and they are nothing but trouble.

### How apps are discovered

The scripts search below `PROJECTS_ROOT` (from `.env`, the parent directory by
default) for directories holding a `gradlew.bat` and an `app/` module, and read out
`applicationId` and `rootProject.name` themselves. A single-app repo and a monorepo
with several Gradle projects are recognised alike — with nothing to register
anywhere.

### `planning\`

A place for your own notes on a given project. Its contents are **gitignored** and
stay on your machine: project notes are rarely meant for the public, and this repo
is meant to stay neutral.

### `.env`

For the ordinary debug loop there is **nothing** to set. It only becomes interesting
when your app needs a different SDK version (`ANDROID_PLATFORM`,
`ANDROID_BUILD_TOOLS`) or your app repos live elsewhere (`PROJECTS_ROOT`).

Optionally you can enter `RELEASE_KEYSTORE_PATH` and `RELEASE_STORE_PASSWORD`. The
`.env` is gitignored; the keystore itself does **not** belong in this repository —
only its path does.

---

## When something goes wrong

**"No Android device found over USB"**
Is USB debugging on? Does the cable carry data (some charging cables carry power
only)? Unplug and replug the phone, then run **`device`**.

**"The device has not authorised this computer yet"**
A dialog appears on the phone. It is easy to miss — unlock the screen and look.
If it does not appear: replug the cable.

**`INSTALL_FAILED_USER_RESTRICTED` — "Install canceled by user"**
Affects **Xiaomi, Redmi and POCO** (MIUI/HyperOS). → Use **`<app>:push`** once
instead of **`<app>`**. The reason is in the "Special case: Xiaomi" section above.

**`INSTALL_FAILED_UPDATE_INCOMPATIBLE`**
The published, differently signed version of your app is on the phone. Run
`<app>:uninstall`, then build again. (See above.)

**`INSTALL_FAILED_CONFLICTING_PROVIDER`**
Two apps claim the same provider authority (usually the FileProvider, entered in
`AndroidManifest.xml` as a literal instead of `${applicationId}.fileprovider`).
Remove the colliding app from the device.

**Gradle complains about the Java version**
It has to be Java 17. Run `install.cmd` again — it checks and repairs.

**Strange Gradle errors after bigger changes**
Run `<app>:clean`, then build again.

**The first build takes forever**
It does. Gradle and all dependencies are downloaded once (5–10 minutes). After
that, a run takes 20–40 seconds.

---

## What happens to your app repository

**Nothing** — `git status` stays empty over there.

Gradle puts its build folder inside the app repo, but that folder is in the app's
own `.gitignore` anyway. The finished APKs are additionally copied to `builds\`.

The only file this environment places there is a `CLAUDE.md` — a signpost so that
AI sessions find the rules in `AGENTS.md`. It is created during installation and,
in the same breath, entered into `.git/info/exclude`, i.e. Git's **local**,
unversioned ignore list. It therefore shows up neither in `git status` nor on
GitHub. An existing `CLAUDE.md` is never overwritten. On a new machine,
`install.cmd` simply creates it again.

Your existing release path stays untouched — whatever your CI does, it keeps doing.
Local debug builds never come near it.

---

## License

MIT — see [LICENSE](LICENSE). Take it, rebuild it, do whatever you like with it.
