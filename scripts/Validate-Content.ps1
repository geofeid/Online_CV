param(
  [Parameter(Mandatory = $true)]
  [string]$ContentPath,

  [Parameter(Mandatory = $true)]
  [string]$LimitsPath
)

$ErrorActionPreference = "Stop"

function Read-EnvFile {
  param([string]$Path)

  $values = [ordered]@{}
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "File not found: $Path"
  }

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

function Get-VisibleTextLength {
  param([string]$Value)

  $withoutTags = [regex]::Replace($Value, "<[^>]+>", "")
  return ([Globalization.StringInfo]::new($withoutTags)).LengthInTextElements
}

function Get-LimitValue {
  param(
    [System.Collections.IDictionary]$Limits,
    [string]$Key,
    [object]$DefaultMax
  )

  if ($Limits.Contains($Key)) {
    return $Limits[$Key]
  }

  $genericKey = [regex]::Replace($Key, "^(EXP|CERT)\d+_", '$1_')
  if ($Limits.Contains($genericKey)) {
    return $Limits[$genericKey]
  }

  if ($null -ne $DefaultMax) {
    return [string]$DefaultMax
  }

  return $null
}

$content = Read-EnvFile -Path $ContentPath
$limits = Read-EnvFile -Path $LimitsPath
$failures = @()
$defaultMax = $null

if ($limits.Contains("DEFAULT_MAX")) {
  $parsedDefault = 0
  if ([int]::TryParse($limits["DEFAULT_MAX"], [ref]$parsedDefault)) {
    $defaultMax = $parsedDefault
  } else {
    $failures += "DEFAULT_MAX has invalid max length '$($limits["DEFAULT_MAX"])'"
  }
}

foreach ($key in $content.Keys) {
  $maxValue = Get-LimitValue -Limits $limits -Key $key -DefaultMax $defaultMax
  if ($null -eq $maxValue) {
    continue
  }

  $max = 0
  if (-not [int]::TryParse($maxValue, [ref]$max)) {
    $failures += "$key has invalid max length '$maxValue'"
    continue
  }

  $length = Get-VisibleTextLength -Value $content[$key]
  if ($length -gt $max) {
    $failures += "$key is $length chars; max is $max"
  }
}

if ($failures.Count -gt 0) {
  [Console]::Error.WriteLine("Content validation failed for $ContentPath")
  foreach ($failure in $failures) {
    [Console]::Error.WriteLine("  - $failure")
  }
  exit 1
}

Write-Output "Content validation passed for $ContentPath"
exit 0
