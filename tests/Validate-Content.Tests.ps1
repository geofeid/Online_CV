$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$validator = Join-Path $root "scripts/Validate-Content.ps1"
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("online-cv-content-test-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null

try {
  $content = Join-Path $tmp "content.env"
  $limits = Join-Path $tmp "content.limits.env"
  $tooLong = Join-Path $tmp "content-too-long.env"
  $failLog = Join-Path $tmp "fail.log"

  Set-Content -LiteralPath $content -Encoding utf8 -Value @(
    "NAME=Georgios Feidakis",
    "ABOUT=Short enough",
    "HTML_TEXT=Awarded as Most <b>Helpful</b>"
  )

  Set-Content -LiteralPath $limits -Encoding utf8 -Value @(
    "DEFAULT_MAX=30",
    "NAME=20",
    "ABOUT=20",
    "HTML_TEXT=23",
    "MISSING_KEY=1"
  )

  & $validator -ContentPath $content -LimitsPath $limits | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Expected valid content to pass"
  }

  Set-Content -LiteralPath $tooLong -Encoding utf8 -Value @(
    "NAME=Georgios Feidakis",
    "ABOUT=This content is intentionally too long"
  )

  & $validator -ContentPath $tooLong -LimitsPath $limits *> $failLog
  if ($LASTEXITCODE -eq 0) {
    throw "Expected validator to fail when content exceeds the limit"
  }

  $failure = Get-Content -LiteralPath $failLog -Raw
  if ($failure -notmatch "ABOUT is 38 chars; max is 20") {
    throw "Expected ABOUT length failure, got: $failure"
  }

  $defaultLimited = Join-Path $tmp "content-default-too-long.env"
  Set-Content -LiteralPath $defaultLimited -Encoding utf8 -Value @(
    "UNLISTED_KEY=This unlisted value should still be checked"
  )

  & $validator -ContentPath $defaultLimited -LimitsPath $limits *> $failLog
  if ($LASTEXITCODE -eq 0) {
    throw "Expected validator to fail by DEFAULT_MAX"
  }

  $defaultFailure = Get-Content -LiteralPath $failLog -Raw
  if ($defaultFailure -notmatch "UNLISTED_KEY is 43 chars; max is 30") {
    throw "Expected DEFAULT_MAX failure, got: $defaultFailure"
  }
}
finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force
}
