# wowaddons

WoW 포에버(`wowf`, 클라이언트 1.60.x) 애드온 모음.
여러 PC에서 항상 **같은 버전**을 쓰도록 빌드·릴리스·자동 업데이트까지 묶어 두었다.

## 새 PC에서 처음 설치 (한 번만)

PowerShell을 열고 아래 한 줄을 붙여 넣는다.

```powershell
iwr https://raw.githubusercontent.com/kent-k/wowaddons/main/tools/update.ps1 -OutFile $env:TEMP\wa.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\wa.ps1 -RegisterTask
```

- 최신 릴리스를 받아 게임 `_forever_\Interface\AddOns` 에 설치한다 (게임 폴더는 자동으로 찾음).
- **Windows 로그인할 때마다 자동으로 새 버전을 확인**하도록 시작프로그램에 등록한다.
- 기록: `%LOCALAPPDATA%\wowaddons\update.log`
- 게임 폴더를 못 찾으면 `-GameAddOns 'X:\...\_forever_\Interface\AddOns'` 를 붙인다.
- 지금 바로 업데이트 (PowerShell): `powershell -ExecutionPolicy Bypass -File $env:LOCALAPPDATA\wowaddons\update.ps1`
- 자동 업데이트 끄기: 위 명령 끝에 `-UnregisterTask`

## 버전이 맞는지 확인하는 법

게임에 접속하면 채팅창에 각 애드온의 버전이 뜬다.

| 표시 | 뜻 |
|---|---|
| 초록 `1.2.3` | 정식 릴리스. PC끼리 이 숫자가 같으면 같은 버전 |
| 주황 `1.2.3-dev.4+abc1234` | 개발 중인 PC에서 직접 빌드한 버전 (릴리스 아님) |
| 빨강 `빌드 안 됨` | 빌드를 거치지 않은 소스가 그대로 깔림 → 업데이트 다시 실행 |

개발 빌드가 깔린 PC는 자동 업데이트가 덮어쓰지 않는다 (작업 중인 것 보호). 릴리스로 되돌리려면 `update.ps1 -Force`.

## 개발 → 빌드 → 릴리스

```
addons/<이름>/ 수정
   │  .\tools\build.ps1 -Install     이 PC 게임에 개발 빌드 설치 → 게임에서 /reload
   ▼
git commit / push                     GitHub Actions 가 빌드가 깨지지 않았는지 확인
   │  .\tools\release.ps1            다음 버전 태그(v0.1.1 등)를 만들어 푸시
   ▼
GitHub Actions 가 zip 을 빌드해 Release 에 올림
   ▼
각 PC: 다음 로그인 때 update.ps1 이 자동으로 받아 설치
```

- 버전은 git 태그가 기준이다. 사람이 버전 숫자를 파일에 직접 쓰지 않는다.
- 소스의 `@project-version@` 자리에 빌드가 버전을 넣는다 (`.toc` 의 `## Version:`).
- `.\tools\release.ps1 -Bump minor` / `-Bump major` 로 올리는 자리를 고른다.

## 폴더 구조

```
addons/              애드온 하나당 폴더 하나 (폴더 이름 = .toc 이름)
  DNProbe/           던전 안 맵/좌표 기능 진단
tools/
  build.ps1          빌드 (버전 새기기, -Install 로컬 설치, -Zip 릴리스 파일)
  release.ps1        릴리스 태그 만들기
  update.ps1         각 PC 설치/자동 업데이트 (이 파일 하나만으로 동작)
  casc/              게임 데이터(CASC) 읽기 도구 (던전 지도 그림 추출 등)
.github/workflows/   GitHub Actions 빌드/릴리스
dist/                빌드 결과 (git 에 안 올림)
```

## 애드온을 만들 때 지킬 것

1. **게임 안 안내를 반드시 넣는다.**
   - 접속하면 한 줄: 애드온 이름, 버전, 도움말 명령어.
   - 슬래시 명령어를 그냥 입력하면(`/dnp`) 사용법과 순서를 보여 준다.
   - 결과는 채팅 로그만이 아니라 읽기 쉬운 창으로 보여 주고, **결과가 무슨 뜻인지, 다음에 뭘 하면 되는지**까지 적는다.
   - 한국어 명령어와 영어 명령어 둘 다 받는다 (`/dnp 검사` = `/dnp check`).
2. `.toc` 에 `## Version: @project-version@` 를 넣고, 접속 메시지에 버전을 보여 준다.
3. 저장 데이터(SavedVariables) 이름은 `<애드온이름>DB` 로 한다.

## 참고

- `.toc` 의 `## Interface:` 값은 아직 확인 전이다 (임시로 16001). 게임 안에서 `/dump select(4, GetBuildInfo())` 로 확인해 맞춘다.
- 던전 지도 그림은 게임 데이터 안에 있다 (`interface/worldmap/<던전>/`, 4x3 타일). `tools/casc/extract_map.py` 로 꺼내 볼 수 있다.
