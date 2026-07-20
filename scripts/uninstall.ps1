[CmdletBinding()]
param(
  [string]$StudioRoot = (Join-Path $env:LOCALAPPDATA 'CodexDreamSkinStudio'),
  [switch]$NoRestart
)

$ErrorActionPreference = 'Stop'
$StudioRoot = [System.IO.Path]::GetFullPath($StudioRoot)
$StateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$ThemesRoot = [System.IO.Path]::GetFullPath((Join-Path $StateRoot 'themes'))
$CssPath = Join-Path $StudioRoot 'assets\dream-skin.css'
$StartScript = Join-Path $StudioRoot 'scripts\start-dream-skin.ps1'

foreach ($themeId in @('preset-pikachu-light', 'preset-pikachu-dark')) {
  $target = [System.IO.Path]::GetFullPath((Join-Path $ThemesRoot $themeId))
  if (-not $target.StartsWith($ThemesRoot + [System.IO.Path]::DirectorySeparatorChar,
      [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove a path outside the managed themes directory: $target"
  }
  if (Test-Path -LiteralPath $target -PathType Container) {
    Remove-Item -LiteralPath $target -Recurse -Force
  }
}

if (Test-Path -LiteralPath $CssPath -PathType Leaf) {
  $css = [System.IO.File]::ReadAllText($CssPath)
  $markerPattern = '(?s)\r?\n?/\* chatgpt-pika-theme:start \*/.*?/\* chatgpt-pika-theme:end \*/\r?\n?'
  $updated = [regex]::Replace($css, $markerPattern, "`r`n")
  if ($updated -cne $css) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($CssPath, $updated, $utf8NoBom)
  }
}

if (-not $NoRestart -and (Test-Path -LiteralPath $StartScript -PathType Leaf)) {
  $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($null -ne $pwsh) {
    & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $StartScript
  } else {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $StartScript
  }
  if ($LASTEXITCODE -ne 0) { throw "Dream Skin restart failed with exit code $LASTEXITCODE" }
}

Write-Host 'Removed the saved Pikachu themes and the repository-owned icon CSS block.'
Write-Host 'If a Pikachu theme was active, choose another saved theme from the tray menu.'

