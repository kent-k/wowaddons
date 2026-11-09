# 새 버전 릴리스: 다음 버전 태그를 만들어 푸시한다.
# 태그가 올라가면 GitHub Actions 가 빌드해서 Release 에 zip 을 올리고,
# 각 PC 의 update.ps1 이 그 zip 을 받아 간다.
#
#   .\tools\release.ps1              1.2.3 -> 1.2.4 (patch)
#   .\tools\release.ps1 -Bump minor  1.2.3 -> 1.3.0
#   .\tools\release.ps1 -Bump major  1.2.3 -> 2.0.0
param(
    [ValidateSet('patch', 'minor', 'major')][string]$Bump = 'patch',
    [string]$Message
)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne 'main') { throw "main 브랜치에서만 릴리스합니다 (현재: $branch)" }
if (git status --porcelain) { throw '커밋하지 않은 변경이 있습니다. 먼저 커밋하세요.' }

git fetch --tags --quiet origin
$last = git tag --list 'v[0-9]*' --sort=-v:refname | Select-Object -First 1
if ($last -match '^v(\d+)\.(\d+)\.(\d+)$') {
    $maj, $min, $pat = [int]$Matches[1], [int]$Matches[2], [int]$Matches[3]
    switch ($Bump) {
        'major' { $maj++; $min = 0; $pat = 0 }
        'minor' { $min++; $pat = 0 }
        'patch' { $pat++ }
    }
    $next = "v$maj.$min.$pat"
} else {
    $next = 'v0.1.0'
}
if (-not $Message) { $Message = "릴리스 $next" }

git push origin main
git tag -a $next -m $Message
git push origin $next
Write-Host "$last -> $next 태그를 올렸습니다. GitHub Actions 빌드가 끝나면 각 PC 가 자동으로 받아 갑니다."
Write-Host "진행 상황: https://github.com/kent-k/wowaddons/actions"
