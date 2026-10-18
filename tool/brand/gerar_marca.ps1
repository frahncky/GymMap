# Gera as imagens da marca do GymMap a partir de um único símbolo vetorial
# (tool/brand/gymmap_symbol.svg): pino do mapa, ícone do app e splash.
#
#   pwsh tool/brand/gerar_marca.ps1   (pinos em assets/brand; ícone e splash em tool/brand/out)
#   pwsh tool/brand/gerar_marca.ps1 -SoApp   (só o que fica em assets/brand: pinos e ícones)
#   dart run flutter_launcher_icons
#   dart run flutter_native_splash:create
#
# Usa o Microsoft Edge em modo headless para rasterizar, com fundo
# transparente. Cores da marca: grafite #1B222B (fundo do ícone e do splash).

param([switch]$SoApp)

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
$fontSemiUrl = 'file:///' + ((Join-Path $root 'assets\fonts\PlusJakartaSans-SemiBold.ttf') -replace '\\', '/')
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
@font-face{font-family:Jakarta;font-weight:600;src:url('$fontSemiUrl')}
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

function Symbol([int]$height, [string]$source = $svg) {
  $width = [int]($height * 192 / 256)
  return $source -replace '<svg ', "<svg width=""$width"" height=""$height"" "
}

# Pino do mapa (proporção 192x256, em 2x para telas de alta densidade).
Render $pinDir 'pin' 384 512 (Symbol 512)

# Pinos por lotação: só o anel muda, nas cores do selo de lotação do app
# (GymMapColors.occupancy*), do tom claro ao tom do selo.
$levels = [ordered]@{
  low    = @('#7EDB5A', '#2A8F52')
  medium = @('#5FD6C8', '#13897E')
  high   = @('#FFD27A', '#E09F3E')
  full   = @('#FF8A73', '#CC4A37')
}
foreach ($level in $levels.Keys) {
  $from, $to = $levels[$level]
  $ring = "<linearGradient id=""ring"" x1=""0.15"" y1=""0"" x2=""0.85"" y2=""1"">" +
    "<stop offset=""0"" stop-color=""$from""/><stop offset=""1"" stop-color=""$to""/></linearGradient>"
  $levelSvg = [regex]::Replace($svg, '<linearGradient id="ring"[\s\S]*?</linearGradient>', $ring)
  Render $pinDir "pin_$level" 384 512 (Symbol 512 $levelSvg)
}

# Ícones das comodidades (painel da academia): verde-água da marca com um
# detalhe no laranja da mochila; 96 px para ~24 dp em telas 4x.
$teal = '#13897E'
$orange = '#EC6A2C'
$amenityIcons = [ordered]@{
  weights = @"
<rect x="1.5" y="9" width="2.5" height="6" rx="1" fill="$teal"/>
<rect x="4.5" y="6.5" width="3" height="11" rx="1.2" fill="$teal"/>
<rect x="16.5" y="6.5" width="3" height="11" rx="1.2" fill="$teal"/>
<rect x="20" y="9" width="2.5" height="6" rx="1" fill="$teal"/>
<rect x="7.5" y="11" width="9" height="2" rx="1" fill="$orange"/>
"@
  cardio = @"
<path d="M12 21s-7.6-4.6-9.6-9.3C.9 8.1 3.2 4 7.1 4c2.1 0 3.5 1.1 4.9 2.9C13.4 5.1 14.8 4 16.9 4c3.9 0 6.2 4.1 4.7 7.7C19.6 16.4 12 21 12 21z" fill="$teal"/>
<polyline points="3.5,12 8,12 9.8,9 12.4,15.2 14.4,10.6 15.8,12 20.5,12" fill="none" stroke="#fff" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>
"@
  classes = @"
<g fill="$teal" opacity="0.55">
  <circle cx="5.2" cy="8.6" r="2.1"/><path d="M1 19.5c0-2.8 1.8-4.6 4.2-4.6s4.2 1.8 4.2 4.6z"/>
  <circle cx="18.8" cy="8.6" r="2.1"/><path d="M14.6 19.5c0-2.8 1.8-4.6 4.2-4.6s4.2 1.8 4.2 4.6z"/>
</g>
<circle cx="12" cy="6.8" r="2.7" fill="$teal"/>
<path d="M6.6 20.5c0-3.5 2.4-5.9 5.4-5.9s5.4 2.4 5.4 5.9z" fill="$teal"/>
<circle cx="12" cy="17.6" r="1.1" fill="$orange"/>
"@
  pool = @"
<g fill="none" stroke="$teal" stroke-width="1.9" stroke-linecap="round">
  <path d="M8 13V5.5a2 2 0 0 1 4 0"/><path d="M15 13V5.5a2 2 0 0 1 4 0"/>
  <path d="M8 8h7M8 11h7"/>
  <path d="M2 16.5c1.7 0 1.7-1.3 3.3-1.3s1.7 1.3 3.4 1.3 1.6-1.3 3.3-1.3 1.7 1.3 3.3 1.3 1.7-1.3 3.4-1.3 1.6 1.3 3.3 1.3"/>
</g>
<path d="M2 20.5c1.7 0 1.7-1.3 3.3-1.3s1.7 1.3 3.4 1.3 1.6-1.3 3.3-1.3 1.7 1.3 3.3 1.3 1.7-1.3 3.4-1.3 1.6 1.3 3.3 1.3" fill="none" stroke="$orange" stroke-width="1.9" stroke-linecap="round"/>
"@
}
foreach ($name in $amenityIcons.Keys) {
  $icon = "<svg xmlns=""http://www.w3.org/2000/svg"" viewBox=""0 0 24 24"" width=""96"" height=""96"">$($amenityIcons[$name])</svg>"
  Render $pinDir "amenity_$name" 96 96 $icon
}

