# wowaddons

WoW 포에버(`wowf`, 클라이언트 1.60.x) 애드온 모음.
여러 PC에서 항상 **같은 버전**을 쓰도록 빌드·릴리스·자동 업데이트까지 묶어 두었다.

## 다른 PC에 설치하기: 애드온 도우미

1. **[WowAddonHelper.exe 받기](https://github.com/kent-k/wowaddons/releases/latest/download/WowAddonHelper.exe)** → 실행
   - 처음 실행하면 Windows가 "PC 보호" 경고를 띄운다 (서명 안 된 exe). **추가 정보 → 실행** 을 한 번 누른다.
2. 설치할 애드온을 체크하고 **[선택대로 적용]**.
3. **Windows 시작할 때 자동으로 업데이트** 를 켜 두면, 이후엔 로그인할 때마다 창 없이 최신 버전으로 맞춘다.

- 게임 폴더는 자동으로 찾는다. 못 찾으면 [변경]에서 와우 폴더를 고른다.
- 처음 실행하면 시작 메뉴에 **애드온 도우미** 가 생긴다 (`%LOCALAPPDATA%\wowaddons` 에 설치). 받은 exe 는 지워도 된다.
- 도우미 자신도 새 버전이 나오면 알아서 바뀐다.
- 기록: `%LOCALAPPDATA%\wowaddons\update.log`

## 버전이 맞는지 확인하는 법

게임에 접속하면 채팅창에 각 애드온의 버전이 뜬다. 애드온 도우미에서도 상태를 볼 수 있다.

| 표시 | 뜻 |
|---|---|
| 초록 `1.2.3` / 도우미 `최신` | 릴리스 버전. PC끼리 이 숫자가 같으면 같은 버전 |
| 도우미 `업데이트` | 새 릴리스가 있음 → [선택대로 적용] (자동 업데이트가 켜져 있으면 다음 로그인 때 알아서) |
| 빨강 `빌드 안 됨` | 빌드를 거치지 않은 소스가 깔림 → 도우미로 다시 적용 |

**개발 빌드는 없다.** 모든 PC(개발하는 PC 포함)가 릴리스 버전만 쓰고, 테스트도 릴리스로 한다.
자동 업데이트는 항상 최신 릴리스로 덮어쓴다.

## 수정 → 릴리스 → 설치

```
addons/<이름>/ 수정
   ▼
git commit / push                     GitHub Actions 가 빌드가 깨지지 않았는지 확인
   │  .\tools\release.ps1            다음 버전 태그(v0.2.1 등)를 만들어 푸시
   ▼
GitHub Actions 가 애드온 zip + 목록 + 도우미 exe 를 빌드해 Release 에 올림
   ▼
각 PC: 다음 로그인 때 애드온 도우미가 자동으로 받아 설치
```

- 버전은 git 태그가 기준이다. 사람이 버전 숫자를 파일에 직접 쓰지 않는다.
- 소스의 `@project-version@` 자리에 빌드가 버전을 넣는다 (`.toc` 의 `## Version:`).
- `.\tools\release.ps1 -Bump minor` / `-Bump major` 로 올리는 자리를 고른다.

## 폴더 구조

```
addons/              애드온 하나당 폴더 하나 (폴더 이름 = .toc 이름)
  DungeonNav/        던전 네비: 인던 들어가면 그 던전 지도 + 그 던전 퀘스트 목록 자동 표시 (/던전)
  DNProbe/           던전 안 맵/좌표 기능 진단 (진단용)
  MacroKit/          매크로 공방: 템플릿 골라 빈칸 채우면 매크로 생성 (/매공)
  QoLKit/            편의 모음: 빠른 줍기, 회색 템 판매, 자동 수리, 쿨다운 숫자, 우편 모두 받기, 퀘스트 빠른 진행 (/편의)
installer/
  WowAddonHelper/    애드온 도우미 (C# WinForms, .NET Framework 4.8 → 런타임 설치 불필요)
tools/
  build.ps1          빌드 (-Zip 릴리스 파일, -Helper 도우미 exe) — 보통 GitHub Actions 가 실행
  release.ps1        릴리스 태그 만들기
  casc/              게임 데이터(CASC) 읽기 도구 (지도 그림 추출, DungeonNav Data.lua 생성, check_spells.py 주문 번호 검증)
docs/                개발 문서 (MacroKit.md, MacroKit-spells.txt 주문 번호 검증 결과, QoLKit.md)
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
   `## Title:` / `## Notes:` 는 애드온 도우미 목록에 그대로 나오니 알아보기 쉽게 쓴다.
   진단용 애드온은 `## X-Dev: 1` (도우미에서 기본 체크 안 함, [진단용] 표시).
   `## X-Usage-1:`, `## X-Usage-2:` ... 에 핵심 명령어와 사용법을 한 줄씩 쓴다. 도우미의 **[사용법 ▸]** 창에 그대로 나온다.
   게임을 켜기 전에 읽는 안내이므로 꼭 넣는다.
3. 저장 데이터(SavedVariables) 이름은 `<애드온이름>DB` 로 한다.
4. 애드온 도우미 같은 Windows 프로그램 UI 는 와우 분위기로 만든다 (어두운 바탕, 금테, 금색 제목, 붉은 버튼). 블리자드 이미지/글꼴 파일은 넣지 않고 직접 그린다.

## 참고

- `.toc` 의 `## Interface:` 값은 아직 확인 전이다 (임시로 16001). 게임 안에서 `/dump select(4, GetBuildInfo())` 로 확인해 맞춘다.
- 던전 지도 그림은 게임 데이터 안에 있다 (`interface/worldmap/<던전>/`, 4x3 타일). `tools/casc/extract_map.py` 로 꺼내 볼 수 있다.
