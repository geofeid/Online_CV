$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$build = Join-Path $root "scripts/Build.ps1"
$preview = Join-Path $root "src/html/preview.html"
$previewCss = Join-Path $root "src/html/css/main.css"

& $build | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "Build failed"
}

if (-not (Test-Path -LiteralPath $preview)) {
  throw "Expected src/html/preview.html to exist"
}

if (-not (Test-Path -LiteralPath $previewCss)) {
  throw "Expected src/html/css/main.css to exist"
}

$html = Get-Content -LiteralPath $preview -Raw
if ($html -match "\{\{") {
  throw "Expected preview.html to contain resolved content, not placeholders"
}

if ($html -notmatch 'href="css/main.css"') {
  throw "Expected preview.html to link local css/main.css"
}
