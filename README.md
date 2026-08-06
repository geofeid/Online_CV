# Online_CV

My CV as a web page. One content source (`content.env`) builds the online page, a true-A4 print page, and the downloadable PDF.

## Build (Node — canonical)

```bash
npm install        # once
npm run build      # dist/index.html + dist/print.html
npm run build:pdf  # same + dist/"Georgios Feidakis CV.pdf" (needs Chrome)
```

The build creates:

- `dist/index.html` from `content.env` — the online CV. Ctrl+P on it prints proper A4.
- `dist/print.html` from `content.env` plus `content.print.env` overrides — compact A4 sheet, source of the PDF.
- `dist/Georgios Feidakis CV.pdf` (with `--pdf`) — generated via headless Chrome, so the Download CV link never goes stale.
- `src/html/preview.html` for live-reload preview.

Content length guardrails live in `content.limits.env`. `DEFAULT_MAX` applies to every property unless a key has its own explicit limit.
Generic numbered limits are supported too: `EXP_DESC1` applies to `EXP1_DESC1`, `EXP2_DESC1`, `EXP3_DESC1`, and so on, unless a specific key overrides it.

Experience items are generated from `EXP{n}_...` properties in descending numeric order. Keep older jobs on lower numbers; add the newest job as the next number, for example `EXP4_...`, and it will render first.

## Preview while editing

```bash
npm run watch   # rebuilds on every save
npm run serve   # http://localhost:5500 (dist)
```

## Test

```bash
npm test
```

## Deploy

Pushing to `main` runs `.github/workflows/deploy.yml`: tests → build + PDF → GitHub Pages (enable Pages → "GitHub Actions" in repo settings once).

To replace the old hand-written site at geofeid.github.io/OnlineCV/ instead, sync the build into that repo and push it:

```bash
./scripts/publish-to-onlinecv.sh
```

## Legacy

`scripts/*.ps1` + `tests/*.Tests.ps1` are the original PowerShell pipeline (Windows). Kept for reference; the Node build above is the maintained path.
