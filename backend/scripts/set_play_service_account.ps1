param(
  [Parameter(Mandatory = $true)]
  [string]$ServiceAccountJsonPath,
  [string]$EnvFile = "backend/.env.production",
  [string]$PackageName = "",
  [switch]$RunValidation
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ServiceAccountJsonPath)) {
  throw "Service account JSON file not found: $ServiceAccountJsonPath"
}
if (-not (Test-Path $EnvFile)) {
  throw "Env file not found: $EnvFile"
}

$jsonRaw = Get-Content -Path $ServiceAccountJsonPath -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($jsonRaw)) {
  throw "Service account JSON file is empty."
}

try {
  $null = $jsonRaw | ConvertFrom-Json
} catch {
  throw "Invalid JSON in service account file."
}

$base64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($jsonRaw))

$lines = Get-Content -Path $EnvFile -Encoding UTF8
$updated = New-Object System.Collections.Generic.List[string]

$hasBase64 = $false
$hasPackage = $false

foreach ($line in $lines) {
  if ($line -match '^\s*PLAY_SERVICE_ACCOUNT_JSON_BASE64=') {
    $updated.Add("PLAY_SERVICE_ACCOUNT_JSON_BASE64=$base64")
    $hasBase64 = $true
    continue
  }
  if ($PackageName -and $line -match '^\s*PLAY_PACKAGE_NAME=') {
    $updated.Add("PLAY_PACKAGE_NAME=$PackageName")
    $hasPackage = $true
    continue
  }
  $updated.Add($line)
}

if (-not $hasBase64) {
  $updated.Add("PLAY_SERVICE_ACCOUNT_JSON_BASE64=$base64")
}
if ($PackageName -and -not $hasPackage) {
  $updated.Add("PLAY_PACKAGE_NAME=$PackageName")
}

Set-Content -Path $EnvFile -Value $updated -Encoding UTF8

$preview = if ($base64.Length -gt 24) { $base64.Substring(0, 24) + "..." } else { $base64 }
Write-Host "PLAY_SERVICE_ACCOUNT_JSON_BASE64 updated in $EnvFile" -ForegroundColor Green
Write-Host "Base64 preview: $preview"

if ($RunValidation) {
  powershell -ExecutionPolicy Bypass -File "backend/scripts/validate_production_env.ps1" -EnvFile $EnvFile
}
