param(
  [switch]$StartServer,
  [int]$Port = 5500
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$build = Join-Path $root "scripts/Build.ps1"
$srcHtml = Join-Path $root "src/html"
$pathsToWatch = @(
  (Join-Path $root "content.env"),
  (Join-Path $root "content.print.env"),
  (Join-Path $root "content.limits.env"),
  (Join-Path $root "src/html/index.html"),
  (Join-Path $root "src/scss")
)

$serverProcess = $null

function Start-PreviewServer {
  param(
    [string]$Directory,
    [int]$PreviewPort
  )

  $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
  if (-not $pythonCmd) {
    Write-Output "python was not found in PATH. Preview server was not started."
    return $null
  }

  $args = "-m http.server $PreviewPort --bind 127.0.0.1"
  $process = Start-Process -FilePath $pythonCmd.Source -ArgumentList $args -WorkingDirectory $Directory -PassThru
  Write-Output "Preview server: http://127.0.0.1:$PreviewPort/preview.html"
  return $process
}

function Invoke-PreviewBuild {
  Write-Output ""
  Write-Output "[$(Get-Date -Format 'HH:mm:ss')] Rebuilding preview..."
  & powershell -NoProfile -ExecutionPolicy Bypass -File $build
  if ($LASTEXITCODE -ne 0) {
    Write-Output "[$(Get-Date -Format 'HH:mm:ss')] Build failed. Fix the error above; watcher is still running."
    return
  }
  Write-Output "[$(Get-Date -Format 'HH:mm:ss')] Preview updated: src/html/preview.html"
}

Invoke-PreviewBuild

if ($StartServer) {
  $serverProcess = Start-PreviewServer -Directory $srcHtml -PreviewPort $Port
}

$watchers = New-Object System.Collections.Generic.List[System.IO.FileSystemWatcher]
$lastRun = Get-Date

foreach ($path in $pathsToWatch) {
  if (-not (Test-Path -LiteralPath $path)) {
    continue
  }

  $item = Get-Item -LiteralPath $path
  if ($item.PSIsContainer) {
    $watcher = [IO.FileSystemWatcher]::new($item.FullName)
    $watcher.IncludeSubdirectories = $true
    $watcher.Filter = "*.*"
  } else {
    $watcher = [IO.FileSystemWatcher]::new($item.DirectoryName, $item.Name)
  }

  $watcher.NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite, Size'
  $watcher.EnableRaisingEvents = $true
  $watchers.Add($watcher)

  Register-ObjectEvent -InputObject $watcher -EventName Changed -Action {
    $now = Get-Date
    if (($now - $script:lastRun).TotalMilliseconds -lt 500) {
      return
    }
    $script:lastRun = $now
    Invoke-PreviewBuild
  } | Out-Null

  Register-ObjectEvent -InputObject $watcher -EventName Created -Action {
    $now = Get-Date
    if (($now - $script:lastRun).TotalMilliseconds -lt 500) {
      return
    }
    $script:lastRun = $now
    Invoke-PreviewBuild
  } | Out-Null

  Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action {
    $now = Get-Date
    if (($now - $script:lastRun).TotalMilliseconds -lt 500) {
      return
    }
    $script:lastRun = $now
    Invoke-PreviewBuild
  } | Out-Null
}

Write-Output ""
Write-Output "Watching content/template/style files."
if ($StartServer) {
  Write-Output "Hot reload is active while preview.html is open via the local server URL."
} else {
  Write-Output "Open preview through a local server for auto-refresh, or run with -StartServer."
}
Write-Output "Press Ctrl+C to stop."

try {
  while ($true) {
    Wait-Event -Timeout 1 | Out-Null
  }
}
finally {
  if ($serverProcess -and -not $serverProcess.HasExited) {
    Stop-Process -Id $serverProcess.Id -Force
  }
}
