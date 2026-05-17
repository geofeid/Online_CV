$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $root "scripts/CvContent.ps1")

$values = [ordered]@{
  "EXP1_COMPANY" = "Old Company"
  "EXP1_COMPANY_SHORT" = "Old"
  "EXP1_ROLE" = "Old Role"
  "EXP1_ROLE_SHORT" = "Old Role"
  "EXP1_DATES" = "Jan 2020 - Jan 2021"
  "EXP1_DESC1" = "Old description"
  "EXP2_COMPANY" = "Current Company"
  "EXP2_COMPANY_SHORT" = "Current"
  "EXP2_ROLE" = "Current Role"
  "EXP2_ROLE_SHORT" = "Current Role"
  "EXP2_DATES" = "Jan 2021 - Now"
  "EXP2_DESC1" = "Current description"
  "EXP3_COMPANY" = "Newest Company"
  "EXP3_ROLE" = "Newest Role"
  "EXP3_DATES" = "Future"
  "EXP3_DESC1" = "Newest description"
}

$html = Render-ExperienceItems -Values $values

$newest = $html.IndexOf("Newest Company")
$current = $html.IndexOf("Current Company")
$old = $html.IndexOf("Old Company")

if ($newest -lt 0 -or $current -lt 0 -or $old -lt 0) {
  throw "Expected all experience items to render"
}

if (-not ($newest -lt $current -and $current -lt $old)) {
  throw "Expected experience items to render by descending numeric suffix"
}
