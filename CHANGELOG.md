# Changelog

## v1.0.1 - weather and location fix (unreleased draft)

### Fixed
- **Wrong place, wrong weather.** Speakling could show the weather for the wrong city (for example
  San Antonio for someone in Spring, TX, so "sunny" while it was raining at home). Causes:
  - the Windows Location check gave up before it started: it required permission to already read
    `Granted` before asking Windows (that value is often `Unknown` until the watcher starts), suppressed the
    permission prompt, and waited only 8 seconds for a first fix;
  - it then fell back to looking up your location from your internet (IP) address, which often points to
    your internet provider's hub city, not your home;
  - that wrong place was saved in `location.json` and reused for 3 hours, and a last-known place was reused
    forever when everything else failed.
- **Old weather at start-up.** The last reading (`weather.json`, up to 3 hours old) was shown when Speakling
  started, and a failed refresh kept showing the old condition indefinitely.
- "SUNNY" could be shown after sunset in autumn and winter (the label used fixed clock hours). It now uses
  Open-Meteo's `is_day`; the night sky also follows `is_day`.
- Measurable precipitation in the last 15 minutes now always shows rain, even if the model's weather code
  still says clear or cloudy.
- The installer failed when upgrading while Speakling was running (`libzstd.dll` in use). It now stops the
  running copy first.

### Changed
- Location comes **only** from the Windows location service (WinRT `Geolocator`, with the classic .NET
  `GeoCoordinateWatcher` as a backup), with a 45 s timeout. No IP lookup of any kind.
- If location is **blocked** (Location services off, desktop-app access off, or denied), Speakling shows the
  weather for **Spring, TX**, and checks again every 15 minutes so turning location on is picked up.
- If location is allowed but not available yet, Speakling shows a plain sky with no weather and retries
  (15 s, 30 s, 1, 2, 4, then every 5 minutes). It never guesses a place.
- A fresh weather reading is fetched at every start before any weather is shown, then every 15 minutes.
  If refreshes fail for more than 30 minutes the sky goes plain instead of showing an old reading.
  Nothing about location or weather is saved to disk.
- The US state for state holidays is found on the PC from a small built-in map
  (`assets/us_states.txt`, US Census Bureau outlines) instead of a web service.
- Freezing drizzle and freezing rain read `FRZ RAIN`.
- Log lines say which path was taken: `location: Windows Location ...`, `location: permission denied -> Spring, TX fallback`,
  or `location: location not available yet ...; retry #n`.

### Removed
- Manual location: `location_override.json`, `location_override.example.json`, and the `-Lat`/`-Lon` options.
- `-LocateHours` (replaced by `-LocateMinutes`, default 60, kept in memory only).
- The installer deletes `location_override.json`, `location.json` and `weather.json` left by v1.0.0.

### Added
- `geo.ps1` (location, state lookup, weather code mapping) and `tests/test_geo.ps1` (offline unit tests).

## v1.0.0 - 2026-11-01
- First public release.
