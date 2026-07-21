[CmdletBinding()]
param(
  [string]$StudioRoot
)

$ErrorActionPreference = 'Stop'

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
$RendererPath = Join-Path $StudioRoot 'assets\renderer-inject.js'
$InjectorPath = Join-Path $StudioRoot 'scripts\injector.mjs'

foreach ($required in @($RendererPath, $InjectorPath)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Codex Dream Skin file not found: $required"
  }
}

function Replace-RequiredText {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$Old,
    [Parameter(Mandatory = $true)][string]$New,
    [Parameter(Mandatory = $true)][string]$Label
  )
  if (-not $Text.Contains($Old)) {
    throw "Codex Dream Skin compatibility anchor not found: $Label. Update this theme pack before patching a newer Studio build."
  }
  return $Text.Replace($Old, $New)
}

$renderer = [System.IO.File]::ReadAllText($RendererPath).Replace("`r`n", "`n")
$injector = [System.IO.File]::ReadAllText($InjectorPath).Replace("`r`n", "`n")
$rendererReady = $renderer.Contains('data-dream-cartoon-icon') -and
  $renderer.Contains('dream-icons-cartoon') -and $renderer.Contains('copy?.homeTitle')
$sidebarToggleReady = $renderer.Contains('dream-shell-sidebar-optional')
$injectorReady = $injector.Contains('iconStyle: new Set(["native", "cartoon"])') -and
  $injector.Contains('copy.homeTitle')
$injectorSidebarReady = $injector.Contains('dream-shell-sidebar-probe-optional') -and
  $injector.Contains('dream-shell-sidebar-verify-optional')

if ($rendererReady -and $sidebarToggleReady -and $injectorReady -and $injectorSidebarReady) {
  Write-Host 'Codex Dream Skin already supports Pikachu fields and collapsed-sidebar persistence.'
  return
}
if (($renderer.Contains('data-dream-cartoon-icon') -or $renderer.Contains('dream-icons-cartoon')) -and
  -not $rendererReady) {
  throw 'The Studio renderer contains a partial or unknown cartoon-icon implementation; no files were changed.'
}
if (($injector.Contains('iconStyle: new Set') -or $injector.Contains('copy.homeTitle')) -and
  -not $injectorReady) {
  throw 'The Studio injector contains a partial or unknown theme-field implementation; no files were changed.'
}

if (-not $rendererReady) {
  $renderer = Replace-RequiredText $renderer @'
    "dream-task-ambient",
    "dream-task-banner",
    "dream-task-off",
  ];
'@ @'
    "dream-task-ambient",
    "dream-task-banner",
    "dream-task-off",
    "dream-icons-cartoon",
  ];
'@ 'renderer root classes'

  $renderer = Replace-RequiredText $renderer @'
  const HOME_UTILITY_CLASS = "dream-home-utility";
  const installToken = {};
'@ @'
  const HOME_UTILITY_CLASS = "dream-home-utility";
  const CARTOON_ICON_ATTRIBUTE = "data-dream-cartoon-icon";
  const ORIGINAL_HOME_TITLE_ATTRIBUTE = "data-dream-original-home-title";
  const installToken = {};
'@ 'renderer constants'

  $renderer = Replace-RequiredText $renderer @'
    const taskMode = ["auto", "ambient", "banner", "off"].includes(art.taskMode)
      ? art.taskMode
      : "auto";
    const metadataRatio = Number(config?.artMetadata?.ratio);
'@ @'
    const taskMode = ["auto", "ambient", "banner", "off"].includes(art.taskMode)
      ? art.taskMode
      : "auto";
    const iconStyle = config?.icons?.style === "cartoon" ? "cartoon" : "native";
    const homeTitle = typeof config?.copy?.homeTitle === "string"
      ? config.copy.homeTitle.trim().slice(0, 160)
      : "";
    const metadataRatio = Number(config?.artMetadata?.ratio);
'@ 'renderer theme fields'

  $renderer = Replace-RequiredText $renderer @'
      accent: safeAccent,
      initialAspect: Number.isFinite(metadataRatio) && metadataRatio > 0 ? metadataRatio : null,
    };
'@ @'
      accent: safeAccent,
      initialAspect: Number.isFinite(metadataRatio) && metadataRatio > 0 ? metadataRatio : null,
      iconStyle,
      homeTitle,
    };
'@ 'renderer normalized config'

  $renderer = Replace-RequiredText $renderer @'
    document.querySelectorAll(`.${HOME_UTILITY_CLASS}`).forEach((node) => node.classList.remove(HOME_UTILITY_CLASS));
    document.getElementById(STYLE_ID)?.remove();
