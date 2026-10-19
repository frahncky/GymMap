param(
  [string]$EnvFile = "backend/.env.production",
  [string]$DefineFile = "env/app.production.json",
  [ValidateSet("android-appbundle", "android-apk", "ios")]
  [string]$Target = "android-appbundle",
  [switch]$SkipBuild,
  [switch]$SkipOnlineChecks
)

$ErrorActionPreference = "Stop"

Write-Host "==> Running static analysis..."
flutter analyze lib test
if ($LASTEXITCODE -ne 0) {
  throw "flutter analyze failed."
}

Write-Host "==> Running tests..."
flutter test
if ($LASTEXITCODE -ne 0) {
  throw "flutter test failed."
}

Push-Location (Join-Path $PSScriptRoot '../backend')
try {
  dart analyze
  if ($LASTEXITCODE -ne 0) { throw 'Backend analysis failed.' }
  dart test
  if ($LASTEXITCODE -ne 0) { throw 'Backend tests failed.' }
} finally { Pop-Location }

if (Test-Path $EnvFile) {
  Write-Host "==> Validating backend production environment..."
  & "backend/scripts/validate_production_env.ps1" -EnvFile $EnvFile
  if ($LASTEXITCODE -ne 0) {
    throw "Production env validation failed."
  }
} else {
  throw "Backend production env file not found: $EnvFile"
}

if ($SkipOnlineChecks) {
  Write-Warning 'Online checks explicitly skipped. This run does not confirm readiness to publish.'
} else {
  & "$PSScriptRoot/check_production_api.ps1" -DefineFile $DefineFile
}

if ($SkipBuild) {
  Write-Host "==> SkipBuild enabled. Release build was skipped."
  exit 0
}

if (-not (Test-Path $DefineFile)) {
  throw "Define file not found: $DefineFile"
}

Write-Host "==> Building release artifact ($Target)..."
& "scripts/build_app_production.ps1" -Target $Target -DefineFile $DefineFile
if ($LASTEXITCODE -ne 0) {
  throw "Release build failed."
}

Write-Host "Release gate passed successfully." -ForegroundColor Green
