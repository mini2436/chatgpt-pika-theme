[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedThemes = @('preset-pikachu-light', 'preset-pikachu-dark')
$expectedIcons = @(
  '新建任务.png', '拉取请求.png', '已安排.png', '插件.png', '文件夹.png',
  '搜索.png', '设置.png', '关于.png', '添加.png'
)

foreach ($themeId in $expectedThemes) {
  $themeDir = Join-Path (Join-Path $RepoRoot 'themes') $themeId
  $themePath = Join-Path $themeDir 'theme.json'
  $imagePath = Join-Path $themeDir 'background.png'
  if (-not (Test-Path -LiteralPath $themePath -PathType Leaf)) { throw "Missing $themePath" }
  if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) { throw "Missing $imagePath" }
  $theme = Get-Content -LiteralPath $themePath -Raw | ConvertFrom-Json
  if ($theme.schemaVersion -ne 1 -or $theme.id -cne $themeId -or $theme.image -cne 'background.png') {
    throw "Invalid theme identity: $themePath"
  }
  if ($theme.icons.style -cne 'cartoon') { throw "Cartoon icon mode is missing: $themePath" }
  if (-not $theme.copy.homeTitle) { throw "Home title is missing: $themePath" }
  if ((Get-Item -LiteralPath $imagePath).Length -gt 16MB) { throw "Theme image is too large: $imagePath" }
}

foreach ($icon in $expectedIcons) {
  $iconPath = Join-Path (Join-Path $RepoRoot 'icons') $icon
  if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) { throw "Missing $iconPath" }
  $bytes = [System.IO.File]::ReadAllBytes($iconPath)
  if ($bytes.Length -lt 8 -or $bytes[0] -ne 0x89 -or $bytes[1] -ne 0x50 -or
      $bytes[2] -ne 0x4E -or $bytes[3] -ne 0x47) {
    throw "Icon is not a PNG file: $iconPath"
  }
}

foreach ($script in @('install.ps1', 'uninstall.ps1', 'enable-studio-compat.ps1')) {
  $path = Join-Path $PSScriptRoot $script
  $tokens = $null
  $errors = $null
  $null = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
  if ($errors.Count -gt 0) { throw "$script has PowerShell syntax errors: $($errors -join '; ')" }
}

$installer = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'install.ps1') -Raw
foreach ($requiredInstallerToken in @(
  '--pika-cartoon-icon-size',
  'CodexDreamSkin\engine',
  'enable-studio-compat.ps1',
  'powershell.exe'
)) {
  if (-not $installer.Contains($requiredInstallerToken)) {
    throw "Installer compatibility token is missing from install.ps1: $requiredInstallerToken"
  }
}
foreach ($requiredDarkToken in @(
  '--color-token-foreground',
  '--color-token-input-placeholder-foreground',
  '--color-token-dropdown-background'
)) {
  if (-not $installer.Contains($requiredDarkToken)) {
    throw "Dark-mode compatibility token is missing from install.ps1: $requiredDarkToken"
  }
}

Write-Host 'PASS: two themes, nine PNG icons, adaptive sizing, compatibility patching, and PowerShell scripts are valid.'
