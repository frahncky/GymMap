param(
  [Parameter(Mandatory = $true)]
  [string]$BackendPublicBaseUrl,
  [Parameter(Mandatory = $true)]
  [string]$DatabaseUrl,
  [string]$CorsAllowOrigin = "",
  [string]$BackendEnvFile = "backend/.env.production",
  [string]$AppDefineFile = "env/app.production.json",
  [switch]$RunValidation
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BackendEnvFile)) {
  throw "Env file not found: $BackendEnvFile"
}
if (-not (Test-Path $AppDefineFile)) {
  throw "App define file not found: $AppDefineFile"
}

$backendUrl = $BackendPublicBaseUrl.Trim().TrimEnd('/')
if (-not ($backendUrl.StartsWith("https://") -or $backendUrl.StartsWith("http://"))) {
  throw "BackendPublicBaseUrl must start with http:// or https://"
}

$effectiveCors = if ([string]::IsNullOrWhiteSpace($CorsAllowOrigin)) { $backendUrl } else { $CorsAllowOrigin.Trim().TrimEnd('/') }
$webhookUrl = "$backendUrl/v1/webhooks/pix"

$lines = Get-Content -Path $BackendEnvFile -Encoding UTF8
$updated = New-Object System.Collections.Generic.List[string]

$hasDb = $false
$hasCors = $false
$hasWebhook = $false

foreach ($line in $lines) {
  if ($line -match '^\s*DATABASE_URL=') {
    $updated.Add("DATABASE_URL=$DatabaseUrl")
    $hasDb = $true
    continue
  }
  if ($line -match '^\s*CORS_ALLOW_ORIGIN=') {
    $updated.Add("CORS_ALLOW_ORIGIN=$effectiveCors")
    $hasCors = $true
    continue
  }
  if ($line -match '^\s*PIX_MP_NOTIFICATION_URL=') {
    $updated.Add("PIX_MP_NOTIFICATION_URL=$webhookUrl")
    $hasWebhook = $true
    continue
  }
  $updated.Add($line)
}

if (-not $hasDb) { $updated.Add("DATABASE_URL=$DatabaseUrl") }
if (-not $hasCors) { $updated.Add("CORS_ALLOW_ORIGIN=$effectiveCors") }
if (-not $hasWebhook) { $updated.Add("PIX_MP_NOTIFICATION_URL=$webhookUrl") }

Set-Content -Path $BackendEnvFile -Value $updated -Encoding UTF8

$appRaw = Get-Content -Path $AppDefineFile -Raw -Encoding UTF8
$appJson = $appRaw | ConvertFrom-Json
$appJson.PLAN_BACKEND_BASE_URL = $backendUrl
$jsonOut = $appJson | ConvertTo-Json -Depth 8
Set-Content -Path $AppDefineFile -Value $jsonOut -Encoding UTF8

Write-Host "Updated go-live URLs and DB config." -ForegroundColor Green
Write-Host " - DATABASE_URL set"
Write-Host " - CORS_ALLOW_ORIGIN=$effectiveCors"
Write-Host " - PIX_MP_NOTIFICATION_URL=$webhookUrl"
Write-Host " - PLAN_BACKEND_BASE_URL=$backendUrl"

if ($RunValidation) {
  powershell -ExecutionPolicy Bypass -File "backend/scripts/check_go_live_gaps.ps1" -BackendEnvFile $BackendEnvFile -AppDefineFile $AppDefineFile
  powershell -ExecutionPolicy Bypass -File "backend/scripts/validate_production_env.ps1" -EnvFile $BackendEnvFile
}
