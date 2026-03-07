param(
  [string]$EnvFile = "backend/.env.production",
  [string]$DefineFile = "env/app.production.json",
  [ValidateSet("android-appbundle", "android-apk", "ios")]
  [string]$Target = "android-appbundle",
  [switch]$SkipBuild
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

if (Test-Path $EnvFile) {
  Write-Host "==> Validating backend production environment..."
  & "backend/scripts/validate_production_env.ps1" -EnvFile $EnvFile
  if ($LASTEXITCODE -ne 0) {
    throw "Production env validation failed."
  }
} else {
  Write-Host "Warning: backend env file not found ($EnvFile). Skipping backend validation." -ForegroundColor Yellow
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
