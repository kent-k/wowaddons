-- DNProbe: 던전 네비 애드온을 만들기 전에, 이 클라이언트에서
-- (1) 인던 안 좌표를 받을 수 있는지 (2) 던전 지도 그림을 띄울 수 있는지 확인한다.

local ADDON = "DNProbe"
local TAG = "|cff33ff99[DNProbe]|r "
local OK, NG, DIM = "|cff44ff44", "|cffff5555", "|cffaaaaaa"

local function say(msg) print(TAG .. msg) end

-- 빌드 때 .toc 의 Version 이 채워진다. PC 마다 같은 버전인지 비교할 때 본다.
local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local VERSION = getMeta(ADDON, "Version") or "?"
local function versionText()
  if VERSION:find("@project%-version@") then return NG .. "빌드 안 됨(소스 그대로)|r" end
  if VERSION:find("%-dev") then return "|cffffaa00" .. VERSION .. " (개발 빌드)|r" end
  return OK .. VERSION .. "|r"
end

-- 도움말 -------------------------------------------------------------------

local HELP = {
  "|cffffd100사용법|r",
  "  |cffffff00/dnp|r          이 도움말",
  "  |cffffff00/dnp 검사|r     지금 위치에서 맵/좌표 기능 검사 (결과 창이 뜸)",
  "  |cffffff00/dnp 지도|r     죽음의 폐광 지도를 띄워 그림이 나오는지 확인",
  "|cffffd100순서|r",
  "  1) 필드에서 |cffffff00/dnp 검사|r  (비교 기준)",
  "  2) 아무 인던에 들어가서 |cffffff00/dnp 검사|r",
  "  3) |cffffff00/dnp 지도|r 로 지도 그림이 보이는지 확인",
  "  4) |cffffff00/reload|r  →  결과가 파일에 저장됨 (개발자가 읽음)",
}

local function showHelp()
  say("버전 " .. versionText())
  for _, line in ipairs(HELP) do print(TAG .. line) end
end

-- 결과 창 (복사 가능한 글 상자) ------------------------------------------------

local resultFrame
local function getResultFrame()
  if resultFrame then return resultFrame end
  local f = CreateFrame("Frame", "DNProbeResultFrame", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(560, 420)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetFrameStrata("DIALOG")
  tinsert(UISpecialFrames, "DNProbeResultFrame") -- ESC로 닫기

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.title:SetPoint("TOP", 0, -5)
  f.title:SetText("DNProbe 검사 결과  (창은 드래그로 이동, ESC로 닫기)")

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -32)
  scroll:SetPoint("BOTTOMRIGHT", -32, 12)
  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(500)
  edit:SetAutoFocus(false)
  edit:SetScript("OnEscapePressed", function() f:Hide() end)
  scroll:SetScrollChild(edit)
  f.edit = edit

  resultFrame = f
  return f
end

-- 검사 ---------------------------------------------------------------------

local function call(f, ...)
  if not f then return false, "API 없음" end
  return pcall(f, ...)
end

