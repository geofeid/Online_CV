function Get-NumberedPrefixes {
  param(
    [System.Collections.IDictionary]$Values,
    [string]$Prefix,
    [string]$RequiredSuffix
  )

  $pattern = "^$([regex]::Escape($Prefix))(\d+)_$([regex]::Escape($RequiredSuffix))$"
  $numbers = New-Object System.Collections.Generic.HashSet[int]

  foreach ($key in $Values.Keys) {
    $match = [regex]::Match($key, $pattern)
    if ($match.Success) {
      [void]$numbers.Add([int]$match.Groups[1].Value)
    }
  }

  return $numbers | Sort-Object -Descending | ForEach-Object { "$Prefix$_" }
}

function Get-OptionalAttribute {
  param(
    [System.Collections.IDictionary]$Values,
    [string]$Key,
    [string]$AttributeName
  )

  if (-not $Values.Contains($Key) -or [string]::IsNullOrWhiteSpace([string]$Values[$Key])) {
    return ""
  }

  return " $AttributeName=`"$($Values[$Key])`""
}

function Render-ExperienceItems {
  param(
    [System.Collections.IDictionary]$Values,
    [switch]$FlattenDescriptions
  )

  $html = New-Object System.Collections.Generic.List[string]
  $itemIndex = 0

  foreach ($prefix in Get-NumberedPrefixes -Values $Values -Prefix "EXP" -RequiredSuffix "COMPANY") {
    $itemIndex += 1
    $companyShort = Get-OptionalAttribute -Values $Values -Key "${prefix}_COMPANY_SHORT" -AttributeName "data-short"
    $roleShort = Get-OptionalAttribute -Values $Values -Key "${prefix}_ROLE_SHORT" -AttributeName "data-short"
    $toggleId = "readJob$itemIndex"

    $html.Add(@"
            <div class="timeline">
              <div class="left-tl-content">
                <h5 class="tl-title"$companyShort>$($Values["${prefix}_COMPANY"])</h5>
                <p class="para">$($Values["${prefix}_DATES"])</p>
              </div>
              <div class="right-tl-content">
                <div class="tl-content">
                  <h5 class="tl-title-2 header-space"$roleShort>
                    $($Values["${prefix}_ROLE"])
                  </h5>
                  <input type="checkbox" id="$toggleId" class="read-more-toggle" />
                  <div class="read-more-content">
"@)

    $singleDescriptionKey = "${prefix}_DESC"
    $hasSingleDescription = $Values.Contains($singleDescriptionKey) -and -not [string]::IsNullOrWhiteSpace([string]$Values[$singleDescriptionKey])

    $descriptionKeys = $Values.Keys |
      Where-Object { $_ -match "^$([regex]::Escape($prefix))_DESC(\d+)$" } |
      Sort-Object { [int]([regex]::Match($_, "DESC(\d+)$").Groups[1].Value) }

    if ($hasSingleDescription) {
      $html.Add("                    <p class=`"para`">$($Values[$singleDescriptionKey])</p>")
    } elseif ($FlattenDescriptions) {
      $descriptionText = ($descriptionKeys | ForEach-Object { [string]$Values[$_] }) -join " "
      $html.Add("                    <p class=`"para`">$descriptionText</p>")
    } else {
      for ($i = 0; $i -lt $descriptionKeys.Count; $i++) {
        $className = if ($i -lt $descriptionKeys.Count - 1) { ' class="para exp"' } else { ' class="para"' }
        $html.Add("                    <p$className>$($Values[$descriptionKeys[$i]])</p>")
      }
    }

    $html.Add(@"
                  </div>
                  <label for="$toggleId" class="read-more-label"></label>
                </div>
              </div>
            </div>
"@)
  }

  return ($html -join [Environment]::NewLine)
}
