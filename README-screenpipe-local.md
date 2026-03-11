# Screenpipe Local Setup (Windows)

## 1) Install and start (recommended)

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-screenpipe.ps1
```

What this script does:
- Uses local `screenpipe` binary if already installed.
- Otherwise uses `npx --yes screenpipe@latest`.
- If `npx` is missing, tries to install Node.js LTS via `winget`.
- Starts recording and waits for `http://localhost:3030/health`.

## 2) Install/runtime checks only (do not start recording)

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-screenpipe.ps1 -NoStart
```

## 3) Skip install steps and only use existing runtime

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-screenpipe.ps1 -SkipInstall
```

## 4) API quick test

```powershell
Invoke-RestMethod "http://localhost:3030/health"
Invoke-RestMethod "http://localhost:3030/search?limit=5"
```

## 5) Source build (optional)

```powershell
powershell -ExecutionPolicy Bypass -File .\build-screenpipe-source.ps1 -InstallDeps
```

Dry run only:

```powershell
powershell -ExecutionPolicy Bypass -File .\build-screenpipe-source.ps1 -DryRun
```

## 6) If something fails

- Run foreground command to see logs:
  - `screenpipe record`
  - or `npx --yes screenpipe@latest record`
- Do not expose port `3030` directly to the public internet without auth.
