# ScreenDown

Turn off your display. Let your Mac shut itself down.

ScreenDown is a lightweight macOS menu bar app that automatically shuts down your Mac after all connected displays have been offline for a configurable period.

## Features

- Automatic shutdown after displays disconnect, with a customizable timeout.
- Countdown cancellation when a display reconnects.
- Pause and resume monitoring from the menu bar.
- Menu bar indicators for active, paused, and unavailable states.
- Launch at login.
- Persistent event logs with a built-in viewer.
- English and Simplified Chinese, following your macOS language preferences.

## Getting started

Requires macOS 13 or later and Apple Command Line Tools to build.

```sh
./build.sh
```

Move `build/ScreenDown.app` to your Applications folder and open it. Choose **Install / Update Helper…** and approve the administrator prompt, then set your preferred timeout from the menu bar.

To remove the background service, choose **Uninstall Helper…** before deleting the app.

## Notes

Display power detection depends on your monitor and connection: switching a display off must make it appear disconnected to macOS. Unplugging a display also starts the countdown.

Shutdown may discard unsaved work. Pause monitoring when you want your Mac to keep running without a display.