'@ @'
    document.querySelectorAll(`.${HOME_UTILITY_CLASS}`).forEach((node) => node.classList.remove(HOME_UTILITY_CLASS));
    document.querySelectorAll(`[${CARTOON_ICON_ATTRIBUTE}]`).forEach((node) => {
      node.removeAttribute(CARTOON_ICON_ATTRIBUTE);
    });
    document.querySelectorAll(`[${ORIGINAL_HOME_TITLE_ATTRIBUTE}]`).forEach((node) => {
      node.textContent = node.getAttribute(ORIGINAL_HOME_TITLE_ATTRIBUTE) || "";
      node.removeAttribute(ORIGINAL_HOME_TITLE_ATTRIBUTE);
    });
    document.getElementById(STYLE_ID)?.remove();
'@ 'renderer cleanup'

  $rendererHelpers = @'
  const normalizedText = (node) => (node?.innerText || node?.textContent || "")
    .trim()
    .replace(/\s+/g, " ");

  const decorateCartoonIcons = (aside) => {
    document.querySelectorAll(`[${CARTOON_ICON_ATTRIBUTE}]`).forEach((node) => {
      node.removeAttribute(CARTOON_ICON_ATTRIBUTE);
    });
    if (config.iconStyle !== "cartoon" || !aside) return;

    const controls = [...aside.querySelectorAll("button, a, [role='button']")];
    const findControl = ({ texts = [], aria = [] }) => controls.find((control) => {
      const label = control.getAttribute("aria-label") || "";
      return texts.includes(normalizedText(control)) || aria.some((candidate) => label === candidate);
    });
    const markControlIcon = (key, match) => {
      const control = findControl(match);
      const svg = control?.querySelector("svg");
      const host = svg?.parentElement;
      if (host) host.setAttribute(CARTOON_ICON_ATTRIBUTE, key);
    };

    markControlIcon("new-task", { texts: ["新建任务", "New task"] });
    markControlIcon("pull-request", { texts: ["拉取请求", "Pull requests"] });
    markControlIcon("scheduled", { texts: ["已安排", "Scheduled"] });
    markControlIcon("plugins", { texts: ["插件", "Plugins"] });
    markControlIcon("search", { aria: ["搜索", "Search"] });
    markControlIcon("add-project", { aria: ["添加新项目", "Add new project"] });
    markControlIcon("profile", { aria: ["打开个人资料菜单", "Open profile menu"] });
    markControlIcon("help", { aria: ["打开帮助菜单", "Open help menu"] });

    for (const row of aside.querySelectorAll('[class*="group/folder-row"]')) {
      const svg = row.querySelector("svg");
      if (svg?.parentElement) svg.parentElement.setAttribute(CARTOON_ICON_ATTRIBUTE, "project");
    }
  };

  const decorateHomeCopy = (home) => {
    document.querySelectorAll(`[${ORIGINAL_HOME_TITLE_ATTRIBUTE}]`).forEach((node) => {
      if (home && config.homeTitle && home.contains(node)) return;
      node.textContent = node.getAttribute(ORIGINAL_HOME_TITLE_ATTRIBUTE) || "";
      node.removeAttribute(ORIGINAL_HOME_TITLE_ATTRIBUTE);
    });
    if (!home || !config.homeTitle) return;
    const title = [...home.querySelectorAll("h1, h2")].find((node) => normalizedText(node));
    if (!title) return;
    if (!title.hasAttribute(ORIGINAL_HOME_TITLE_ATTRIBUTE)) {
      title.setAttribute(ORIGINAL_HOME_TITLE_ATTRIBUTE, title.textContent || "");
    }
    if (title.textContent !== config.homeTitle) title.textContent = config.homeTitle;
  };

'@
  $renderer = Replace-RequiredText $renderer '  const ensure = () => {' ($rendererHelpers + '  const ensure = () => {') 'renderer decorators'

  $renderer = Replace-RequiredText $renderer @'
    root.classList.add("codex-dream-skin");
    applyProfile(root);
'@ @'
    root.classList.add("codex-dream-skin");
    root.classList.toggle("dream-icons-cartoon", config.iconStyle === "cartoon");
    applyProfile(root);
'@ 'renderer icon mode'

  $renderer = Replace-RequiredText $renderer @'
    const home = document.querySelector('[role="main"]:has([data-testid="home-icon"])');
    const mainCandidates = [...document.querySelectorAll('[role="main"]')];
'@ @'
    const home = document.querySelector('[role="main"]:has([data-testid="home-icon"])');
    const aside = document.querySelector("aside.app-shell-left-panel");
    decorateCartoonIcons(aside);
    decorateHomeCopy(home);
    const mainCandidates = [...document.querySelectorAll('[role="main"]')];
'@ 'renderer ensure hooks'
}

if (-not $sidebarToggleReady) {
  $renderer = Replace-RequiredText $renderer @'
    const shellMain = document.querySelector("main.main-surface");
    const shellSidebar = document.querySelector("aside.app-shell-left-panel");
    if (!shellMain || !shellSidebar) {
      clearSkinDom();
      return;
    }
'@ @'
    const shellMain = document.querySelector("main.main-surface");
    const shellSidebar = document.querySelector("aside.app-shell-left-panel");
    // dream-shell-sidebar-optional: Codex removes the left panel while it is collapsed.
    if (!shellMain) {
      clearSkinDom();
      return;
    }
'@ 'renderer collapsed-sidebar guard'
}

