-- 던전 네비 (DungeonNav)
-- 인던에 들어가면 그 던전 지도(게임 데이터의 지도 그림)를 자동으로 띄운다.
-- 블리자드가 인던 안 좌표를 애드온에 주지 않으므로, 내 위치는 지도를 클릭해 직접 표시한다.
-- (언젠가 좌표를 받을 수 있게 되면 화살표도 자동으로 표시한다.)

local ADDON, ns = ...
local TAG = "|cffffd100[던전 네비]|r "
local OK, NG, DIM, KEY = "|cff44ff44", "|cffff5555", "|cffaaaaaa", "|cffffff00"

local MAP_W, MAP_H = 1002, 668      -- 지도 그림 중 실제로 보이는 영역 (타일 4x3 = 1024x768 중)
local MIN_W, MAX_W = 300, 1400
local DEFAULTS = { width = 640, alpha = 1, autoOpen = true, lastFloor = {}, pins = {}, welcomed = false, questPanel = true }

local db                             -- DungeonNavDB
local current, floorIdx              -- 지금 보여 주는 던전 ID / 층 번호
local autoOpened = false
local lastInstance                   -- 마지막으로 들어가 있던 인던 ID (새로 들어오면 표시를 지운다)

local function say(msg) print(TAG .. msg) end

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local VERSION = getMeta(ADDON, "Version") or "?"
local function versionText()
  if VERSION:find("@project%-version@") then return NG .. "빌드 안 됨|r" end
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

-- 내 위치 표시 (지도 클릭으로 직접 찍는 별)
local pin = canvas:CreateTexture(nil, "OVERLAY")
pin:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
pin:SetSize(22, 22)
pin:Hide()

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
hint:SetPoint("BOTTOMRIGHT", -24, 13)   -- 오른쪽 끝은 크기 손잡이 자리
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
  floorText:SetWidth(w >= 360 and 110 or 70)
  -- 아래 띠 안내: 창이 좁으면 줄이거나 숨긴다 (버튼과 겹치지 않게)
  if w >= 860 then
    hint:SetText("클릭: 내 위치 표시   우클릭: 지우기   휠: 층   모서리 끌기/Ctrl+휠: 크기   Alt+휠: 투명도")
  elseif w >= 600 then
    hint:SetText("클릭: 위치  우클릭: 지우기  휠: 층  모서리: 크기")
  else
    hint:SetText("")
  end
end

-- 지금 층의 내 위치 표시를 그린다
local function showPin()
  local p = current and db.pins[current] and db.pins[current][floorIdx]
  if not p then pin:Hide() return end
  local w, h = canvas:GetSize()
  pin:ClearAllPoints()
  pin:SetPoint("CENTER", canvas, "TOPLEFT", p[1] * w, -p[2] * h)
  pin:Show()
end

-- 지도 크기 바꾸기 (모서리 손잡이, Ctrl+휠, /던전 크기 공통)
local function setWidth(w)
  db.width = math.max(MIN_W, math.min(MAX_W, math.floor(w)))
  layout()
  showPin()
end

-- 오른쪽 아래 모서리 손잡이: 끌어서 크기 조절 (왼쪽 위는 제자리에 둔다)
local grip = CreateFrame("Button", nil, f)
grip:SetSize(16, 16)
grip:SetPoint("BOTTOMRIGHT", -3, 3)
grip:SetFrameLevel(f:GetFrameLevel() + 10)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
grip:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText("끌어서 지도 크기 바꾸기")
  GameTooltip:AddLine("지도 위에서 Ctrl+휠, 또는 /던전 크기 400 으로도 됩니다.", 1, 1, 1, true)
  GameTooltip:Show()
end)
grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
grip:SetScript("OnMouseDown", function(self)
  -- 크기가 바뀌어도 왼쪽 위가 움직이지 않게 기준점을 왼쪽 위로 바꾼다
  local l, t = f:GetLeft(), f:GetTop()
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
  self.startX = GetCursorPosition() / f:GetEffectiveScale()
  self.startW = db.width
  self:SetScript("OnUpdate", function()
    local x = GetCursorPosition() / f:GetEffectiveScale()
    setWidth(self.startW + (x - self.startX))
  end)
end)
grip:SetScript("OnMouseUp", function(self)
  self:SetScript("OnUpdate", nil)
  local point, _, rel, x, y = f:GetPoint()
  db.point = { point, rel, x, y }
end)

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
  showPin()
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
    setWidth(db.width + delta * 40)
  elseif IsAltKeyDown() then
    db.alpha = math.max(0.2, math.min(1, db.alpha + delta * 0.1))
    f:SetAlpha(db.alpha)
  else
    changeFloor(-delta)   -- 휠을 아래로 굴리면 다음 층
  end
