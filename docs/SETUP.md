# Install guide

This guide takes you from an unopened speaker to a talking buddy in about 10 minutes.

## What you need
- **A Divoom MiniToo** Bluetooth pixel speaker (it shows up in Windows as **Divoom MiniToo-Audio**).
- **A Windows 10 or 11 PC with Bluetooth.** Windows PowerShell 5.1 is already built in, nothing else to install.
- **Internet** for live weather (optional; everything else works offline).

## 1. Pair the speaker
1. Turn on the MiniToo. Close the Divoom app on your phone, or turn the phone's Bluetooth off.
   The MiniToo only allows **one** Bluetooth connection at a time.
2. On the PC open **Settings > Bluetooth & devices > Add device > Bluetooth** and pick **Divoom MiniToo-Audio**.
3. Optional: make it your default sound output if you want Grok Bot's voice to play from the speaker.
   The buddy lip-syncs to whatever your *default output* device plays.

## 2. Download Speakling
- When a release is published: open the repo's **Releases** page and download the latest `.zip`.
- Until then (or for the newest code): on the repo's main page click **Code > Download ZIP**.

Right-click the downloaded zip, choose **Extract All**, and open the extracted folder.

## 3. Install
In the extracted folder, click the address bar, type `powershell`, press Enter, then run:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```
The installer:
- copies Speakling to `%LOCALAPPDATA%\Speakling`,
- finds your speaker by name and prints `Found MiniToo at ...` (a warning means the speaker isn't paired yet; pair it and run the installer again),
- sets Speakling to **start automatically when you sign in to Windows**, and starts it right away.

Installer options: `-InstallDir <path>`, `-NoTask` (copy only, no start at sign in), `-NoStart`
(set up start at sign in but don't start now), `-TaskName <name>` (default `Speakling Watcher`).

## 4. Allow location (for correct local weather)
Speakling uses Windows' own location service to show the weather where you actually are. There is
nothing to type in.
1. Open **Settings > Privacy & security > Location**.
2. Turn on **Location services**.
3. Turn on **Let desktop apps access your location**.

That's it. If location stays off, the buddy still works; the weather just won't match your area.

## 5. First-time check
1. Play any sound on the PC (a video, a song, or a Grok Bot read-aloud reply). The buddy's mouth should move.
2. Within a minute or so the background should match your weather and the corner clock should show your time.
3. Leave it quiet for 5 minutes and you'll see the bored face; that means everything is running.

If nothing happens, open `%LOCALAPPDATA%\Speakling\watch.log`. **"MiniToo not reachable"** means the speaker is
off, out of range, or connected to your phone or another PC; Speakling retries every 15 seconds.

## 6. Start at sign in: turn it off or on
The installer sets this up for you. To change it later:

| Action | Command |
|---|---|
| Stop now | `New-Item -ItemType File -Force "$env:LOCALAPPDATA\Speakling\watch.stop"; Stop-ScheduledTask 'Speakling Watcher'` |
| Start again | `Remove-Item "$env:LOCALAPPDATA\Speakling\watch.stop"; Start-ScheduledTask 'Speakling Watcher'` |
| Don't start at sign in | `Disable-ScheduledTask 'Speakling Watcher'` |
| Start at sign in again | `Enable-ScheduledTask 'Speakling Watcher'` |
| Uninstall | `.\uninstall.ps1 -RemoveFiles` from the install folder |

## Optional settings
`config.json` in the install folder:
```json
{ "device_name": "Divoom MiniToo-Audio", "bt_address": "" }
```
Leave `bt_address` empty and Speakling finds the paired speaker by name (cached in `device.cache`; delete
that file after re-pairing). Only set `bt_address` (`AA:BB:CC:DD:EE:FF`) if it picks the wrong speaker.

## Need help?
Ask in the repo's **Discussions** tab: Q&A for setup questions, Bug Reports for problems, Feature Requests for ideas.

## Advanced: run by hand / test
```powershell
cd $env:LOCALAPPDATA\Speakling
.\watch_speak.ps1 -Seconds 120          # run 2 minutes in the console
.\watch_speak.ps1 -Seconds 60 -Dry      # no Bluetooth, just log decisions
.\watch_speak.ps1 -Seconds 120 -Holiday christmas -ForceWx snow -GagNow
```
Useful flags: `-NoWeather -NoTod -NoStamp -NoScene -NoGag -NoHoliday`, `-Holiday <name|none|st-XX>`,
`-State XX`, `-AsOf yyyy-mm-dd`, `-BoredAfterSeconds 300`, `-GagMinMinutes 60 -GagMaxMinutes 180`,
`-WeatherMinutes 15`, `-BtAddress AA:BB:CC:DD:EE:FF`. Log: `watch.log`.

## Advanced: the startup task in detail
`install.ps1` registers **Speakling Watcher** (at log-on, current user). It runs `run_watch.ps1`,
which restarts the watcher 15 s after any exit, until a `watch.stop` file appears.

| Action | Command |
|---|---|
| Stop cleanly | `New-Item -ItemType File -Force "$env:LOCALAPPDATA\Speakling\watch.stop"; Stop-ScheduledTask 'Speakling Watcher'` |
| Start again | `Remove-Item "$env:LOCALAPPDATA\Speakling\watch.stop"; Start-ScheduledTask 'Speakling Watcher'` |
| Disable at log-on | `Disable-ScheduledTask 'Speakling Watcher'` |
| Re-enable | `Enable-ScheduledTask 'Speakling Watcher'` |
| Uninstall | `Unregister-ScheduledTask 'Speakling Watcher' -Confirm:$false` or `.\uninstall.ps1 -RemoveFiles` (pass the same `-InstallDir`/`-TaskName` if you changed them) |

## Optional: Grok Bot announcements
The watcher alone already animates Grok Bot's read-aloud and voice replies. For a chime + "new message"
face and a spoken announcement built off-PC:
```bash
pip install pillow numpy zstandard edge-tts   # plus ffmpeg
python3 tools/buddy.py notify "Your report is ready"   # or: speak "text", idle
```
Copy `tools/job.zip` to the PC and run `.\buddy.ps1 -Job <path>\job.zip`. `buddy.ps1` takes a lock that
pauses the watcher while it plays, then hands the speaker back.

## Rebuilding the idle clip
`python3 tools/divoom_proto.py assets/idle_raw.bin 58 125 assets/idle.bin`

## Preview images
`docs/images` holds each preview as an animated **AVIF** (smaller, near-lossless: max 2/255 colour difference)
plus the original **GIF** as a fallback. The README uses `<picture>` so browsers that can show AVIF get it,
others get the GIF. After adding or changing a GIF, regenerate the AVIFs (needs Pillow 11.3+ with AVIF):
`python3 tools/export_avif.py`
