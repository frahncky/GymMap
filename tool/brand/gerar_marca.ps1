# Gera as imagens da marca do GymMap a partir de um único símbolo vetorial
# (tool/brand/gymmap_symbol.svg): pino do mapa, ícone do app e splash.
#
#   pwsh tool/brand/gerar_marca.ps1   (pino em assets/brand; ícone e splash em tool/brand/out)
#   dart run flutter_launcher_icons
#   dart run flutter_native_splash:create
#
# Usa o Microsoft Edge em modo headless para rasterizar, com fundo
# transparente. Cores da marca: grafite #1B222B (fundo do ícone e do splash).

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$symbol = Join-Path $PSScriptRoot 'gymmap_symbol.svg'
$pinDir = Join-Path $root 'assets\brand'
$genDir = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force -Path $pinDir, $genDir | Out-Null

$edge = @(
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge não encontrado.' }

$svg = Get-Content $symbol -Raw
# Mesma fonte do app (Plus Jakarta Sans) no nome do splash.
$fontUrl = 'file:///' + ((Join-Path $root 'assets\fonts\PlusJakartaSans-ExtraBold.ttf') -replace '\\', '/')
$mapSvg = Get-Content (Join-Path $PSScriptRoot 'folded_map.svg') -Raw
$work = Join-Path ([IO.Path]::GetTempPath()) 'gymmap-brand'
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Render([string]$dir, [string]$name, [int]$width, [int]$height, [string]$body, [string]$background = 'transparent') {
  $html = @"
<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;width:${width}px;height:${height}px;overflow:hidden;background:$background}
body{display:flex;flex-direction:column;align-items:center;justify-content:center}
svg{display:block}
@font-face{font-family:Jakarta;font-weight:800;src:url('$fontUrl')}
.word{font:800 150px Jakarta,'Segoe UI',Roboto,Arial,sans-serif;letter-spacing:-3px;color:#fff;margin-top:40px}
.word b{background:linear-gradient(90deg,#3FC6F0,#22B7A8,#7EDB5A);-webkit-background-clip:text;color:transparent}
</style></head><body>$body</body></html>
"@
  $page = Join-Path $work "$name.html"
  Set-Content -Path $page -Value $html -Encoding UTF8
  $target = Join-Path $dir "$name.png"
  & $edge --headless --disable-gpu --hide-scrollbars --default-background-color=00000000 `
    "--window-size=$width,$height" "--screenshot=$target" "file:///$($page -replace '\\','/')" 2>$null | Out-Null
  Start-Sleep -Milliseconds 300
  if (-not (Test-Path $target)) { throw "Falha ao gerar $name.png" }
  Write-Host "gerado: $target"
}

function Symbol([int]$height) {
  $width = [int]($height * 192 / 256)
  return $svg -replace '<svg ', "<svg width=""$width"" height=""$height"" "
}

# Pino do mapa (proporção 192x256, em 2x para telas de alta densidade).
Render $pinDir 'pin' 384 512 (Symbol 512)

# Ícone do app: fundo grafite com o símbolo (iOS e Android antigo).
Render $genDir 'app_icon' 1024 1024 (Symbol 660) '#1B222B'

# Ícone adaptável do Android: só o símbolo, dentro da área segura (~60%).
Render $genDir 'app_icon_foreground' 1024 1024 (Symbol 560)

# Splash: símbolo + nome.
# O mapa dobrado fica embaixo do pino, como na marca original.
$splashMap = $mapSvg -replace '<svg ', '<svg width="620" height="248" style="margin-top:-150px" '
$splashPin = (Symbol 520) -replace '<svg ', '<svg style="position:relative;z-index:2" '
$splashBody = '<div style="display:flex;flex-direction:column;align-items:center">' + $splashPin + $splashMap + '</div><div class="word">Gym<b>Map</b></div>'
Render $genDir 'splash_logo' 1152 1152 $splashBody

# Splash do Android 12+: o ícone é recortado em círculo; só o símbolo.
Render $genDir 'splash_android12' 1152 1152 (Symbol 600)