end)

-- 지도 클릭: 왼쪽 = 내 위치 표시, 오른쪽 = 지우기, 끌기 = 창 이동 ----------------

local dragging = false
canvas:EnableMouse(true)
canvas:RegisterForDrag("LeftButton")
canvas:SetScript("OnDragStart", function() dragging = true; f:StartMoving() end)
canvas:SetScript("OnDragStop", function()
  f:GetScript("OnDragStop")(f)
  dragging = false
end)
canvas:SetScript("OnMouseUp", function(self, button)
  if dragging or not current then return end
  if button == "RightButton" then
    if db.pins[current] then db.pins[current][floorIdx] = nil end
    showPin()
  elseif button == "LeftButton" then
    local cx, cy = GetCursorPosition()
    local s = self:GetEffectiveScale()
    local w, h = self:GetSize()
    local x = (cx / s - self:GetLeft()) / w
    local y = (self:GetTop() - cy / s) / h
    if x < 0 or x > 1 or y < 0 or y > 1 then return end
    db.pins[current] = db.pins[current] or {}
    db.pins[current][floorIdx] = { x, y }
    showPin()
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
    setPosState("blocked", "인던 안 좌표는 블리자드가 막음 · 클릭으로 위치 표시")
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

-- 던전 퀘스트 목록 (지도 창 왼쪽) ----------------------------------------------------
-- 퀘스트 목록은 지역 머리글 아래에 묶이고, 던전 퀘스트는 던전 이름 머리글 아래에 들어간다.
-- 지금 인던 이름과 같은 머리글 아래 퀘스트만 보여 준다.

local questBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
questBtn:SetSize(64, 22)
questBtn:SetText("퀘스트")
questBtn:SetPoint("LEFT", listBtn, "RIGHT", 6, 0)

local qp = CreateFrame("Frame", "DungeonNavQuestFrame", f, "BasicFrameTemplateWithInset")
qp:SetPoint("TOPRIGHT", f, "TOPLEFT", 2, 0)
qp:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", 2, 0)
qp:SetWidth(230)
qp:Hide()
qp.title = qp:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
qp.title:SetPoint("TOP", 0, -5)
qp.title:SetText("이 던전 퀘스트")
qp.text = qp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
qp.text:SetPoint("TOPLEFT", 12, -30)
qp.text:SetPoint("RIGHT", -12, 0)
qp.text:SetJustifyH("LEFT")
qp.text:SetJustifyV("TOP")
qp.text:SetSpacing(2)

local function squash(s) return (s or ""):gsub("%s", "") end

-- 퀘스트 목록 읽기 (옛 API / 새 API)
local function questEntries()
  local list = {}
  if GetNumQuestLogEntries and GetQuestLogTitle then
    local n = GetNumQuestLogEntries()
    for i = 1, n do
      local title, level, _, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
      list[#list + 1] = { index = i, title = title, level = level, header = isHeader, collapsed = isCollapsed, complete = isComplete == 1 or isComplete == true }
    end
  elseif C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local q = C_QuestLog.GetInfo(i)
      if q then
        list[#list + 1] = { index = i, title = q.title, level = q.level, header = q.isHeader, collapsed = q.isCollapsed,
          complete = q.questID and C_QuestLog.IsComplete and C_QuestLog.IsComplete(q.questID) }
      end
    end
  end
  return list
end

local function objectives(index)
  local out = {}
  if GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
    for j = 1, (GetNumQuestLeaderBoards(index) or 0) do
      local text, _, finished = GetQuestLogLeaderBoard(j, index)
      if text then out[#out + 1] = { text = text, done = finished } end
    end
  end
  return out
end

local function dungeonQuests()
  local name = GetInstanceInfo()
  local want = { squash(name) }
  if current and ns.Dungeons[current] then want[2] = squash(ns.Dungeons[current].name) end
  local found, collapsed, quests = false, false, {}
  local inside = false
  for _, e in ipairs(questEntries()) do
    if e.header then
      local h = squash(e.title)
      inside = false
      for _, w in ipairs(want) do
        if w ~= "" and (h == w or h:find(w, 1, true) or w:find(h, 1, true)) then inside = true end
      end
      if inside then found = true; collapsed = e.collapsed and true or false end
    elseif inside then
      e.objectives = objectives(e.index)
      quests[#quests + 1] = e
    end
  end
  return found, collapsed, quests
end

local function refreshQuests()
  if not qp:IsShown() then return end
  local found, collapsed, quests = dungeonQuests()
  local L = {}
  if not currentInstance() then
    L[#L + 1] = "|cffaaaaaa인던 안에서 그 던전의 퀘스트를 보여 줍니다.|r"
  elseif not found then
    L[#L + 1] = "|cffaaaaaa퀘스트 목록에 이 던전 퀘스트가 없습니다.|r"
    L[#L + 1] = " "
    L[#L + 1] = "|cffaaaaaa(퀘스트 목록에서 던전 이름 아래 묶인 퀘스트만 보여 줍니다)|r"
  elseif collapsed then
    L[#L + 1] = "|cffffd100퀘스트 목록에서 이 던전 묶음이 접혀 있습니다.|r"
    L[#L + 1] = "퀘스트 목록(L)을 열고 던전 이름 옆 [+] 를 눌러 펼치면 여기에 보입니다."
  elseif #quests == 0 then
    L[#L + 1] = "|cffaaaaaa이 던전 퀘스트가 없습니다.|r"
  else
    for _, q in ipairs(quests) do
      local color = q.complete and "|cff44ff44" or "|cffffd100"
      L[#L + 1] = color .. "[" .. tostring(q.level or "?") .. "] " .. (q.title or "?") .. (q.complete and "  (완료)" or "") .. "|r"
      for _, o in ipairs(q.objectives or {}) do
        L[#L + 1] = "   " .. (o.done and "|cff888888" or "|cffffffff") .. "- " .. o.text .. "|r"
      end
      L[#L + 1] = " "
    end
  end
  qp.text:SetText(table.concat(L, "\n"))
end

local function setQuestShown(on)
  db.questPanel = on
  qp:SetShown(on)
  refreshQuests()
end
questBtn:SetScript("OnClick", function() setQuestShown(not qp:IsShown()) end)
questBtn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:SetText("이 던전 퀘스트", 1, 1, 1)
  GameTooltip:AddLine("퀘스트 목록에서 지금 던전에 해당하는 퀘스트와 목표 진행도를 지도 왼쪽에 보여 줍니다.", nil, nil, nil, true)
  GameTooltip:Show()
end)
questBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
f:HookScript("OnShow", function()
  qp:SetShown(db.questPanel and currentInstance() ~= nil)
  refreshQuests()
end)
local qev = CreateFrame("Frame")
qev:RegisterEvent("QUEST_LOG_UPDATE")
qev:SetScript("OnEvent", refreshQuests)

local function onZoneChanged()
  local iid = currentInstance()
  if iid ~= lastInstance then
    if iid and db.pins[iid] then db.pins[iid] = nil end   -- 새로 들어온 인던: 지난번 위치 표시는 지운다
    lastInstance = iid
    if iid == current then showPin() end
  end
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
    "  " .. KEY .. "/던전 크기 400|r   지도 크기 바꾸기 (" .. MIN_W .. "~" .. MAX_W .. ", 창 오른쪽 아래 모서리를 끌어도 됨)",
    "  " .. KEY .. "/던전 초기화|r     창 위치/크기/투명도 되돌리기",
    "  " .. KEY .. "/던전 도움말|r     이 안내",
    "|cffffd100[퀘스트] 버튼:|r 인던 안에서 그 던전의 퀘스트와 목표 진행도를 지도 왼쪽에 보여 줍니다.",
    "|cffffd100지도 위에서:|r 클릭 = 내 위치에 별 표시, 우클릭 = 지우기, 휠 = 층 바꾸기, Ctrl+휠 = 크기, Alt+휠 = 투명도, 끌기 = 이동",
    "|cffffd100내 위치 화살표가 없는 이유:|r 블리자드가 인던 안에서는 애드온에 좌표를 주지 않습니다(모든 애드온 공통). 대신 지도를 클릭해 별로 표시하세요. 층마다 하나씩, 인던에 새로 들어오면 지워집니다.",
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
  elseif lower:match("^크기") or lower:match("^size") then
    local n = tonumber(msg:match("(%d+)"))
    if n then
      setWidth(n)
      say(("지도 너비: %d (가능한 범위 %d~%d)"):format(db.width, MIN_W, MAX_W))
    else
      say(("지도 너비는 지금 %d 입니다. 예) %s/던전 크기 400|r  (범위 %d~%d, 창 오른쪽 아래 모서리를 끌어도 됩니다)"):format(db.width, KEY, MIN_W, MAX_W))
    end
  elseif lower == "초기화" or lower == "reset" then
    db.width, db.alpha, db.point = DEFAULTS.width, DEFAULTS.alpha, nil
    f:ClearAllPoints()
    f:SetPoint("CENTER")
    layout()
    showPin()
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
ev:SetScript("OnEvent", function(_, event, arg1, arg2)
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
    if arg2 then lastInstance = currentInstance() end   -- /reload 는 새로 들어온 것이 아니므로 표시를 지우지 않는다
    onZoneChanged()
  else
    onZoneChanged()
  end
end)