if ($SoApp) { return }

# Pino apoiado no mapa dobrado (a composição da marca), em HTML.
function PinOnMap([int]$pinHeight, [int]$mapWidth, [string]$extra = '', [int]$offsetY = 0) {
  $mapHeight = [int]($mapWidth * 0.4)
  $overlap = [int]($mapHeight * 0.6)
  $pin = (Symbol $pinHeight) -replace '<svg ', '<svg style="position:relative;z-index:2" '
  $map = $mapSvg -replace '<svg ', "<svg width=""$mapWidth"" height=""$mapHeight"" style=""margin-top:-$($overlap)px"" "
  return "<div style=""display:flex;flex-direction:column;align-items:center;margin-top:$($offsetY)px"">$pin$map$extra</div>"
}

# Ícone do app: fundo grafite, pino sobre o mapa (iOS e Android antigo).
Render $genDir 'app_icon' 1024 1024 (PinOnMap 560 700 '' -20) '#1B222B'

# Ícone adaptável do Android: a mesma composição dentro da área segura
# (círculo de ~61% que nenhum formato de ícone recorta).
Render $genDir 'app_icon_foreground' 1024 1024 (PinOnMap 470 540 '' -16)

# Splash: pino sobre o mapa e o nome.
Render $genDir 'splash_logo' 1152 1152 (PinOnMap 520 620 '<div class="word">Gym<b>Map</b></div>')

# Splash do Android 12+: o sistema mostra só um círculo (2/3 da imagem) e põe
# o "branding" no rodapé, longe do ícone. Por isso o nome vai dentro da
# própria imagem, logo abaixo do pino com o mapa, tudo dentro do círculo.
$a12Name = '<div class="word" style="font-size:96px;margin-top:14px;letter-spacing:-2px">Gym<b>Map</b></div>'
Render $genDir 'splash_android12' 1152 1152 (PinOnMap 290 380 $a12Name 10)

# Loja (Google Play): ícone 512x512 e imagem de destaque 1024x500.
$storeDir = Join-Path $genDir 'store'
New-Item -ItemType Directory -Force -Path $storeDir | Out-Null
Render $storeDir 'play_icon_512' 512 512 (PinOnMap 280 340 '' -10) '#1B222B'

function FeatureGraphic([string]$tagline) {
  $art = PinOnMap 300 360
  return @"
<div style="width:1024px;height:500px;display:flex;align-items:center;justify-content:center;gap:64px;
  background:radial-gradient(circle at 25% 40%,#2E3A46 0%,#1B222B 70%)">
  <div style="flex:0 0 auto">$art</div>
  <div style="max-width:520px">
    <div class="word" style="margin:0;font-size:104px;letter-spacing:-3px">Gym<b>Map</b></div>
    <div style="font:600 31px Jakarta,'Segoe UI',sans-serif;color:#E8EDF2;line-height:1.25;margin-top:14px">$tagline</div>
  </div>
</div>
"@
}
Render $storeDir 'feature_graphic_pt' 1024 500 (FeatureGraphic 'Academias perto de você, com a lotação em tempo real.')
Render $storeDir 'feature_graphic_en' 1024 500 (FeatureGraphic 'Gyms near you, with live occupancy.')
