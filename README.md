# Online_CV

My CV as a web page with workflows.

## Build

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Build.ps1
```

```bash
./scripts/build.sh
```

The build creates:

- `dist/index.html` from `content.env`
- `dist/print.html` from `content.env` plus `content.print.env` overrides
- `src/html/preview.html` for local browser preview with resolved content and local CSS

Content length guardrails live in `content.limits.env`. `DEFAULT_MAX` applies to every property unless a key has its own explicit limit.
Generic numbered limits are supported too: `EXP_DESC1` applies to `EXP1_DESC1`, `EXP2_DESC1`, `EXP3_DESC1`, and so on, unless a specific key overrides it.

Experience items are generated from `EXP{n}_...` properties in descending numeric order. Keep older jobs on lower numbers; add the newest job as the next number, for example `EXP3_...`, and it will render first.

## Preview While Editing

Run this once:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Watch-Preview.ps1 -StartServer
```

```bash
./scripts/watch-preview.sh
```

Then open `http://127.0.0.1:5500/preview.html` in the browser. Every save to `content.env`, `content.print.env`, `content.limits.env`, `src/html/index.html`, or `src/scss/*` rebuilds the preview automatically and refreshes the page.

## Test

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\Validate-Content.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\Render-Experience.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\Build-Preview.Tests.ps1
```

```bash
./scripts/test.sh
```
