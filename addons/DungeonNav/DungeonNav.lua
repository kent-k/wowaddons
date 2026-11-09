-- 던전 네비 (DungeonNav)
-- 인던에 들어가면 그 던전 지도(게임 데이터의 지도 그림)를 자동으로 띄운다.
-- 인던 안에서 내 좌표를 받을 수 있는 클라이언트라면 내 위치 화살표도 표시한다.

local ADDON, ns = ...
local TAG = "|cffffd100[던전 네비]|r "
local OK, NG, DIM, KEY = "|cff44ff44", "|cffff5555", "|cffaaaaaa", "|cffffff00"

local MAP_W, MAP_H = 1002, 668      -- 지도 그림 중 실제로 보이는 영역 (타일 4x3 = 1024x768 중)
local MIN_W, MAX_W = 320, 1400
local DEFAULTS = { width = 640, alpha = 1, autoOpen = true, lastFloor = {}, welcomed = false }

local db                             -- DungeonNavDB
local current, floorIdx              -- 지금 보여 주는 던전 ID / 층 번호
local autoOpened = false

local function say(msg) print(TAG .. msg) end

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local VERSION = getMeta(ADDON, "Version") or "?"
local function versionText()
  if VERSION:find("@project%-version@") then return NG .. "빌드 안 됨|r" end
  if VERSION:find("%-dev") then return "|cffffaa00" .. VERSION .. " (개발 빌드)|r" end
  return OK .. VERSION .. "|r"
end

-- 지도 창 ------------------------------------------------------------------

local f = CreateFrame("Frame", "DungeonNavFrame", UIParent, "BasicFrameTemplateWithInset")
f:Hide()
f:SetFrameStrata("HIGH")
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local point, _, rel, x, y = self:GetPoint()
  db.point = { point, rel, x, y }
end)
tinsert(UISpecialFrames, "DungeonNavFrame")   -- ESC 로 닫기

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", 0, -5)

-- 지도 그림 (타일 12장)
local canvas = CreateFrame("Frame", nil, f)
canvas:SetPoint("TOPLEFT", 8, -28)
canvas:SetClipsChildren(true)
local tiles = {}
for i = 1, 12 do
  tiles[i] = canvas:CreateTexture(nil, "ARTWORK")
end

local arrow = canvas:CreateTexture(nil, "OVERLAY")
arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
arrow:SetSize(28, 28)
arrow:Hide()

-- 아래 띠: [<] 층 이름 [>]   [목록]          안내
local prevBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
prevBtn:SetSize(28, 22)
prevBtn:SetText("<")
prevBtn:SetPoint("BOTTOMLEFT", 10, 8)

local floorText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
floorText:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
floorText:SetWidth(110)

local nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
nextBtn:SetSize(28, 22)
nextBtn:SetText(">")
nextBtn:SetPoint("LEFT", floorText, "RIGHT", 6, 0)

local listBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
listBtn:SetSize(64, 22)
listBtn:SetText("목록")
listBtn:SetPoint("LEFT", nextBtn, "RIGHT", 10, 0)

local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("BOTTOMRIGHT", -12, 13)
hint:SetJustifyH("RIGHT")

local posText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
posText:SetPoint("BOTTOMRIGHT", hint, "TOPRIGHT", 0, 2)
posText:SetJustifyH("RIGHT")

local function layout()
  local w = math.floor(db.width)
  local h = math.floor(w * MAP_H / MAP_W)
  local tile = w / MAP_W * 256
  canvas:SetSize(w, h)
  for i, t in ipairs(tiles) do
    t:SetSize(tile, tile)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", ((i - 1) % 4) * tile, -math.floor((i - 1) / 4) * tile)
  end
  f:SetSize(w + 16, h + 28 + 40)
  f:SetAlpha(db.alpha)
  hint:SetText(w >= 560 and "휠: 층 바꾸기   Ctrl+휠: 크기   Alt+휠: 투명도" or "휠: 층  Ctrl+휠: 크기")
end

