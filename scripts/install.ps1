[CmdletBinding()]
param(
  [ValidateSet('light', 'dark', 'none')]
  [string]$Apply = 'light',
  [string]$StudioRoot,
  [switch]$NoRestart
)

$ErrorActionPreference = 'Stop'
$RepoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if ([string]::IsNullOrWhiteSpace($StudioRoot)) {
  $candidates = @(
    (Join-Path $env:LOCALAPPDATA 'CodexDreamSkin\engine'),
    (Join-Path $env:LOCALAPPDATA 'CodexDreamSkinStudio')
  )
  $StudioRoot = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
    Select-Object -First 1
  if (-not $StudioRoot) { $StudioRoot = $candidates[0] }
}
$StudioRoot = [System.IO.Path]::GetFullPath($StudioRoot)
$StateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$ThemesRoot = Join-Path $StateRoot 'themes'
$CssPath = Join-Path $StudioRoot 'assets\dream-skin.css'
$RendererPath = Join-Path $StudioRoot 'assets\renderer-inject.js'
$InjectorPath = Join-Path $StudioRoot 'scripts\injector.mjs'
$CommonScript = Join-Path $StudioRoot 'scripts\common-windows.ps1'
$ThemeScript = Join-Path $StudioRoot 'scripts\theme-windows.ps1'
$StartScript = Join-Path $StudioRoot 'scripts\start-dream-skin.ps1'
$MarkerStart = '/* chatgpt-pika-theme:start */'
$MarkerEnd = '/* chatgpt-pika-theme:end */'

foreach ($required in @($CssPath, $RendererPath, $InjectorPath, $CommonScript, $ThemeScript, $StartScript)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Codex Dream Skin Studio file not found: $required"
  }
}

