param(
  [ValidateSet("android-appbundle", "android-apk", "ios")]
  [string]$Target = "android-appbundle",
  [string]$DefineFile = "env/app.production.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $DefineFile)) {
  throw "Define file not found: $DefineFile"
}

switch ($Target) {
  "android-appbundle" {
    flutter build appbundle --release --dart-define-from-file="$DefineFile"
  }
  "android-apk" {
    flutter build apk --release --dart-define-from-file="$DefineFile"
  }
  "ios" {
    flutter build ipa --release --dart-define-from-file="$DefineFile"
  }
}