local function showFloor()
  local d = ns.Dungeons[current]
  if not d then return end
  floorIdx = math.max(1, math.min(floorIdx or 1, #d.floors))
  local fl = d.floors[floorIdx]
  for i, t in ipairs(tiles) do t:SetTexture(fl.tiles[i]) end
  f.title:SetText(d.name .. (fl.name ~= "" and ("  -  " .. fl.name) or ""))
  local multi = #d.floors > 1
  floorText:SetText(multi and (fl.name ~= "" and fl.name or (floorIdx .. "층")) .. (" (%d/%d)"):format(floorIdx, #d.floors) or "한 층짜리")
  prevBtn:SetEnabled(multi and floorIdx > 1)
  nextBtn:SetEnabled(multi and floorIdx < #d.floors)
  db.lastFloor[current] = floorIdx
end

local function open(id, floor)
  if not ns.Dungeons[id] then return false end
  current = id
  floorIdx = floor or db.lastFloor[id] or 1
  layout()
  showFloor()
  f:Show()
  return true
end

local function changeFloor(delta)
  local d = ns.Dungeons[current]
  if not d then return end
  floorIdx = math.max(1, math.min(#d.floors, floorIdx + delta))
  showFloor()
end

prevBtn:SetScript("OnClick", function() changeFloor(-1) end)
nextBtn:SetScript("OnClick", function() changeFloor(1) end)

canvas:EnableMouseWheel(true)
canvas:SetScript("OnMouseWheel", function(_, delta)
  if IsControlKeyDown() then
    db.width = math.max(MIN_W, math.min(MAX_W, db.width + delta * 40))
    layout()
  elseif IsAltKeyDown() then
    db.alpha = math.max(0.2, math.min(1, db.alpha + delta * 0.1))
    f:SetAlpha(db.alpha)
  else
    changeFloor(-delta)   -- 휠을 아래로 굴리면 다음 층
  end
end)

-- 내 위치 화살표 (좌표를 받을 수 있을 때만) --------------------------------------

local artFloorCache = {}   -- [uiMapID] = 이 던전의 층 번호 또는 false

-- 게임이 알려 주는 지도(uiMapID)의 그림이 우리 층 그림과 같은지 첫 타일로 맞춰 본다
local function floorForUiMap(uiMapID)
  local key = current .. ":" .. uiMapID
  if artFloorCache[key] ~= nil then return artFloorCache[key] end
  local found = false
  local ok, tex = pcall(C_Map.GetMapArtLayerTextures, uiMapID, 1)
  if ok and type(tex) == "table" and tex[1] then
    for i, fl in ipairs(ns.Dungeons[current].floors) do
      if fl.tiles[1] == tex[1] then found = i break end
    end
  end
  artFloorCache[key] = found
  return found
end

local posState   -- 마지막 안내 상태 (같은 글을 매번 다시 쓰지 않게)
local function setPosState(state, text)
  if posState == state then return end
  posState = state
  posText:SetText(text)
end

local function updateArrow()
  if not (C_Map and C_Map.GetBestMapForUnit and current) then arrow:Hide() return end
  local _, _, _, _, _, _, _, iid = GetInstanceInfo()
  if iid ~= current then
    arrow:Hide()
    setPosState("away", "")
    return
  end
  local uiMapID = C_Map.GetBestMapForUnit("player")
  local pos = uiMapID and C_Map.GetPlayerMapPosition(uiMapID, "player")
  local x, y
  if pos then x, y = pos:GetXY() end
  if not x or (x == 0 and y == 0) then
    arrow:Hide()
    setPosState("blocked", "내 위치: 이 클라이언트는 인던 안 좌표를 주지 않음")
    return
  end
  local fi = floorForUiMap(uiMapID)
  if not fi then
    arrow:Hide()
    setPosState("nomatch", "내 위치: 좌표는 있으나 지도 그림이 달라 표시 안 함")
    return
  end
  if fi ~= floorIdx then floorIdx = fi; showFloor() end   -- 내가 있는 층으로 자동 전환
  local w, h = canvas:GetSize()
  arrow:ClearAllPoints()
  arrow:SetPoint("CENTER", canvas, "TOPLEFT", x * w, -y * h)
  local facing = GetPlayerFacing and GetPlayerFacing()
  if facing then arrow:SetRotation(facing) end
  arrow:Show()
  setPosState("ok", OK .. "내 위치 표시 중|r")
end

local elapsed = 0
f:SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + dt
  if elapsed < 0.1 then return end
  elapsed = 0
  updateArrow()
end)

-- 던전 목록 패널 -------------------------------------------------------------

local list
local function buildList()
  list = CreateFrame("Frame", "DungeonNavListFrame", f, "BasicFrameTemplateWithInset")
  list:SetPoint("TOPLEFT", f, "TOPRIGHT", -2, 0)
  list:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", -2, 0)
  list:SetWidth(190)
  list:Hide()
  local t = list:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  t:SetPoint("TOP", 0, -5)
  t:SetText("던전 목록")

  local scroll = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -28)
  scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(150, 10)
  scroll:SetScrollChild(content)

  local y = 0
  local lastKind
  for _, id in ipairs(ns.DungeonOrder) do
    local d = ns.Dungeons[id]
    if d.kind ~= lastKind then
      lastKind = d.kind
      local h = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      h:SetPoint("TOPLEFT", 2, -y - 4)
      h:SetText(d.kind == "raid" and "— 공격대 —" or "— 던전 —")
      y = y + 20
    end
    local b = CreateFrame("Button", nil, content)
    b:SetSize(150, 18)
    b:SetPoint("TOPLEFT", 0, -y)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 6, 0)
    label:SetText(d.name .. (#d.floors > 1 and (DIM .. " (" .. #d.floors .. ")|r") or ""))
    b:SetScript("OnClick", function()
      autoOpened = false
      open(id)
    end)
    y = y + 18
  end
  content:SetHeight(y + 4)
end

local function toggleList()
  if not list then buildList() end
  list:SetShown(not list:IsShown())
end
listBtn:SetScript("OnClick", toggleList)

-- 열기/닫기 -----------------------------------------------------------------

local function currentInstance()
  local _, instType, _, _, _, _, _, iid = GetInstanceInfo()
  if (instType == "party" or instType == "raid") and ns.Dungeons[iid] then return iid end
end

function DungeonNav_Toggle()
  if f:IsShown() then f:Hide() return end
  local iid = currentInstance()
  if iid then open(iid) return end
  if current then open(current) return end
  open(ns.DungeonOrder[1])
  toggleList()
  say("인던 밖이라 목록을 열었습니다. 보고 싶은 던전을 고르세요.")
end
BINDING_HEADER_DUNGEONNAV = "던전 네비"
BINDING_NAME_DUNGEONNAV_TOGGLE = "던전 지도 열기/닫기"

local function onZoneChanged()
  local iid = currentInstance()
  if iid then
    if db.autoOpen and (current ~= iid or not f:IsShown()) then
      open(iid)
      autoOpened = true
      say(("%s 지도를 열었습니다. 닫기: ESC 또는 %s/던전|r, 자동 열기 끄기: %s/던전 자동|r"):format(ns.Dungeons[iid].name, KEY, KEY))
    end
  elseif autoOpened then
    f:Hide()            -- 인던에서 나오면 자동으로 연 지도는 닫는다
    autoOpened = false
  end
end

-- 명령어 ---------------------------------------------------------------------

local function showHelp()
  say("버전 " .. versionText())
  local lines = {
    "|cffffd100인던에 들어가면 지도가 자동으로 뜹니다.|r 보스 위치(해골)와 구역 이름이 그림에 있습니다.",
    "  " .. KEY .. "/던전|r            지도 열기/닫기 (인던 밖이면 목록)",
    "  " .. KEY .. "/던전 목록|r       던전 목록 열기",
    "  " .. KEY .. "/던전 <이름>|r     이름 일부로 열기  예) " .. KEY .. "/던전 검은바위|r",
    "  " .. KEY .. "/던전 자동|r       인던 들어갈 때 자동으로 열기 켜기/끄기 (지금: " .. (db.autoOpen and OK .. "켜짐|r" or NG .. "꺼짐|r") .. ")",
    "  " .. KEY .. "/던전 초기화|r     창 위치/크기/투명도 되돌리기",
    "  " .. KEY .. "/던전 도움말|r     이 안내",
    "|cffffd100지도 위에서:|r 휠 = 층 바꾸기, Ctrl+휠 = 크기, Alt+휠 = 투명도, 드래그 = 이동",
    "|cffffd100단축키:|r ESC > 설정 > 단축키 > 던전 네비 에서 지정할 수 있습니다.",
  }
  for _, l in ipairs(lines) do print(TAG .. l) end
end

local function findByName(q)
  for _, id in ipairs(ns.DungeonOrder) do
    if ns.Dungeons[id].name:find(q, 1, true) then return id end
  end
end

local function slash(msg)
  msg = strtrim(msg or "")
  local lower = msg:lower()
  if msg == "" then
    DungeonNav_Toggle()
  elseif lower == "도움말" or lower == "help" or lower == "?" then
    showHelp()
  elseif lower == "목록" or lower == "list" then
    if not f:IsShown() then DungeonNav_Toggle() end
    if not list or not list:IsShown() then toggleList() end
  elseif lower == "자동" or lower == "auto" then
    db.autoOpen = not db.autoOpen
    say("인던 들어갈 때 자동 열기: " .. (db.autoOpen and OK .. "켜짐|r" or NG .. "꺼짐|r"))
  elseif lower == "초기화" or lower == "reset" then
    db.width, db.alpha, db.point = DEFAULTS.width, DEFAULTS.alpha, nil
    f:ClearAllPoints()
    f:SetPoint("CENTER")
    layout()
    say("창 위치/크기/투명도를 되돌렸습니다.")
  else
    local id = findByName(msg)
    if id then
      autoOpened = false
      open(id)
    else
      say(NG .. "'" .. msg .. "' 던전을 찾지 못했습니다.|r " .. KEY .. "/던전 목록|r 으로 확인하세요.")
    end
  end
end

SLASH_DUNGEONNAV1 = "/던전"
SLASH_DUNGEONNAV2 = "/dn"
SLASH_DUNGEONNAV3 = "/dungeonnav"
SlashCmdList.DUNGEONNAV = slash

-- 시작 -----------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    DungeonNavDB = DungeonNavDB or {}
    db = DungeonNavDB
    for k, v in pairs(DEFAULTS) do
      if db[k] == nil then db[k] = type(v) == "table" and {} or v end
    end
    f:ClearAllPoints()
    if db.point then
      f:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    else
      f:SetPoint("CENTER")
    end
    layout()
  elseif event == "PLAYER_ENTERING_WORLD" then
    if arg1 then   -- 처음 접속(isInitialLogin)일 때만 안내
      if not db.welcomed then
        db.welcomed = true
        say("설치 감사합니다! 인던에 들어가면 지도가 자동으로 뜹니다. 사용법: " .. KEY .. "/던전 도움말|r")
      else
        say("버전 " .. versionText() .. " 로드됨. 도움말: " .. KEY .. "/던전 도움말|r")
      end
    end
    onZoneChanged()
  else
    onZoneChanged()
  end
end)
