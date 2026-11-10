# Speakling for Grok Bot

> **Unofficial community project.** Not made by, affiliated with, or endorsed by Divoom or the Grok Bot team.
> Divoom and MiniToo are trademarks of their respective owners.

A cozy, talking pixel-face buddy for the **Divoom MiniToo** Bluetooth speaker on Windows. It becomes
Grok Bot's face: it idles softly on the MiniToo's 128x128 screen, moves its mouth when Grok Bot speaks
(read-aloud replies, announcements, voice calls), and quietly reflects the time, weather and season.

| Idle (sunny) | Talking (rain) | Snow | Christmas |
|---|---|---|---|
| <picture><source srcset="docs/images/sunny_idle_plain.avif" type="image/avif"><img src="docs/images/sunny_idle_plain.gif" alt="idle" width="256"></picture> | <picture><source srcset="docs/images/talk_day_rain_talk.avif" type="image/avif"><img src="docs/images/talk_day_rain_talk.gif" alt="talk" width="256"></picture> | <picture><source srcset="docs/images/snow_idle.avif" type="image/avif"><img src="docs/images/snow_idle.gif" alt="snow" width="256"></picture> | <picture><source srcset="docs/images/christmas_idle.avif" type="image/avif"><img src="docs/images/christmas_idle.gif" alt="christmas" width="256"></picture> |

[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ea4aaa?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/mikebeee)

## Features (designed to be cozy: soft light, gentle motion, nothing jarring)
- **Idle animations** - glances, blinks, antenna sparkle, a happy bounce, a curious head tilt.
- **Lip-sync talking** - listens to the PC's default audio output and animates the mouth by loudness
  whenever anything plays, so Grok Bot's read-aloud and voice replies "come from" the buddy.
- **Bored face** after 5 minutes of silence (`-BoredAfterSeconds`).
- **Time of day** - morning, day, evening and night (stars and moon) looks from the PC clock.
- **Live weather** for where you are, from keyless [Open-Meteo](https://open-meteo.com): sunny, cloudy, rain,
  storm, fog, snow backdrops plus a small summary line (e.g. `RAIN 67F 81%`). Your location comes from
  Windows Location automatically; there is nothing to set up. A fresh reading is fetched every time
  Speakling starts and every 15 minutes.
- **Clock** - small HH:MM in the corner, refreshed every minute.
- **Birds** drift by every few minutes, and a rare (every 1-3 h) bird gag with a rainbow-colored spray finish
  (`-NoGag` to turn it off).
- **Holidays** - Halloween, Thanksgiving, Christmas, New Year, Valentine's, St Patrick's, Easter, July 4,
  plus a state observance for each US state (from 3 days before to the day).
- **Grok Bot announcements** - optional `tools/buddy.py` builds a chime + "new message" face and a
  lip-synced spoken clip; `buddy.ps1` plays it on the PC.

## Requirements
- Windows 10 or 11 with Bluetooth, Windows PowerShell 5.1 (built in).
- A Divoom MiniToo, paired in Windows (shows as **Divoom MiniToo-Audio**).
- Internet for weather (optional), and Windows Location turned on for local weather.
- Optional, for `tools/buddy.py` only: Python 3.9+, `pip install pillow numpy zstandard edge-tts`, and ffmpeg.

## Quick start
You need a **Divoom MiniToo** and a **Windows 10 or 11 PC with Bluetooth**.
1. Pair the MiniToo: Settings > Bluetooth & devices > Add device > Bluetooth > *Divoom MiniToo-Audio*.
   Close the Divoom phone app (the speaker allows only one connection).
2. Download the latest `Speakling-for-Grok-Bot-vX.Y.Z.zip` from the [Releases](https://github.com/mikebeee/Speakling-for-Grok-Bot/releases/latest) page and unzip it.
3. In that folder run:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
   ```
   This copies the files to `%LOCALAPPDATA%\Speakling`, finds the speaker by name, sets Speakling to start
   when you sign in to Windows, and starts it. Upgrading? Just run the new installer; it stops the old copy first.
4. Allow location for local weather: if Windows asks whether to let PowerShell / desktop apps use your
   location, choose **Allow**. Otherwise open Settings > Privacy & security > Location and turn on
   **Location services** and **Let desktop apps access your location**. If location is blocked, the buddy
   shows the weather for Spring, TX instead.
5. Play any sound - the buddy should start talking.

Step by step install guide, settings and every flag: [docs/SETUP.md](docs/SETUP.md). Questions or ideas: use the **Discussions** tab.

## Stop, disable, uninstall
```powershell
$d="$env:LOCALAPPDATA\Speakling"
New-Item -ItemType File -Force "$d\watch.stop"; Stop-ScheduledTask 'Speakling Watcher'   # stop cleanly
Disable-ScheduledTask 'Speakling Watcher'                                                 # don't start at log-on
Remove-Item "$d\watch.stop"; Enable-ScheduledTask 'Speakling Watcher'; Start-ScheduledTask 'Speakling Watcher'  # start again
Unregister-ScheduledTask 'Speakling Watcher' -Confirm:$false                               # remove task
# or: .\uninstall.ps1 [-RemoveFiles]   (add -InstallDir/-TaskName if you used custom ones)
```

## Troubleshooting
- **"MiniToo not reachable"** in `watch.log`: the speaker is off, out of range, or held by another
  connection (the Divoom app or another PC). The MiniToo holds **one** Bluetooth connection at a time;
  the watcher retries every 15 s.
- **Screen blanks briefly** when the scene changes - every change uploads a whole new clip; this is normal.
- **Clip size limit** - the device accepts about 13.5 KB per clip; the scene builder automatically falls
  back to calmer variants (less motion, fewer raindrops) to fit.
- **Wrong speaker / not found** - set `bt_address` in `config.json` (format `AA:BB:CC:DD:EE:FF`).
- **Weather is for Spring, TX** - location is blocked. Turn on Settings > Privacy & security > Location, including
  **Let desktop apps access your location**; Speakling picks it up within 15 minutes.
- **No weather on the screen** - Windows has not given a location yet (it can take a minute after sign-in, or the PC
  has no Wi-Fi to locate with) or the weather service is unreachable. Speakling keeps retrying and shows a plain sky
  meanwhile; `watch.log` says which (`location:` and `weather:` lines).

## Privacy
Your location is used only to pick the weather and the US state holiday. It comes only from Windows Location,
and only if you allow it; Speakling never looks up your location from your internet (IP) address. The US state
is worked out on your PC from a built-in map, with no web lookup. Your location is kept in memory only and is
never saved to disk. The only thing sent over the internet is your coordinates rounded to about 1 km, sent to
Open-Meteo to get the weather. Nothing else leaves your PC; no audio is recorded - only the output loudness
level is read. Use `-NoWeather` to turn off location and all network requests.

## Releases
Downloads are zipped GitHub release assets on the [Releases](https://github.com/mikebeee/Speakling-for-Grok-Bot/releases)
page (GitHub counts downloads per asset). What changed in each version: [CHANGELOG.md](CHANGELOG.md).

## Contributing
Issues and pull requests are welcome. Please keep the cozy rule: soft lighting, gentle movement, nothing
jarring, and keep every clip within the ~13.5 KB limit. Do not submit code copied from projects without a
compatible license.

## License
MIT, Copyright (c) 2026 Mike Babaie - see [LICENSE](LICENSE). Third-party components: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
