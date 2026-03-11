# Pipescreen

Local screenpipe setup and interactive launcher. Part of a larger project to build a personal life timeline that captures both on-screen and off-screen activities.

## What is this?

[Screenpipe](https://github.com/screenpipe/screenpipe) records your screen and audio locally, extracts text via OCR, transcribes speech, and provides a REST API to search through everything. This repo contains scripts to install, configure, and run screenpipe with an interactive menu.

## Quick start (Windows)

Double-click `pipescreen.bat`. You'll see:

```
  ========================================
           PIPESCREEN
    Screen + Life Timeline Recorder
  ========================================

  Status: [STOPPED]

  [1] Start recording
  [2] Stop recording
  [3] Search screen history
  [4] View data info
  [5] Settings
  [6] Install / update screenpipe
  [q] Quit
```

First time? Press `6` to install, then `5` to pick a data folder (so your C: drive doesn't fill up), then `1` to start.

### Quick start mode

```
pipescreen.bat --quick
```

Skips the menu and starts recording immediately. Good for startup scripts.

## macOS / Linux

```bash
chmod +x pipescreen.sh
./pipescreen.sh
```

> **Note:** macOS/Linux support is provided via `pipescreen.sh` but has not been tested yet. Screenpipe itself supports macOS and Linux.

## Files

| File | Platform | Purpose |
|------|----------|---------|
| `pipescreen.bat` | Windows | Interactive launcher (double-click to use) |
| `pipescreen.sh` | macOS/Linux | Interactive launcher |
| `setup-screenpipe.ps1` | Windows | Auto-install screenpipe (PowerShell) |
| `build-screenpipe-source.ps1` | Windows | Build screenpipe from source |

## Configuration

Settings are saved to `~/.pipescreen.conf.bat` (Windows) or `~/.pipescreen.conf` (macOS/Linux) and persist across restarts.

- **Data directory** - where screenshots, audio, and the database are stored (default: `~/.screenpipe`)
- **Port** - API port (default: 3030)

## Screenpipe API

Once recording, the API is available at `http://localhost:3030`:

| Endpoint | Description |
|----------|-------------|
| `GET /health` | System status |
| `GET /search?q=keyword&limit=10` | Search screen/audio history |
| `GET /search?content_type=ocr` | Search screen text only |
| `GET /search?content_type=audio` | Search audio transcriptions only |
| `GET /search?app_name=Chrome&start_time=...&end_time=...` | Filter by app and time range |
| `GET /frames/{id}` | Get a captured frame |
| `POST /raw_sql` | Direct SQLite queries |

## Data storage

All data is stored locally in the configured data directory:

```
<data-dir>/
  db.sqlite          # Main database (OCR text, transcriptions, metadata)
  data/
    2026-03-10/       # Screenshots (JPEG) organized by date
    *.mp4             # Audio recordings
```

## License

MIT
