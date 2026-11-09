# addons\* 폴더를 게임 AddOns 폴더에 정션으로 연결한다.
# 여기서 고친 소스가 게임에 바로 반영된다. 이미 연결된 것은 건너뛴다.
param(
    [string]$GameAddOns = 'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns'
)
$src = Join-Path $PSScriptRoot '..\addons' | Resolve-Path
foreach ($dir in Get-ChildItem $src -Directory) {
    $link = Join-Path $GameAddOns $dir.Name
    if (Test-Path $link) {
        Write-Host "skip  $($dir.Name) (이미 있음)"
        continue
    }
    New-Item -ItemType Junction -Path $link -Target $dir.FullName | Out-Null
    Write-Host "link  $($dir.Name) -> $($dir.FullName)"
}
