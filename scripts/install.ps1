[CmdletBinding()]
param(
  [ValidateSet('light', 'dark', 'none')]
  [string]$Apply = 'light',
  [string]$StudioRoot = (Join-Path $env:LOCALAPPDATA 'CodexDreamSkinStudio'),
  [switch]$NoRestart
)

$ErrorActionPreference = 'Stop'
$RepoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$StudioRoot = [System.IO.Path]::GetFullPath($StudioRoot)
$StateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$ThemesRoot = Join-Path $StateRoot 'themes'
$CssPath = Join-Path $StudioRoot 'assets\dream-skin.css'
$RendererPath = Join-Path $StudioRoot 'assets\renderer-inject.js'
$CommonScript = Join-Path $StudioRoot 'scripts\common-windows.ps1'
$ThemeScript = Join-Path $StudioRoot 'scripts\theme-windows.ps1'
$StartScript = Join-Path $StudioRoot 'scripts\start-dream-skin.ps1'
$MarkerStart = '/* chatgpt-pika-theme:start */'
$MarkerEnd = '/* chatgpt-pika-theme:end */'

foreach ($required in @($CssPath, $RendererPath, $CommonScript, $ThemeScript, $StartScript)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Codex Dream Skin Studio file not found: $required"
  }
}

$renderer = [System.IO.File]::ReadAllText($RendererPath)
$css = [System.IO.File]::ReadAllText($CssPath)
if ($renderer -notmatch 'data-dream-cartoon-icon' -or $css -notmatch 'dream-icons-cartoon') {
  throw 'This Dream Skin Studio build does not support theme-owned cartoon icons. Update the Studio before installing this pack.'
}

New-Item -ItemType Directory -Force -Path $ThemesRoot | Out-Null
foreach ($themeId in @('preset-pikachu-light', 'preset-pikachu-dark')) {
  $source = Join-Path $RepoRoot "themes\$themeId"
  $destination = Join-Path $ThemesRoot $themeId
  if (-not (Test-Path -LiteralPath (Join-Path $source 'theme.json')) -or
      -not (Test-Path -LiteralPath (Join-Path $source 'background.png'))) {
    throw "Theme package is incomplete: $source"
  }
  New-Item -ItemType Directory -Force -Path $destination | Out-Null
  Copy-Item -LiteralPath (Join-Path $source 'theme.json') -Destination $destination -Force
  Copy-Item -LiteralPath (Join-Path $source 'background.png') -Destination $destination -Force
}

$iconMap = [ordered]@{
  'new-task' = '新建任务.png'
  'pull-request' = '拉取请求.png'
  'scheduled' = '已安排.png'
  'plugins' = '插件.png'
  'project' = '文件夹.png'
  'search' = '搜索.png'
  'profile' = '设置.png'
  'help' = '关于.png'
  'add-project' = '添加.png'
}

$rules = New-Object System.Collections.Generic.List[string]
$rules.Add($MarkerStart)
$rules.Add('html.codex-dream-skin.dream-icons-cartoon [data-dream-cartoon-icon] > svg { display: none !important; }')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon [data-dream-cartoon-icon]::before { content: ""; display: inline-grid; width: 40px; height: 40px; flex: 0 0 40px; }')
$rules.Add('html.codex-dream-skin.dream-theme-dark {')
$rules.Add('  --color-token-foreground: var(--dream-text) !important;')
$rules.Add('  --color-token-text-primary: var(--dream-text) !important;')
$rules.Add('  --color-token-text-secondary: color-mix(in oklab, var(--dream-text) 78%, transparent) !important;')
$rules.Add('  --color-token-text-tertiary: var(--dream-text-muted) !important;')
$rules.Add('  --color-token-description-foreground: var(--dream-text-muted) !important;')
$rules.Add('  --color-token-disabled-foreground: color-mix(in oklab, var(--dream-text-muted) 72%, transparent) !important;')
$rules.Add('  --color-token-icon-foreground: var(--dream-text) !important;')
$rules.Add('  --color-token-dropdown-foreground: var(--dream-text) !important;')
$rules.Add('  --color-token-input-foreground: var(--dream-text) !important;')
$rules.Add('  --color-token-input-placeholder-foreground: var(--dream-text-muted) !important;')
$rules.Add('  --color-token-editor-foreground: var(--dream-text) !important;')
$rules.Add('  --color-token-terminal-foreground: var(--dream-text) !important;')
$rules.Add('  --color-token-text-preformat-foreground: var(--dream-text) !important;')
$rules.Add('  --color-token-checkbox-foreground: var(--dream-text) !important;')
$rules.Add('  --color-token-radio-active-foreground: var(--dream-text) !important;')
$rules.Add('  --color-token-list-active-selection-foreground: var(--dream-text) !important;')
$rules.Add('  --color-token-list-active-selection-icon-foreground: var(--dream-text) !important;')
$rules.Add('  --color-token-menubar-selection-foreground: var(--dream-text) !important;')
$rules.Add('  --color-token-dropdown-background: var(--dream-surface-raised) !important;')
$rules.Add('  --color-token-input-background: var(--dream-immersive-composer) !important;')
$rules.Add('  --color-token-main-surface-primary: var(--dream-surface) !important;')
$rules.Add('  --color-token-text-code-block-background: var(--dream-surface-raised) !important;')
$rules.Add('  --color-token-text-preformat-background: var(--dream-surface-raised) !important;')
$rules.Add('}')
foreach ($entry in $iconMap.GetEnumerator()) {
  $iconPath = Join-Path (Join-Path $RepoRoot 'icons') $entry.Value
  if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
    throw "Icon file not found: $iconPath"
  }
  $base64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($iconPath))
  $rules.Add("html.codex-dream-skin.dream-icons-cartoon [data-dream-cartoon-icon=`"$($entry.Key)`"]::before { content: `"`"; background: center / contain no-repeat url(`"data:image/png;base64,$base64`"); }")
}
$rules.Add($MarkerEnd)
$iconCss = $rules -join "`r`n"

$markerPattern = '(?s)\r?\n?/\* chatgpt-pika-theme:start \*/.*?/\* chatgpt-pika-theme:end \*/\r?\n?'
$css = [regex]::Replace($css, $markerPattern, "`r`n")
$backupPath = $CssPath + '.chatgpt-pika-theme.backup'
if (-not (Test-Path -LiteralPath $backupPath)) {
  Copy-Item -LiteralPath $CssPath -Destination $backupPath
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($CssPath, $css.TrimEnd() + "`r`n`r`n" + $iconCss + "`r`n", $utf8NoBom)

if ($Apply -ne 'none') {
  . $CommonScript
  . $ThemeScript
  $themeId = if ($Apply -eq 'dark') { 'preset-pikachu-dark' } else { 'preset-pikachu-light' }
  $null = Use-DreamSkinSavedTheme -ThemeDirectory (Join-Path $ThemesRoot $themeId) -StateRoot $StateRoot
}

if (-not $NoRestart) {
  $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($null -ne $pwsh) {
    & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $StartScript
  } else {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $StartScript
  }
  if ($LASTEXITCODE -ne 0) { throw "Dream Skin restart failed with exit code $LASTEXITCODE" }
}

Write-Host 'Installed Pikachu light and dark themes.'
if ($Apply -ne 'none') { Write-Host "Applied theme variant: $Apply" }
