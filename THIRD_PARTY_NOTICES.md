# Third-party notices

## Zstandard (libzstd.dll)
- Bundled file: `libzstd.dll`, unmodified, from the official Zstandard **v1.5.7** Windows 64-bit release
  (https://github.com/facebook/zstd/releases/tag/v1.5.7).
- SHA-256: `8f07e1112ed283e5cd2798833e9a3c32d8961381bc36da04af57a1b0ca9bd40b`
- Copyright (c) Meta Platforms, Inc. and affiliates. All rights reserved.
- Zstandard is dual-licensed under BSD or GPLv2. This project uses it under the **BSD license**;
  the full text is in [`THIRD_PARTY_LICENSE-zstd-BSD.txt`](THIRD_PARTY_LICENSE-zstd-BSD.txt).
- If you prefer not to use the bundled copy, delete it and drop in `dll\libzstd.dll` from the same
  official release zip (verify the hash above).

## Services used at runtime (no code bundled)
- Open-Meteo (https://open-meteo.com) - weather, keyless, CC BY 4.0 data. "Weather data by Open-Meteo.com".
- ipwho.is - approximate city-level location from public IP (only if no override / Windows location).
- BigDataCloud reverse-geocode-client - US state lookup for state observances (only if needed).

## Trademarks
Divoom and MiniToo are trademarks of their owners. Grok is a trademark of its owner. This project is
unofficial and not affiliated with or endorsed by Divoom or the Grok Bot team.
