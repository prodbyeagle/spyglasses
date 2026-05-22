# SpyGlasses

A lightweight macOS menu bar app that shows live network throughput at a glance.

SpyGlasses sits in the menu bar and displays current download and upload speed. The popover includes launch-at-login controls, refresh interval settings, and an optional Ookla Speedtest run for ping, download, and upload measurements.

## Features

- Live download and upload speed in the macOS menu bar
- Compact SwiftUI popover
- Adjustable update interval from `0.1s` to `2.0s`
- Launch at login support
- Built-in Speedtest runner using the Ookla `speedtest` CLI
- Native macOS app bundle generation script

## Requirements

- macOS 14 or newer
- Xcode command line tools
- Swift 5.10 or newer
- Optional: Ookla Speedtest CLI for the popover speed test

## Install Speedtest CLI

The app can show live traffic without Speedtest. For manual ping/download/upload tests, install the Ookla `speedtest` executable and make sure it is available at one of these paths:

- `/opt/homebrew/bin/speedtest`
- `/usr/local/bin/speedtest`
- `/usr/bin/speedtest`

## Build

```bash
swift build
```

## Install And Run

```bash
./script/build_install.sh
```

This builds `dist/SpyGlasses.app`, signs it ad-hoc, copies it to `/Applications/SpyGlasses.app`, and opens it.

## Project Structure

```text
Sources/SpyGlasses/
  App/        App entry point and status bar controller
  Models/     Shared model types
  Services/   Network monitor and Speedtest runner
  Support/    Formatting, settings, and launch-at-login helpers
  Views/      SwiftUI popover UI
script/       Build, install, and run script
```

## Notes

SpyGlasses is ad-hoc signed by the install script, but not notarized. macOS may show the usual warning for locally built apps.

## License

MIT
