param(
    [string]$SourceUri = 'https://raw.githubusercontent.com/Azure/azure-policy/master/built-in-policies/policySetDefinitions/Security%20Center/MCSBv2.json',
    [string]$OutputPath = 'infra/policies/mcsb-v2-pruned.json'
)

# Fetch latest MCSB definition from GitHub and remove MobileNetwork / Sim specific entries.
$rawJson = (Invoke-WebRequest -Uri $SourceUri -UseBasicParsing).Content
$policySet = $rawJson | ConvertFrom-Json -Depth 100

$removed = @()
$filtered = @()
foreach ($definition in $policySet.properties.policyDefinitions) {
    $id = [string]$definition.policyDefinitionId
    $ref = [string]$definition.policyDefinitionReferenceId
    if ($id -match 'Microsoft\.MobileNetwork' -or $ref -match 'SimGroup') {
        $removed += $ref
        continue
    }
    $filtered += $definition
}

$policySet.properties.policyDefinitions = $filtered
$policySet.properties.displayName = 'Custom MCSB (Core Controls)'
$policySet.properties.description = 'Microsoft cloud security benchmark trimmed to exclude MobileNetwork dependencies.'
if (-not $policySet.properties.metadata) {
    $policySet.properties | Add-Member -MemberType NoteProperty -Name metadata -Value @{}
}
$policySet.properties.metadata.customizedOn = (Get-Date).ToString('s')

$directory = Split-Path -Path $OutputPath -Parent
if ($directory -and -not (Test-Path $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
$policySet | ConvertTo-Json -Depth 100 | Set-Content -Path $OutputPath -Encoding utf8

if ($removed.Count -gt 0) {
    Write-Host "Removed policy references:`n$($removed -join [Environment]::NewLine)"
} else {
    Write-Host 'No MobileNetwork or SimGroup entries were found.'
}