if (-not $injectorReady) {
  $injector = Replace-RequiredText $injector @'
  taskMode: new Set(["auto", "ambient", "banner", "off"]),
};
'@ @'
  taskMode: new Set(["auto", "ambient", "banner", "off"]),
  iconStyle: new Set(["native", "cartoon"]),
};
'@ 'injector theme choices'

  $injector = Replace-RequiredText $injector @'
  const palette = raw.palette && typeof raw.palette === "object" && !Array.isArray(raw.palette)
    ? raw.palette : {};
  const theme = {
'@ @'
  const palette = raw.palette && typeof raw.palette === "object" && !Array.isArray(raw.palette)
    ? raw.palette : {};
  const icons = raw.icons && typeof raw.icons === "object" && !Array.isArray(raw.icons)
    ? raw.icons : {};
  const copy = raw.copy && typeof raw.copy === "object" && !Array.isArray(raw.copy)
    ? raw.copy : {};
  const theme = {
'@ 'injector raw theme fields'

  $injector = Replace-RequiredText $injector @'
    },
    palette: {},
  };
'@ @'
    },
    palette: {},
    icons: {
      style: normalizedChoice(icons.style, "icons.style", THEME_CHOICES.iconStyle, "native"),
    },
    copy: {
      homeTitle: normalizedText(copy.homeTitle, "copy.homeTitle", null, 160),
    },
  };
'@ 'injector sanitized theme fields'
}

$nodePath = Join-Path $StudioRoot 'runtime\node.exe'
if (-not (Test-Path -LiteralPath $nodePath -PathType Leaf)) {
  $node = Get-Command node -ErrorAction SilentlyContinue
  if (-not $node) { throw 'Node.js 22 or newer is required to validate the Studio compatibility patch.' }
  $nodePath = $node.Source
}

if (-not $injectorSidebarReady) {
  $injector = Replace-RequiredText $injector @'
    return {
      markers,
      codex: location.protocol === 'app:' && markers.shell && markers.sidebar && (markers.composer || markers.main),
    };
'@ @'
    return {
      markers,
      // dream-shell-sidebar-probe-optional: the left panel is absent while collapsed.
      codex: location.protocol === 'app:' && markers.shell && (markers.composer || markers.main),
    };
'@ 'injector collapsed-sidebar probe'

  $injector = Replace-RequiredText $injector @'
      result.stylePresent && result.chromePresent &&
      result.chromePointerEvents === 'none' && Boolean(result.composer) && Boolean(result.sidebar) &&
      (!result.homePresent || (Boolean(result.hero) &&
'@ @'
      result.stylePresent && result.chromePresent &&
      result.chromePointerEvents === 'none' && Boolean(result.composer) &&
      // dream-shell-sidebar-verify-optional: sidebar absence is a valid collapsed state.
      (!result.homePresent || (Boolean(result.hero) &&
'@ 'injector collapsed-sidebar verification'
}
$nodeVersion = (& $nodePath --version).Trim().TrimStart('v')
$nodeMajor = [int]($nodeVersion.Split('.')[0])
if ($nodeMajor -lt 22) { throw "Node.js 22 or newer is required; found $nodeVersion." }

$token = [guid]::NewGuid().ToString('N')
$temporaryRenderer = Join-Path (Split-Path -Parent $RendererPath) "renderer-inject.pika-$token.js"
$temporaryInjector = Join-Path (Split-Path -Parent $InjectorPath) "injector.pika-$token.mjs"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
try {
  [System.IO.File]::WriteAllText($temporaryRenderer, $renderer, $utf8NoBom)
  [System.IO.File]::WriteAllText($temporaryInjector, $injector, $utf8NoBom)
  & $nodePath --check $temporaryRenderer
  if ($LASTEXITCODE -ne 0) { throw 'Patched renderer-inject.js failed syntax validation.' }
  & $nodePath --check $temporaryInjector
  if ($LASTEXITCODE -ne 0) { throw 'Patched injector.mjs failed syntax validation.' }

  foreach ($path in @($RendererPath, $InjectorPath)) {
    $backup = $path + '.chatgpt-pika-theme.compat.backup'
    if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $path -Destination $backup }
  }
  Copy-Item -LiteralPath $temporaryRenderer -Destination $RendererPath -Force
  Copy-Item -LiteralPath $temporaryInjector -Destination $InjectorPath -Force
} finally {
  Remove-Item -LiteralPath $temporaryRenderer, $temporaryInjector -Force -ErrorAction SilentlyContinue
}

Write-Host 'Enabled Pikachu fields and collapsed-sidebar persistence in Codex Dream Skin.'