$renderer = [System.IO.File]::ReadAllText($RendererPath)
$injector = [System.IO.File]::ReadAllText($InjectorPath)
$css = [System.IO.File]::ReadAllText($CssPath)
if ($renderer -notmatch 'data-dream-cartoon-icon' -or $renderer -notmatch 'dream-icons-cartoon' -or
    $renderer -notmatch 'dream-shell-sidebar-optional' -or $injector -notmatch 'iconStyle: new Set' -or
    $injector -notmatch 'copy\.homeTitle' -or $injector -notmatch 'dream-shell-sidebar-probe-optional' -or
    $injector -notmatch 'dream-shell-sidebar-verify-optional') {
  & (Join-Path $PSScriptRoot 'enable-studio-compat.ps1') -StudioRoot $StudioRoot
  $renderer = [System.IO.File]::ReadAllText($RendererPath)
  $injector = [System.IO.File]::ReadAllText($InjectorPath)
  if ($renderer -notmatch 'data-dream-cartoon-icon' -or $renderer -notmatch 'dream-icons-cartoon' -or
      $renderer -notmatch 'dream-shell-sidebar-optional' -or $injector -notmatch 'iconStyle: new Set' -or
      $injector -notmatch 'copy\.homeTitle' -or $injector -notmatch 'dream-shell-sidebar-probe-optional' -or
      $injector -notmatch 'dream-shell-sidebar-verify-optional') {
    throw 'Codex Dream Skin compatibility patch completed without exposing the required theme fields and sidebar behavior.'
  }
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
$rules.Add('html.codex-dream-skin.dream-icons-cartoon { --pika-cartoon-icon-size: clamp(28px, var(--height-token-row, 32px), 34px); }')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon [data-dream-cartoon-icon]:not(button):not(a) { width: var(--pika-cartoon-icon-size) !important; height: var(--pika-cartoon-icon-size) !important; flex: 0 0 var(--pika-cartoon-icon-size) !important; }')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon [data-dream-cartoon-icon] > svg { display: none !important; }')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon [data-dream-cartoon-icon]::before { content: ""; display: inline-grid; width: var(--pika-cartoon-icon-size); height: var(--pika-cartoon-icon-size); flex: 0 0 var(--pika-cartoon-icon-size); }')
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
$rules.Add('html.codex-dream-skin.dream-icons-cartoon {')
$rules.Add('  --pika-electric-yellow: oklch(0.88 0.18 96);')
$rules.Add('  --pika-panel-radius: 14px;')
$rules.Add('  --pika-shell-inset: 8px;')
$rules.Add('  --pika-shell-gap: 10px;')
$rules.Add('  --pika-panel-line: color-mix(in oklab, oklch(0.7 0.12 85) 52%, transparent);')
$rules.Add('  --pika-sidebar-panel: color-mix(in oklab, oklch(0.965 0.055 95) 88%, transparent);')
$rules.Add('  --pika-main-panel: color-mix(in oklab, oklch(0.985 0.025 95) 78%, transparent);')
$rules.Add('  --pika-utility-surface: oklch(0.965 0.055 95);')
$rules.Add('  --pika-utility-surface-raised: oklch(0.982 0.035 95);')
$rules.Add('  --pika-utility-row: oklch(0.985 0.028 95);')
$rules.Add('  --pika-utility-row-hover: oklch(0.94 0.075 91);')
$rules.Add('  --pika-utility-line: oklch(0.76 0.11 88);')
$rules.Add('  --pika-utility-text: oklch(0.29 0.055 64);')
$rules.Add('  --pika-utility-text-muted: oklch(0.46 0.065 70);')
$rules.Add('  --pika-utility-accent: oklch(0.54 0.14 78);')
$rules.Add('}')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon.dream-theme-dark {')
$rules.Add('  --pika-panel-line: color-mix(in oklab, var(--pika-electric-yellow) 44%, transparent);')
$rules.Add('  --pika-sidebar-panel: color-mix(in oklab, oklch(0.22 0.055 91) 90%, transparent);')
$rules.Add('  --pika-main-panel: color-mix(in oklab, oklch(0.18 0.035 91) 84%, transparent);')
$rules.Add('  --pika-utility-surface: oklch(0.2 0.04 91);')
$rules.Add('  --pika-utility-surface-raised: oklch(0.24 0.045 91);')
$rules.Add('  --pika-utility-row: oklch(0.26 0.05 91);')
$rules.Add('  --pika-utility-row-hover: oklch(0.31 0.065 91);')
$rules.Add('  --pika-utility-line: oklch(0.62 0.13 92);')
$rules.Add('  --pika-utility-text: oklch(0.93 0.02 95);')
$rules.Add('  --pika-utility-text-muted: oklch(0.74 0.05 90);')
$rules.Add('  --pika-utility-accent: oklch(0.82 0.16 95);')
$rules.Add('}')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon div:has(> aside.app-shell-left-panel + main.main-surface),')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon div:has(> main.main-surface):not(:has(> aside.app-shell-left-panel)) {')
$rules.Add('  gap: var(--pika-shell-gap) !important;')
$rules.Add('  padding: var(--pika-shell-inset) !important;')
$rules.Add('  background: transparent !important;')
$rules.Add('}')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon.dream-art-wide:has(main.main-surface.dream-home-shell) aside.app-shell-left-panel,')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon.dream-art-wide:is(.dream-task-ambient, .dream-task-banner):has(main.main-surface:not(.dream-home-shell)) aside.app-shell-left-panel {')
$rules.Add('  background: var(--pika-sidebar-panel) !important;')
$rules.Add('  border: 1px solid var(--pika-panel-line) !important;')
$rules.Add('  border-radius: var(--pika-panel-radius) !important;')
$rules.Add('  box-shadow: none !important;')
$rules.Add('  overflow: clip !important;')
$rules.Add('  backdrop-filter: none !important;')
$rules.Add('}')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon.dream-art-wide main.main-surface.dream-home-shell,')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon.dream-art-wide:is(.dream-task-ambient, .dream-task-banner) main.main-surface:not(.dream-home-shell) {')
$rules.Add('  background: var(--pika-main-panel) !important;')
$rules.Add('  border: 1px solid var(--pika-panel-line) !important;')
$rules.Add('  border-radius: var(--pika-panel-radius) !important;')
$rules.Add('  box-shadow: none !important;')
$rules.Add('}')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon main.main-surface > header.app-header-tint {')
$rules.Add('  position: absolute !important;')
$rules.Add('  inset: 0 0 auto 0 !important;')
$rules.Add('  width: auto !important;')
$rules.Add('}')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon main.main-surface div[class~="rounded-3xl"][class~="bg-token-dropdown-background"][class~="pt-2.5"],')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon main.main-surface div[class~="absolute"][class~="top-0"][class~="bottom-0"][class~="left-0"][class~="bg-token-main-surface-primary"][class~="border-l"] {')
$rules.Add('  --color-token-foreground: var(--pika-utility-text) !important;')
$rules.Add('  --color-token-text-primary: var(--pika-utility-text) !important;')
$rules.Add('  --color-token-text-secondary: var(--pika-utility-text-muted) !important;')
$rules.Add('  --color-token-text-tertiary: var(--pika-utility-text-muted) !important;')
$rules.Add('  --color-token-text-quaternary: var(--pika-utility-text-muted) !important;')
$rules.Add('  --color-token-description-foreground: var(--pika-utility-text-muted) !important;')
$rules.Add('  --color-token-disabled-foreground: var(--pika-utility-text-muted) !important;')
$rules.Add('  --color-token-icon-foreground: var(--pika-utility-accent) !important;')
$rules.Add('  --color-token-conversation-summary-trailing: var(--pika-utility-text-muted) !important;')
$rules.Add('  --color-token-dropdown-background: var(--pika-utility-surface-raised) !important;')
$rules.Add('  --color-token-main-surface-primary: var(--pika-utility-surface) !important;')
$rules.Add('  --color-token-bg-fog: var(--pika-utility-row) !important;')
$rules.Add('  --color-token-list-hover-background: var(--pika-utility-row-hover) !important;')
$rules.Add('  --color-token-border-default: var(--pika-utility-line) !important;')
$rules.Add('  --color-token-border-heavy: var(--pika-utility-line) !important;')
$rules.Add('  --color-token-border-xstrong: var(--pika-utility-line) !important;')
$rules.Add('  color: var(--pika-utility-text) !important;')
$rules.Add('}')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon main.main-surface div[class~="rounded-3xl"][class~="bg-token-dropdown-background"][class~="pt-2.5"] {')
$rules.Add('  background: var(--pika-utility-surface-raised) !important;')
$rules.Add('  border: 1px solid var(--pika-utility-line) !important;')
$rules.Add('  border-radius: var(--pika-panel-radius) !important;')
$rules.Add('  box-shadow: 0 4px 8px color-mix(in oklab, var(--dream-canvas) 18%, transparent) !important;')
$rules.Add('}')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon main.main-surface div[class~="rounded-3xl"][class~="bg-token-dropdown-background"][class~="pt-2.5"] header {')
$rules.Add('  background: var(--pika-utility-surface-raised) !important;')
$rules.Add('}')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon main.main-surface div[class~="rounded-3xl"][class~="bg-token-dropdown-background"][class~="pt-2.5"] svg,')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon main.main-surface div[class~="absolute"][class~="top-0"][class~="bottom-0"][class~="left-0"][class~="bg-token-main-surface-primary"][class~="border-l"] svg {')
$rules.Add('  color: var(--pika-utility-accent) !important;')
$rules.Add('}')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon main.main-surface div[class~="absolute"][class~="top-0"][class~="bottom-0"][class~="left-0"][class~="bg-token-main-surface-primary"][class~="border-l"] {')
$rules.Add('  background: var(--pika-utility-surface) !important;')
$rules.Add('  border-left: 1px solid var(--pika-utility-line) !important;')
$rules.Add('}')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon main.main-surface div[class~="absolute"][class~="top-0"][class~="bottom-0"][class~="left-0"][class~="bg-token-main-surface-primary"][class~="border-l"] [class~="bg-token-main-surface-primary"] {')
$rules.Add('  background: var(--pika-utility-surface) !important;')
$rules.Add('}')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon main.main-surface div[class~="absolute"][class~="top-0"][class~="bottom-0"][class~="left-0"][class~="bg-token-main-surface-primary"][class~="border-l"] button[class~="bg-token-bg-fog"] {')
$rules.Add('  color: var(--pika-utility-text) !important;')
$rules.Add('  background: var(--pika-utility-row) !important;')
$rules.Add('}')
$rules.Add('html.codex-dream-skin.dream-icons-cartoon main.main-surface div[class~="absolute"][class~="top-0"][class~="bottom-0"][class~="left-0"][class~="bg-token-main-surface-primary"][class~="border-l"] button[class~="bg-token-bg-fog"]:hover {')
$rules.Add('  background: var(--pika-utility-row-hover) !important;')
$rules.Add('}')
$rules.Add('@media (max-width: 900px) {')
$rules.Add('  html.codex-dream-skin.dream-icons-cartoon {')
$rules.Add('    --pika-panel-radius: 12px;')
$rules.Add('    --pika-shell-inset: 6px;')
$rules.Add('    --pika-shell-gap: 6px;')
$rules.Add('  }')
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
  $windowsPowerShell = Get-Command powershell.exe -ErrorAction SilentlyContinue
  if ($null -ne $windowsPowerShell) {
    & $windowsPowerShell.Source -NoProfile -ExecutionPolicy Bypass -File $StartScript
  } else {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $StartScript
  }
  if ($LASTEXITCODE -ne 0) { throw "Dream Skin restart failed with exit code $LASTEXITCODE" }
}

Write-Host 'Installed Pikachu light and dark themes.'
if ($Apply -ne 'none') { Write-Host "Applied theme variant: $Apply" }
