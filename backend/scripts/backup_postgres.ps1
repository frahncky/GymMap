param(
  [string]$DatabaseUrl = $env:DATABASE_URL,
  [string]$OutputDir = "backend/backups",
  [int]$RetentionDays = 14
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($DatabaseUrl)) {
  throw "DATABASE_URL is required (parameter or environment)."
}

if (-not (Get-Command pg_dump -ErrorAction SilentlyContinue)) {
  throw "pg_dump not found in PATH."
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = Join-Path $OutputDir ("gymmap_{0}.dump" -f $timestamp)

Write-Host "Creating backup: $backupFile"
& pg_dump --format=custom --no-owner --no-acl --file "$backupFile" "$DatabaseUrl"
if ($LASTEXITCODE -ne 0) {
  throw "pg_dump failed with exit code $LASTEXITCODE."
}

$cutoff = (Get-Date).AddDays(-$RetentionDays)
Get-ChildItem -Path $OutputDir -File -Filter "*.dump" |
  Where-Object { $_.LastWriteTime -lt $cutoff } |
  ForEach-Object {
    Write-Host "Removing expired backup: $($_.FullName)"
    Remove-Item $_.FullName -Force
  }

Write-Host "Backup completed successfully."
