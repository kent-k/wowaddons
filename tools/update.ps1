# wowaddons 업데이트/설치 스크립트 (혼자 동작한다 — 저장소 없이 이 파일만 있어도 됨)
#
#   update.ps1                 GitHub 최신 릴리스를 받아 설치 (이미 최신이면 아무것도 안 함)
#   update.ps1 -RegisterTask   위 작업을 Windows 로그인 때마다 자동 실행하도록 등록
#   update.ps1 -UnregisterTask 자동 실행 해제
#   update.ps1 -Force          버전이 같거나 개발 빌드가 깔려 있어도 덮어씀
#   update.ps1 -GameAddOns <경로>  게임 AddOns 폴더 지정 (한 번 지정하면 기억함)
#
# 새 PC 처음 설치 (PowerShell 에 한 줄 붙여넣기):
#   iwr https://raw.githubusercontent.com/kent-k/wowaddons/main/tools/update.ps1 -OutFile $env:TEMP\wa.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\wa.ps1 -RegisterTask
param(
    [string]$GameAddOns,
    [string]$FromFolder,   # build.ps1 -Install 이 로컬 빌드 결과를 넘길 때
    [switch]$Force,
    [switch]$RegisterTask,
    [switch]$UnregisterTask,
    [switch]$Quiet
)
$ErrorActionPreference = 'Stop'
$Repo = 'kent-k/wowaddons'
$Home_ = Join-Path $env:LOCALAPPDATA 'wowaddons'
$ConfigPath = Join-Path $Home_ 'config.json'
$LogPath = Join-Path $Home_ 'update.log'
$StartupLink = Join-Path ([Environment]::GetFolderPath('Startup')) 'wowaddons 업데이트.lnk'
$ManifestName = 'wowaddons-manifest.json'
$utf8 = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force $Home_ | Out-Null

function Log([string]$msg) {
    $line = '{0}  {1}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $msg
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
    if (-not $Quiet) { Write-Host $msg }
}

function Read-Json($path) {
    if (Test-Path $path) { return [IO.File]::ReadAllText($path) | ConvertFrom-Json }
    return $null
}

