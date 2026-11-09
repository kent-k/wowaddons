# 애드온 빌드: addons\* 를 dist\ 로 복사하면서 버전을 새겨 넣는다.
#
#   .\tools\build.ps1             빌드만 (dist\addons\)
#   .\tools\build.ps1 -Install    빌드 후 이 PC 게임에 설치 (개발 중 확인용)
#   .\tools\build.ps1 -Zip        릴리스용 zip 생성 (GitHub Actions 가 사용)
#
# 버전 규칙 (git 기준, 소스의 @project-version@ 자리에 들어간다)
#   태그 v1.2.3 위에서 깨끗하게 빌드  ->  1.2.3            (릴리스)
#   태그 이후 커밋 / 수정 중         ->  1.2.3-dev.4+abc1234(.dirty)  (개발 빌드)
param(
    [switch]$Install,
    [switch]$Zip,
    [string]$Version,
    [string]$GameAddOns
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dist = Join-Path $root 'dist'
$out = Join-Path $dist 'addons'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Get-GitVersion {
    Push-Location $root
    try {
        $desc = (& git describe --tags --match 'v[0-9]*' --long --dirty --always 2>$null)
    } finally { Pop-Location }
    if (-not $desc) { return '0.0.0-dev' }
    if ($desc -match '^v(\d+\.\d+\.\d+)-(\d+)-g([0-9a-f]+)(-dirty)?$') {
        $base, $ahead, $sha, $dirty = $Matches[1], [int]$Matches[2], $Matches[3], $Matches[4]
        if ($ahead -eq 0 -and -not $dirty) { return $base }
        $v = "$base-dev.$ahead+$sha"
        if ($dirty) { $v += '.dirty' }
        return $v
    }
    # 태그가 아직 없음: 커밋 해시만
    $sha = $desc -replace '-dirty$', ''
    $v = "0.0.0-dev+$sha"
    if ($desc -like '*-dirty') { $v += '.dirty' }
    return $v
}

if (-not $Version) { $Version = Get-GitVersion }
$isDev = $Version -like '*-dev*'

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null

$names = @()
foreach ($dir in Get-ChildItem (Join-Path $root 'addons') -Directory) {
    $toc = Join-Path $dir.FullName "$($dir.Name).toc"
    if (-not (Test-Path $toc)) { throw "$($dir.Name): $($dir.Name).toc 가 없습니다 (폴더 이름 = toc 이름)" }
    $dest = Join-Path $out $dir.Name
    Copy-Item $dir.FullName $dest -Recurse
    foreach ($f in Get-ChildItem $dest -Recurse -File -Include *.toc, *.lua, *.xml) {
        $text = [IO.File]::ReadAllText($f.FullName)
        if ($text.Contains('@project-version@')) {
            [IO.File]::WriteAllText($f.FullName, $text.Replace('@project-version@', $Version), $utf8)
        }
    }
    $names += $dir.Name
}

# 설치된 애드온 목록과 버전: update.ps1 이 이것으로 관리 대상/새 버전 여부를 판단한다
$manifest = [ordered]@{ version = $Version; dev = $isDev; addons = $names; built = (Get-Date).ToString('s') }
[IO.File]::WriteAllText((Join-Path $out 'wowaddons-manifest.json'), ($manifest | ConvertTo-Json), $utf8)
Copy-Item (Join-Path $PSScriptRoot 'update.ps1') (Join-Path $out 'wowaddons-update.ps1')

Write-Host "빌드 완료: $Version  ($($names -join ', '))"

if ($Zip) {
    $zipPath = Join-Path $dist "wowaddons-$Version.zip"
    Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zipPath
    Write-Host "zip: $zipPath"
}

if ($Install) {
    $updateArgs = @{ FromFolder = $out; Force = $true }
    if ($GameAddOns) { $updateArgs.GameAddOns = $GameAddOns }
    & (Join-Path $PSScriptRoot 'update.ps1') @updateArgs
}
