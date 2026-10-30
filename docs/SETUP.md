# Setup guide

## 1. Pair the speaker
1. Turn on the MiniToo. Close the Divoom app on your phone (or turn the phone's Bluetooth off).
2. Windows: Settings > Bluetooth & devices > Add device > Bluetooth > pick **Divoom MiniToo-Audio**.
3. Optional: set it as your default sound output if you want Grok Bot's voice to play from it.
   The buddy lip-syncs to whatever the *default output* device plays.

## 2. Install
```powershell
cd <unzipped folder>
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```
Options: `-InstallDir <path>` (default `%LOCALAPPDATA%\Speakling`), `-NoTask` (copy only, no scheduled task),
`-NoStart` (register the task but don't start it now), `-TaskName <name>` (default `Speakling Watcher`).
The installer prints `Found MiniToo at ...` when auto-discovery works; a warning instead means the speaker
isn't paired yet (pair it, then re-run, or set `bt_address`).

## 3. Configure (optional)
`config.json` in the install folder:
```json
{ "device_name": "Divoom MiniToo-Audio", "bt_address": "" }
```
Leave `bt_address` empty to auto-discover the paired device by name (the result is cached in `device.cache`;
delete it after re-pairing). Fixed weather location: copy `location_override.example.json` to
`location_override.json` and set `lat`, `lon`, `state` (US two-letter code, optional).

## 4. Run by hand / test
```powershell
cd $env:LOCALAPPDATA\Speakling
.\watch_speak.ps1 -Seconds 120          # run 2 minutes in the console
.\watch_speak.ps1 -Seconds 60 -Dry      # no Bluetooth, just log decisions
.\watch_speak.ps1 -Seconds 120 -Holiday christmas -ForceWx snow -GagNow
```
Useful flags: `-NoWeather -NoTod -NoStamp -NoScene -NoGag -NoHoliday`, `-Holiday <name|none|st-XX>`,
`-State XX`, `-AsOf yyyy-mm-dd`, `-Lat/-Lon`, `-BoredAfterSeconds 300`, `-GagMinMinutes 60 -GagMaxMinutes 180`,
`-WeatherMinutes 15`, `-BtAddress AA:BB:CC:DD:EE:FF`. Log: `watch.log`.

## 5. Always-on (scheduled task)
`install.ps1` registers **Speakling Watcher** (at log-on, current user). It runs `run_watch.ps1`,
which restarts the watcher 15 s after any exit, until a `watch.stop` file appears.

| Action | Command |
|---|---|
| Stop cleanly | `New-Item -ItemType File -Force "$env:LOCALAPPDATA\Speakling\watch.stop"; Stop-ScheduledTask 'Speakling Watcher'` |
| Start again | `Remove-Item "$env:LOCALAPPDATA\Speakling\watch.stop"; Start-ScheduledTask 'Speakling Watcher'` |
| Disable at log-on | `Disable-ScheduledTask 'Speakling Watcher'` |
| Re-enable | `Enable-ScheduledTask 'Speakling Watcher'` |
| Uninstall | `Unregister-ScheduledTask 'Speakling Watcher' -Confirm:$false` or `.\uninstall.ps1 -RemoveFiles` (pass the same `-InstallDir`/`-TaskName` if you changed them) |

## 6. Grok Bot announcements (optional)
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