function Find-GameAddOns {
    if ($GameAddOns) { return $GameAddOns }
    $cfg = Read-Json $ConfigPath
    if ($cfg -and $cfg.gameAddOns -and (Test-Path $cfg.gameAddOns)) { return $cfg.gameAddOns }
    $roots = @('C:\Program Files (x86)\World of Warcraft')
    foreach ($key in 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft',
                     'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft') {
        try {
            $p = (Get-ItemProperty $key -ErrorAction Stop).InstallPath
            if ($p) { $roots += (Split-Path ($p.TrimEnd('\')) -Parent) }
        } catch {}
    }
    foreach ($d in Get-PSDrive -PSProvider FileSystem) {
        foreach ($sub in 'World of Warcraft', 'Games\World of Warcraft', 'Program Files (x86)\World of Warcraft', 'Game\World of Warcraft') {
            $roots += (Join-Path $d.Root $sub)
        }
    }
    foreach ($r in $roots | Select-Object -Unique) {
        $forever = Join-Path $r '_forever_'
        if (Test-Path $forever) { return (Join-Path $forever 'Interface\AddOns') }
    }
    throw "WoW 포에버 설치 폴더(_forever_)를 못 찾았습니다. -GameAddOns 'X:\...\_forever_\Interface\AddOns' 로 지정해 주세요."
}

function Remove-Addon([string]$path) {
    if (-not (Test-Path $path)) { return }
    $item = Get-Item $path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $item.Delete()   # 정션/링크는 링크만 지운다 (원본 보존)
    } else {
        Remove-Item $path -Recurse -Force
    }
}

function Install-From([string]$src, [string]$target) {
    $new = Read-Json (Join-Path $src $ManifestName)
    if (-not $new) { throw "설치 원본에 $ManifestName 이 없습니다: $src" }
    $old = Read-Json (Join-Path $target $ManifestName)
    New-Item -ItemType Directory -Force $target | Out-Null

    # 예전 버전에 있던 애드온 + 새로 깔 애드온을 지우고 새로 복사 (빠진 애드온도 정리된다)
    $toRemove = @()
    if ($old) { $toRemove += $old.addons }
    $toRemove += $new.addons
    foreach ($name in $toRemove | Select-Object -Unique) { Remove-Addon (Join-Path $target $name) }
    foreach ($name in $new.addons) { Copy-Item (Join-Path $src $name) (Join-Path $target $name) -Recurse }
    Copy-Item (Join-Path $src $ManifestName) (Join-Path $target $ManifestName) -Force

    # 자동 실행용 업데이트 스크립트도 최신으로 교체
    $selfNew = Join-Path $src 'wowaddons-update.ps1'
    if (Test-Path $selfNew) { Copy-Item $selfNew (Join-Path $Home_ 'update.ps1') -Force }

    $from = if ($old) { $old.version } else { '(없음)' }
    Log ("설치 완료: {0} -> {1}  [{2}]" -f $from, $new.version, ($new.addons -join ', '))
    if (Get-Process -Name 'Wow' -ErrorAction SilentlyContinue) {
        Log '게임이 실행 중입니다. 게임에서 /reload 하세요 (새 애드온이 추가됐다면 게임 재시작).'
    }
}

# --- 자동 실행 등록/해제 (시작프로그램 바로가기, 관리자 권한 불필요) ---
if ($UnregisterTask) {
    if (Test-Path $StartupLink) { Remove-Item $StartupLink -Force }
    Log '로그인 시 자동 업데이트를 해제했습니다.'
    return
}
if ($RegisterTask) {
    $installed = Join-Path $Home_ 'update.ps1'
    if ($PSCommandPath -ne $installed) { Copy-Item $PSCommandPath $installed -Force }
    $sh = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut($StartupLink)
    $lnk.TargetPath = (Get-Command powershell.exe).Source
    $lnk.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installed`" -Quiet"
    $lnk.WorkingDirectory = $Home_
    $lnk.Save()
    Log "로그인 시 자동 업데이트를 등록했습니다. (기록: $LogPath)"
}

try {
    $target = Find-GameAddOns
    [IO.File]::WriteAllText($ConfigPath, (@{ gameAddOns = $target } | ConvertTo-Json), $utf8)

    if ($FromFolder) {
        Install-From $FromFolder $target
        return
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $headers = @{ 'User-Agent' = 'wowaddons-updater' }
    try {
        $rel = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" -Headers $headers
    } catch {
        Log "릴리스를 가져오지 못했습니다 (아직 릴리스가 없거나 인터넷 문제): $($_.Exception.Message)"
        return
    }
    $asset = $rel.assets | Where-Object { $_.name -like 'wowaddons-*.zip' } | Select-Object -First 1
    if (-not $asset) { Log "릴리스 $($rel.tag_name) 에 zip 파일이 없습니다."; return }
    $latest = $rel.tag_name.TrimStart('v')

    $installed = Read-Json (Join-Path $target $ManifestName)
    if ($installed -and -not $Force) {
        if ($installed.dev) {
            Log "개발 빌드($($installed.version))가 깔린 PC라 건너뜁니다. 릴리스로 덮으려면 -Force."
            return
        }
        if ($installed.version -eq $latest) { Log "이미 최신입니다: $latest"; return }
    }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("wowaddons-" + [guid]::NewGuid())
    New-Item -ItemType Directory $tmp | Out-Null
    try {
        $zip = Join-Path $tmp $asset.name
        Invoke-WebRequest $asset.browser_download_url -OutFile $zip -Headers $headers -UseBasicParsing
        $ex = Join-Path $tmp 'x'
        Expand-Archive $zip -DestinationPath $ex
        Install-From $ex $target
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {
    Log "실패: $($_.Exception.Message)"
    if (-not $Quiet) { throw }
}
