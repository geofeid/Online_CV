$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$dist = Join-Path $root "dist"
$cssDist = Join-Path $dist "css"
$srcHtml = Join-Path $root "src/html"
$srcHtmlCss = Join-Path $srcHtml "css"
$templatePath = Join-Path $root "src/html/index.html"
$contentPath = Join-Path $root "content.env"
$printContentPath = Join-Path $root "content.print.env"
$limitsPath = Join-Path $root "content.limits.env"
$validator = Join-Path $root "scripts/Validate-Content.ps1"
. (Join-Path $root "scripts/CvContent.ps1")

function Invoke-Checked {
  param(
    [scriptblock]$Command,
    [string]$FailureMessage
  )

  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw $FailureMessage
  }
}

function Read-EnvFile {
  param([string]$Path)

  $values = [ordered]@{}
  foreach ($line in [IO.File]::ReadLines($Path, [Text.Encoding]::UTF8)) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
      continue
    }

    $separator = $line.IndexOf("=")
    if ($separator -lt 1) {
      continue
    }

    $key = $line.Substring(0, $separator).Trim()
    $value = $line.Substring($separator + 1)
    $values[$key] = $value
  }

  return $values
}

function Write-EnvFile {
  param(
    [string]$Path,
    [System.Collections.IDictionary]$Values
  )

  $lines = foreach ($key in $Values.Keys) {
    "$key=$($Values[$key])"
  }
  [IO.File]::WriteAllLines($Path, $lines, [Text.UTF8Encoding]::new($false))
}

function Write-TextFileWithRetry {
  param(
    [string]$Path,
    [string]$Content,
    [int]$Retries = 5
  )

  for ($attempt = 1; $attempt -le $Retries; $attempt++) {
    try {
      [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
      return
    } catch [System.IO.IOException] {
      if ($attempt -eq $Retries) {
        throw
      }
      Start-Sleep -Milliseconds 200
    }
  }
}

function Merge-EnvFiles {
  param(
    [string]$BasePath,
    [string]$OverlayPath
  )

  $merged = Read-EnvFile -Path $BasePath
  $overlay = Read-EnvFile -Path $OverlayPath
  foreach ($key in $overlay.Keys) {
    $merged[$key] = $overlay[$key]
  }
  return $merged
}

function ConvertTo-BuiltHtml {
  param(
    [string]$Template,
    [System.Collections.IDictionary]$Values,
    [string]$Stylesheet,
    [string]$BodyClass = "",
    [switch]$FlattenExperienceDescriptions
  )

  $html = $Template.Replace('href="css/main.css"', "href=`"$Stylesheet`"")
  if ($BodyClass.Length -gt 0) {
    $html = $html.Replace("<body>", "<body class=`"$BodyClass`">")
  }

  $experienceItems = Render-ExperienceItems -Values $Values -FlattenDescriptions:$FlattenExperienceDescriptions
  $html = [regex]::Replace(
    $html,
    '(?s)<!-- EXPERIENCE_ITEMS_START -->.*?<!-- EXPERIENCE_ITEMS_END -->',
    "<!-- EXPERIENCE_ITEMS_START -->`n$experienceItems`n            <!-- EXPERIENCE_ITEMS_END -->"
  )

  foreach ($key in $Values.Keys) {
    $html = $html.Replace("{{$key}}", [string]$Values[$key])
  }

  $html = [regex]::Replace($html, '\sdata-short="\{\{[^}]+\}\}"', "")
  $unresolved = [regex]::Matches($html, '\{\{[^}]+\}\}') | ForEach-Object { $_.Value } | Select-Object -Unique
  if ($unresolved.Count -gt 0) {
    throw "Unresolved placeholders: $($unresolved -join ', ')"
  }

  return $html
}

function Add-PreviewLiveReloadScript {
  param([string]$Html)

  $script = @"
<script>
  (function () {
    const reloadUrl = ".preview-reload.txt";
    let lastValue = null;

    async function checkReload() {
      try {
        const response = await fetch(reloadUrl + "?t=" + Date.now(), { cache: "no-store" });
        const value = (await response.text()).trim();
        if (lastValue === null) {
          lastValue = value;
          return;
        }
        if (value && value !== lastValue) {
          window.location.reload();
        }
      } catch (error) {
      }
    }

    checkReload();
    setInterval(checkReload, 1000);
  })();
</script>
"@

  return $Html.Replace("</body>", "$script`n</body>")
}

Write-Output "Cleaning dist/..."
if (Test-Path -LiteralPath $dist) {
  Remove-Item -LiteralPath $dist -Recurse -Force
}
New-Item -ItemType Directory -Path $cssDist | Out-Null
New-Item -ItemType Directory -Path $srcHtmlCss -Force | Out-Null

Write-Output "Validating content..."
Invoke-Checked -Command { & $validator -ContentPath $contentPath -LimitsPath $limitsPath } -FailureMessage "Online content validation failed"

$printValues = Merge-EnvFiles -BasePath $contentPath -OverlayPath $printContentPath
$tmpPrintContent = Join-Path ([IO.Path]::GetTempPath()) ("online-cv-print-content-" + [Guid]::NewGuid() + ".env")
try {
  Write-EnvFile -Path $tmpPrintContent -Values $printValues
  Invoke-Checked -Command { & $validator -ContentPath $tmpPrintContent -LimitsPath $limitsPath } -FailureMessage "Print content validation failed"
}
finally {
  if (Test-Path -LiteralPath $tmpPrintContent) {
    Remove-Item -LiteralPath $tmpPrintContent -Force
  }
}

Write-Output "Compiling SCSS..."
Invoke-Checked -Command { & sass "src/scss/main.scss" "dist/css/main.css" } -FailureMessage "Failed to compile main.scss"
Invoke-Checked -Command { & sass "src/scss/print.scss" "dist/css/print.css" } -FailureMessage "Failed to compile print.scss"

Write-Output "Building HTML..."
$template = [IO.File]::ReadAllText($templatePath, [Text.Encoding]::UTF8)
$onlineValues = Read-EnvFile -Path $contentPath
$onlineHtml = ConvertTo-BuiltHtml -Template $template -Values $onlineValues -Stylesheet "css/main.css"
$printHtml = ConvertTo-BuiltHtml -Template $template -Values $printValues -Stylesheet "css/print.css" -BodyClass "print-page" -FlattenExperienceDescriptions
$previewHtml = Add-PreviewLiveReloadScript -Html $onlineHtml

Write-TextFileWithRetry -Path (Join-Path $dist "index.html") -Content $onlineHtml
Write-TextFileWithRetry -Path (Join-Path $dist "print.html") -Content $printHtml
Write-TextFileWithRetry -Path (Join-Path $srcHtml "preview.html") -Content $previewHtml
Write-TextFileWithRetry -Path (Join-Path $srcHtml ".preview-reload.txt") -Content ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString())
Copy-Item -LiteralPath (Join-Path $cssDist "main.css") -Destination (Join-Path $srcHtmlCss "main.css") -Force

Write-Output "Copying assets..."
Get-ChildItem -LiteralPath (Join-Path $root "src/html") -File |
  Where-Object { $_.Extension -match '^\.(jpg|jpeg|png|gif|svg|ico|webp)$' } |
  Copy-Item -Destination $dist -Force

Write-Output "Done. Preview dist/index.html or dist/print.html"
