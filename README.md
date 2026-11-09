# wowaddons

WoW 포에버(`wowf`, 클라이언트 1.60.x) 애드온 모음.

## 폴더 구조

```
addons/          애드온 하나당 폴더 하나 (폴더 이름 = .toc 이름)
  DNProbe/       던전 안 맵/좌표 API 진단용
tools/
  link-addons.ps1  addons/* 를 게임 AddOns 폴더에 정션으로 연결
  casc/            게임 데이터(CASC) 읽기 도구 (지도 타일 추출 등)
```

## 개발 방법

1. `addons/<이름>/` 에 `<이름>.toc` 와 Lua 파일을 만든다.
2. `powershell -File tools\link-addons.ps1` 로 게임에 연결한다 (한 번만).
3. 게임에서 `/reload` 하면 바뀐 내용이 반영된다.

게임 경로: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns`

## 참고

- `.toc` 의 `## Interface:` 값은 아직 확인 전이다 (임시로 16001). 게임 안에서 `/dump select(4, GetBuildInfo())` 로 확인해 맞춘다.
- 던전 지도 그림은 게임 데이터 안에 있다 (`interface/worldmap/<던전>/`, 4x3 타일). `tools/casc/extract_map.py` 로 꺼내 볼 수 있다.
