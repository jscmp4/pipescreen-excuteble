# Pipescreen

A one-click launcher for [screenpipe](https://github.com/screenpipe/screenpipe). Double-click to start recording your screen and audio locally.

**This is not screenpipe itself.** This repo just wraps screenpipe with an interactive menu so you can install, configure, and run it without touching the terminal. All the actual recording, OCR, and transcription is done by [screenpipe](https://github.com/screenpipe/screenpipe).

## Quick start (Windows)

1. Double-click `pipescreen.bat`
2. Press `6` to install screenpipe (first time only)
3. Press `5` to pick a data folder (recommended: put it on a non-C: drive)
4. Press `1` to start recording

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

For auto-start (e.g. startup script): `pipescreen.bat --quick`

## macOS / Linux

```bash
chmod +x pipescreen.sh
./pipescreen.sh
```

> macOS/Linux support via `pipescreen.sh` is untested. Screenpipe itself supports macOS and Linux.

## What's in this repo

| File | Platform | What it does |
|------|----------|-------------- |
| `pipescreen.bat` | Windows | Interactive launcher (double-click) |
| `pipescreen.sh` | macOS/Linux | Interactive launcher |
| `setup-screenpipe.ps1` | Windows | Auto-install helper (PowerShell) |
| `build-screenpipe-source.ps1` | Windows | Build from source (optional) |

## What's NOT in this repo

- Screenpipe itself -- see [screenpipe/screenpipe](https://github.com/screenpipe/screenpipe)
- Screenpipe docs -- see [docs.screenpi.pe](https://docs.screenpi.pe)
- Your recorded data -- stored locally in the data folder you pick

## Configuration

Settings are saved to `~/.pipescreen.conf.bat` (Windows) or `~/.pipescreen.conf` (macOS/Linux) and persist across restarts:

- **Data directory** - where screenshots, audio, and the SQLite database go (default: `~/.screenpipe`)
- **Port** - API port (default: 3030)

## Screenpipe API (quick reference)

Once recording, screenpipe's API runs at `http://localhost:3030`. Full docs: [docs.screenpi.pe](https://docs.screenpi.pe)

| Endpoint | Description |
|----------|-------------|
| `GET /health` | System status |
| `GET /search?q=keyword&limit=10` | Search screen/audio history |
| `GET /search?content_type=ocr` | Screen text only |
| `GET /search?content_type=audio` | Audio transcriptions only |
| `GET /search?app_name=Chrome&start_time=...&end_time=...` | Filter by app and time |
| `GET /frames/{id}` | Get a captured screenshot |
| `POST /raw_sql` | Direct SQLite queries |

## License

MIT
