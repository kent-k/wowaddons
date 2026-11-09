# 빌드: addons\* 를 dist\ 로 복사하면서 버전을 새겨 넣는다.
#
#   .\tools\build.ps1             애드온 빌드만 (dist\addons\)
#   .\tools\build.ps1 -Install    빌드 후 이 PC 게임에 개발 빌드로 설치 → 게임에서 /reload
#   .\tools\build.ps1 -Zip        릴리스 파일: 애드온 zip + 목록(json)
#   .\tools\build.ps1 -Helper     애드온 도우미 exe 빌드 (dist\WowAddonHelper.exe)
#
# 버전 규칙 (git 기준, 소스의 @project-version@ 자리에 들어간다)
#   태그 v1.2.3 위에서 깨끗하게 빌드  ->  1.2.3                         (릴리스)
#   태그 이후 커밋 / 수정 중         ->  1.2.3-dev.4+abc1234(.dirty)   (개발 빌드)
#
# .toc 에서 읽는 정보 (애드온 도우미 목록에 표시)
#   ## Title:  이름        ## Notes:  설명        ## X-Dev: 1   개발/진단용 (기본 체크 안 함)
param(
    [switch]$Install,
    [switch]$Zip,
    [switch]$Helper,
    [string]$Version,
    [string]$GameAddOns
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dist = Join-Path $root 'dist'
$out = Join-Path $dist 'addons'
$ManifestName = 'wowaddons-manifest.json'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Get-GitVersion {
    Push-Location $root
    try { $desc = (& git describe --tags --match 'v[0-9]*' --long --dirty --always 2>$null) } finally { Pop-Location }
    if (-not $desc) { return '0.0.0-dev' }
    if ($desc -match '^v(\d+\.\d+\.\d+)-(\d+)-g([0-9a-f]+)(-dirty)?$') {
        $base, $ahead, $sha, $dirty = $Matches[1], [int]$Matches[2], $Matches[3], $Matches[4]
        if ($ahead -eq 0 -and -not $dirty) { return $base }
        $v = "$base-dev.$ahead+$sha"
        if ($dirty) { $v += '.dirty' }
        return $v
    }
    $sha = $desc -replace '-dirty$', ''
    $v = "0.0.0-dev+$sha"
    if ($desc -like '*-dirty') { $v += '.dirty' }
    return $v
}

function Read-TocMeta([string]$tocPath) {
    $meta = @{}
    foreach ($line in [IO.File]::ReadAllLines($tocPath)) {
        if ($line -match '^##\s*([\w-]+)\s*:\s*(.*)$') { $meta[$Matches[1]] = $Matches[2].Trim() }
    }
    return $meta
}

# 와우 색 코드(|cffRRGGBB ... |r) 제거
function Strip-Color([string]$s) { if ($s) { ($s -replace '\|c[0-9a-fA-F]{8}', '' -replace '\|r', '').Trim() } else { '' } }

function Find-GameAddOns {
    if ($GameAddOns) { return $GameAddOns }
    $cfg = Join-Path $env:LOCALAPPDATA 'wowaddons\config.json'
    if (Test-Path $cfg) {
        $p = ([IO.File]::ReadAllText($cfg) | ConvertFrom-Json).gameAddOns
        if ($p) { return $p }
    }
    $default = 'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns'
    if (Test-Path (Split-Path $default)) { return $default }
    throw '게임 AddOns 폴더를 못 찾았습니다. -GameAddOns 로 지정하세요.'
}

if (-not $Version) { $Version = Get-GitVersion }
$isDev = $Version -like '*-dev*'

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null

$addons = @()
foreach ($dir in Get-ChildItem (Join-Path $root 'addons') -Directory) {
    $toc = Join-Path $dir.FullName "$($dir.Name).toc"
    if (-not (Test-Path $toc)) { throw "$($dir.Name): $($dir.Name).toc 가 없습니다 (폴더 이름 = toc 이름)" }
    $meta = Read-TocMeta $toc
    $dest = Join-Path $out $dir.Name
    Copy-Item $dir.FullName $dest -Recurse
    foreach ($f in Get-ChildItem $dest -Recurse -File -Include *.toc, *.lua, *.xml) {
        $text = [IO.File]::ReadAllText($f.FullName)
        if ($text.Contains('@project-version@')) {
            [IO.File]::WriteAllText($f.FullName, $text.Replace('@project-version@', $Version), $utf8)
        }
    }
    $title = Strip-Color $meta['Title']
    $addons += [ordered]@{
        name  = $dir.Name
        title = $(if ($title) { $title } else { $dir.Name })
        notes = Strip-Color $meta['Notes']
        dev   = ($meta['X-Dev'] -in @('1', 'true', 'yes'))
    }
}

# 애드온 목록과 버전: 애드온 도우미가 이것으로 목록/새 버전 여부를 판단한다
$manifest = [ordered]@{ version = $Version; dev = $isDev; addons = $addons; built = (Get-Date).ToString('s') }
$manifestJson = ConvertTo-Json $manifest -Depth 5
[IO.File]::WriteAllText((Join-Path $out $ManifestName), $manifestJson, $utf8)
Write-Host "빌드 완료: $Version  ($(($addons | ForEach-Object { $_.name }) -join ', '))"

if ($Zip) {
    $zipPath = Join-Path $dist "wowaddons-$Version.zip"
    Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zipPath
    Copy-Item (Join-Path $out $ManifestName) (Join-Path $dist $ManifestName)
    Write-Host "zip: $zipPath"
}

if ($Helper) {
    # exe 버전은 숫자만 (개발 빌드는 0.0.0 → 도우미가 자기 업데이트를 하지 않음)
    $numeric = if ($isDev) { '0.0.0' } else { $Version }
    $proj = Join-Path $root 'installer\WowAddonHelper\WowAddonHelper.csproj'
    & dotnet build $proj -c Release -nologo -v q "-p:Version=$numeric" "-p:InformationalVersion=$Version" "-o" (Join-Path $dist 'helper')
    if ($LASTEXITCODE -ne 0) { throw '애드온 도우미 빌드 실패' }
    Copy-Item (Join-Path $dist 'helper\WowAddonHelper.exe') (Join-Path $dist 'WowAddonHelper.exe')
    Write-Host "도우미: $(Join-Path $dist 'WowAddonHelper.exe')"
}

if ($Install) {
    $target = Find-GameAddOns
    New-Item -ItemType Directory -Force $target | Out-Null
    $oldPath = Join-Path $target $ManifestName
    $old = @()
    if (Test-Path $oldPath) {
        $old = @(([IO.File]::ReadAllText($oldPath) | ConvertFrom-Json).addons | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.name } })
    }
    $new = @($addons | ForEach-Object { $_.name })
    foreach ($name in ($old + $new | Select-Object -Unique)) {
        $p = Join-Path $target $name
        if (Test-Path $p) {
            $item = Get-Item $p -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { $item.Delete() } else { Remove-Item $p -Recurse -Force }
        }
    }
    foreach ($name in $new) { Copy-Item (Join-Path $out $name) (Join-Path $target $name) -Recurse }
    $installed = [ordered]@{ version = $Version; dev = $true; addons = $new; installedBy = 'build.ps1'; installed = (Get-Date).ToString('s') }
    [IO.File]::WriteAllText($oldPath, (ConvertTo-Json $installed -Depth 5), $utf8)
    Write-Host "설치 완료 (개발 빌드): $target"
    if (Get-Process -Name 'Wow' -ErrorAction SilentlyContinue) { Write-Host '게임이 실행 중입니다. 게임에서 /reload 하세요.' }
}
