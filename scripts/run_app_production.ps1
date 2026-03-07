param(
  [string]$DefineFile = "env/app.production.json",
  [string]$DeviceId = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $DefineFile)) {
  throw "Define file not found: $DefineFile"
}

$args = @("run", "--release", "--dart-define-from-file=$DefineFile")
if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
  $args += @("-d", $DeviceId)
}

flutter @args
