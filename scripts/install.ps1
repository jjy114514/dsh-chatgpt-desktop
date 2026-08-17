# dsh-chatgpt-desktop 一键安装（Windows / PowerShell）
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install.ps1 [-Profile desktop]
param(
    [string]$Profile = "desktop"
)

$ErrorActionPreference = "Stop"

$DshHome   = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE ".dsh" }
$ProfileDir = Join-Path $DshHome "profiles\$Profile"
$PluginDir  = Join-Path $ProfileDir "plugins\dsh-chatgpt-desktop"
$SrcDir     = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (-not (Test-Path $ProfileDir)) {
    Write-Error "未找到 DSH profile 目录：$ProfileDir`n请先安装并运行一次 DSH 桌面端，或用 -Profile 指定正确的 profile 名。"
    exit 1
}

# 1. 拷贝插件本体
New-Item -ItemType Directory -Force -Path (Join-Path $PluginDir "lib") | Out-Null
Copy-Item (Join-Path $SrcDir "package.json") (Join-Path $PluginDir "package.json") -Force
Copy-Item (Join-Path $SrcDir "lib\*")        (Join-Path $PluginDir "lib") -Force
Write-Host "[1/4] 插件文件已复制到 $PluginDir"

# 2. 在 profile 的 package.json 里登记 file: 依赖
$PkgFile = Join-Path $ProfileDir "package.json"
$NodeCandidates = @(
    (Get-Command node -ErrorAction SilentlyContinue).Source,
    (Join-Path $env:APPDATA "DSH Desktop\runtime-commands\private\node-bin\node.cmd")
) | Where-Object { $_ -and (Test-Path $_) }
if (-not $NodeCandidates) {
    Write-Error "找不到可用的 node。请手动编辑 $PkgFile，在 dependencies 中加入：`n  ""dsh-chatgpt-desktop"": ""file:plugins/dsh-chatgpt-desktop"""
    exit 1
}
$Node = $NodeCandidates[0]
$PatchJs = @"
const fs = require('fs');
const file = process.argv[1];
const j = JSON.parse(fs.readFileSync(file, 'utf8'));
j.dependencies = j.dependencies || {};
j.dependencies['dsh-chatgpt-desktop'] = 'file:plugins/dsh-chatgpt-desktop';
fs.writeFileSync(file, JSON.stringify(j, null, 2) + '\n');
console.log('[2/4] package.json 已登记依赖');
"@
& $Node -e $PatchJs $PkgFile

# 3. 追加 cordis.patch.yml 挂载条目
$PatchFile = Join-Path $ProfileDir "cordis.patch.yml"
$Entry = "- insert:`n    - id: chatgpt-desktop-theme`n      name: dsh-chatgpt-desktop"
if ((Test-Path $PatchFile) -and (Select-String -Path $PatchFile -Pattern "dsh-chatgpt-desktop" -Quiet)) {
    Write-Host "[3/4] cordis.patch.yml 已存在挂载条目，跳过"
} else {
    Add-Content -Path $PatchFile -Value "`n$Entry`n" -Encoding UTF8
    Write-Host "[3/4] cordis.patch.yml 已追加挂载条目"
}

# 4. pnpm install 生成依赖链接
$PnpmCandidates = @(
    (Get-Command pnpm -ErrorAction SilentlyContinue).Source,
    (Join-Path $env:APPDATA "DSH Desktop\runtime-commands\bin\pnpm.cmd")
) | Where-Object { $_ -and (Test-Path $_) }
if (-not $PnpmCandidates) {
    Write-Host "[4/4] 未找到 pnpm，请手动在 $ProfileDir 下执行 pnpm install"
} else {
    Push-Location $ProfileDir
    & $PnpmCandidates[0] install --silent
    Pop-Location
    Write-Host "[4/4] 依赖链接完成"
}

Write-Host ""
Write-Host "安装完成！重启 DSH 桌面端即可看到 ChatGPT 风格界面。"
Write-Host "可选：接入第三模型 5.6 Terra（Kimi）请见 README.md「可选：接入 Kimi」一节。"