local function probe()
  local lines, raw = {}, {}
  local function add(s) lines[#lines + 1] = s end
  local function rec(k, v) raw[k] = tostring(v) end

  local ver, build, _, iface = GetBuildInfo()
  rec("build", ver .. " (" .. build .. ")"); rec("interface", iface); rec("addonVersion", VERSION)

  local inInstance, instType = IsInInstance()
  local zone = GetRealZoneText() or "?"
  rec("zone", zone); rec("instanceType", instType)
  local _, _, difficulty, _, _, _, _, instanceMapID = GetInstanceInfo()
  rec("instanceMapID", instanceMapID)

  add("|cffffd100■ 위치|r")
  add(("  %s  —  %s"):format(zone, inInstance and (OK .. "인던 안|r (" .. tostring(instType) .. ")") or (DIM .. "인던 밖 (필드)|r")))
  add(("  게임 빌드 %s, 애드온 버전 번호(Interface) %s"):format(ver, tostring(iface)))
  add("")

  -- 1) 좌표
  add("|cffffd100■ 1. 내 좌표를 받을 수 있나?|r  (실시간 위치 화살표에 필요)")
  local mapID = C_Map and C_Map.GetBestMapForUnit("player")
  rec("uiMapID", mapID)
  local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
  local x, y = nil, nil
  if pos then x, y = pos:GetXY() end
  rec("mapPos", x and ("%.4f,%.4f"):format(x, y) or "nil")
  local okUP, ux, uy = call(UnitPosition, "player")
  rec("UnitPosition", okUP and tostring(ux) .. "," .. tostring(uy) or "error")

  if x then
    add(("  %s받을 수 있음|r  →  지도 위 위치 %.1f%%, %.1f%%"):format(OK, x * 100, y * 100))
    if inInstance then add("  " .. OK .. "인던 안에서도 된다! 실시간 네비 화살표를 만들 수 있음.|r") end
  else
    add(("  %s막혀 있음|r  (지도 ID: %s)"):format(NG, tostring(mapID)))
    if inInstance then add("  → 인던 안에서는 위치를 못 받음. 지도 + 보스/동선 표시 방식으로 만든다.") end
  end
  add(("  %s참고: UnitPosition = %s|r"):format(DIM, raw.UnitPosition))
  add("")

  -- 2) 이 지역의 지도 정보
  add("|cffffd100■ 2. 이 지역에 지도 정보가 있나?|r")
  if mapID then
    local info = C_Map.GetMapInfo(mapID)
    rec("mapName", info and info.name); rec("mapType", info and info.mapType)
    add(("  지도 이름: %s  (ID %d, 종류 %s)"):format(info and info.name or "?", mapID, tostring(info and info.mapType)))
    local layers = C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
    rec("artLayers", layers and #layers or "nil")
    local group = C_Map.GetMapGroupID and C_Map.GetMapGroupID(mapID)
    if group then
      local floors = C_Map.GetMapGroupMembersInfo(group) or {}
      rec("floors", #floors)
      add(("  층 수: %d"):format(#floors))
      for _, m in ipairs(floors) do add(("    - %s (ID %d)"):format(tostring(m.name), m.mapID)) end
    else
      add("  층 정보 없음 (한 층짜리이거나 지도가 없음)")
    end
  else
    add("  " .. NG .. "지도 없음|r — 게임이 이 지역의 지도를 모름")
  end
  add("")
  add(DIM .. "다음: |cffffff00/dnp 지도|r" .. DIM .. " 로 지도 그림 확인 → |cffffff00/reload|r" .. DIM .. " 하면 결과가 저장됩니다.|r")

  DNProbeDB = DNProbeDB or {}
  DNProbeDB[#DNProbeDB + 1] = { time = date("%Y-%m-%d %H:%M:%S"), raw = raw }

  local f = getResultFrame()
  f.edit:SetText(table.concat(lines, "\n"))
  f:Show()
  say("검사 완료. 결과 창을 확인하세요. (" .. #DNProbeDB .. "번째 기록)")
end

-- 지도 그림 테스트 (죽음의 폐광 1층, 4x3 타일) ----------------------------------

-- 타일 파일 번호(FileDataID): _1, _10, _11, _12, _2 ... _9 순서로 이어져 있다
local function deadminesTile(n)
  if n == 1 then return 449591 end
  if n >= 10 then return 449592 + (n - 10) end
  return 449595 + (n - 2)
end

local mapFrame
local function showMapTest()
  if not mapFrame then
    local f = CreateFrame("Frame", "DNProbeMapFrame", UIParent, "BasicFrameTemplateWithInset")
    local scale = 0.6
    f:SetSize(1002 * scale + 16, 668 * scale + 36)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    tinsert(UISpecialFrames, "DNProbeMapFrame")
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText("지도 그림 테스트: 죽음의 폐광  (보이면 성공)")
    local size = 256 * scale
    for i = 1, 12 do
      local t = f:CreateTexture(nil, "ARTWORK")
      t:SetSize(size, size)
      t:SetPoint("TOPLEFT", 8 + ((i - 1) % 4) * size, -28 - math.floor((i - 1) / 4) * size)
      t:SetTexture(deadminesTile(i))
    end
    mapFrame = f
  end
  mapFrame:Show()
  say("지도 창을 띄웠습니다. 양피지 지도가 보이면 성공, 검거나 초록색이면 실패입니다.")
  DNProbeDB = DNProbeDB or {}
  DNProbeDB.mapTestShownAt = date("%Y-%m-%d %H:%M:%S")
end

-- 명령어 / 로그인 안내 ----------------------------------------------------------

SLASH_DNPROBE1 = "/dnp"
SLASH_DNPROBE2 = "/dnprobe"
SlashCmdList.DNPROBE = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "검사" or msg == "run" or msg == "check" then
    probe()
  elseif msg == "지도" or msg == "map" then
    showMapTest()
  else
    showHelp()
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  say("버전 " .. versionText() .. " 로드됨. 사용법은 |cffffff00/dnp|r 를 입력하세요.")
end)
