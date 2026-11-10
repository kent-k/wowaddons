-- 편의 모음 (QoLKit) - 코어: 설정, 모듈 등록, 설정 창, 명령어
-- 기능 하나 = 모듈 하나 (Loot.lua, Merchant.lua, ...). 모듈은 ns.AddModule 로 등록한다.

local ADDON, ns = ...

ns.TAG = "|cffffd100[편의 모음]|r "
ns.OK, ns.NG, ns.DIM, ns.KEY = "|cff44ff44", "|cffff5555", "|cffaaaaaa", "|cffffff00"
function ns.say(msg) print(ns.TAG .. msg) end
local say, OK, NG, DIM, KEY = ns.say, ns.OK, ns.NG, ns.DIM, ns.KEY

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.VERSION = getMeta(ADDON, "Version") or "?"
local function versionText()
  if ns.VERSION:find("@project%-version@") then return NG .. "빌드 안 됨|r" end
  return OK .. ns.VERSION .. "|r"
end

-- 모듈 -------------------------------------------------------------------------
-- { key, title, desc, default, onEnable(), onDisable(), extra(parent) -> 설정 창에 덧붙일 위젯 }
ns.Modules = {}
function ns.AddModule(m)
  ns.Modules[#ns.Modules + 1] = m
end

function ns.Enabled(key)
  return QoLKitDB and QoLKitDB.on[key] ~= false
end

local function setEnabled(m, on)
  QoLKitDB.on[m.key] = on
  if on and m.onEnable then m.onEnable() end
  if not on and m.onDisable then m.onDisable() end
end

-- 공용 도우미 ---------------------------------------------------------------------

function ns.Money(copper)
  if GetCoinTextureString then return GetCoinTextureString(copper) end
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  return (g > 0 and (g .. "금 ") or "") .. ((g > 0 or s > 0) and (s .. "실 ") or "") .. c .. "동"
end

-- 가방 API (새/옛 이름 둘 다)
ns.Bag = {
  slots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots,
  free = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots,
  use = (C_Container and C_Container.UseContainerItem) or UseContainerItem,
}
-- 칸 정보: quality, link, count, noValue, itemID
function ns.Bag.info(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local i = C_Container.GetContainerItemInfo(bag, slot)
    if i then return i.quality, i.hyperlink, i.stackCount, i.hasNoValue, i.itemID end
    return nil
  end
  local _, count, _, quality, _, _, link, _, noValue, id = GetContainerItemInfo(bag, slot)
  return quality, link, count, noValue, id
end
function ns.Bag.freeSlots()
  local n = 0
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    local free, family = ns.Bag.free(bag)
    if (family or 0) == 0 then n = n + (free or 0) end
  end
  return n
end

-- 설정 창 ------------------------------------------------------------------------

local panel
local function buildPanel()
  panel = CreateFrame("Frame", "QoLKitFrame", UIParent, "BasicFrameTemplateWithInset")
  panel:SetFrameStrata("HIGH")
  panel:SetClampedToScreen(true)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
  panel:SetPoint("CENTER")
  tinsert(UISpecialFrames, "QoLKitFrame")
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -5)
  title:SetText("편의 모음 설정  " .. DIM .. ns.VERSION .. "|r")

  local y = -34
  for _, m in ipairs(ns.Modules) do
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", 14, y)
    cb:SetChecked(ns.Enabled(m.key))
    cb:SetScript("OnClick", function(self)
      setEnabled(m, self:GetChecked() and true or false)
      say(m.title .. ": " .. (self:GetChecked() and (OK .. "켬|r") or (NG .. "끔|r")))
    end)
    local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    t:SetText(m.title)
    local d = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 30, 2)
    d:SetWidth(330)
    d:SetJustifyH("LEFT")
    d:SetText(m.desc)
    y = y - 26 - math.max(14, d:GetStringHeight()) - 6
    if m.extra then
      local h = m.extra(panel, 44, y) or 0
      y = y - h
    end
    y = y - 6
  end
  panel:SetSize(400, -y + 30)
  local foot = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  foot:SetPoint("BOTTOM", 0, 10)
  foot:SetText("설정은 모든 캐릭터에 같이 적용됩니다.  ESC: 닫기")
end

function QoLKit_Toggle()
  if not panel then buildPanel() end
  panel:SetShown(not panel:IsShown())
  if panel:IsShown() and ns.refreshAll then ns.refreshAll() end
end
BINDING_HEADER_QOLKIT = "편의 모음"
BINDING_NAME_QOLKIT_TOGGLE = "편의 모음 설정 열기/닫기"

-- 모듈이 설정 창 새로 그리기에 끼어들 수 있게
ns.refreshers = {}
function ns.OnPanelRefresh(fn) ns.refreshers[#ns.refreshers + 1] = fn end
local function refreshAll() for _, fn in ipairs(ns.refreshers) do fn() end end

-- 명령어 ----------------------------------------------------------------------------

local function showHelp()
  say("버전 " .. versionText())
  print(ns.TAG .. "|cffffd100클래식 기본 UI 에 없는 편의 기능 모음입니다.|r 기능마다 켜고 끌 수 있습니다.")
  print(ns.TAG .. "  " .. KEY .. "/편의|r          설정 창 (기능 켜기/끄기)")
  print(ns.TAG .. "  " .. KEY .. "/편의 도움말|r   이 안내    영어: " .. KEY .. "/qol|r")
  for _, m in ipairs(ns.Modules) do
    local state = ns.Enabled(m.key) and (OK .. "켜짐|r") or (NG .. "꺼짐|r")
    print(ns.TAG .. ("  · %s [%s] %s%s|r"):format(m.title, state, DIM, m.help or m.desc))
  end
end

SLASH_QOLKIT1 = "/편의"
SLASH_QOLKIT2 = "/qol"
SLASH_QOLKIT3 = "/qolkit"
SlashCmdList.QOLKIT = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "도움말" or msg == "help" or msg == "?" then
    showHelp()
  elseif msg == "" then
    QoLKit_Toggle()
  else
    say(NG .. "모르는 명령입니다.|r " .. KEY .. "/편의 도움말|r")
  end
end

-- 시작 -----------------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    QoLKitDB = QoLKitDB or {}
    QoLKitDB.on = QoLKitDB.on or {}
    for _, m in ipairs(ns.Modules) do
      if QoLKitDB.on[m.key] == nil then QoLKitDB.on[m.key] = (m.default ~= false) end
    end
  else
    for _, m in ipairs(ns.Modules) do
      if m.onLogin then m.onLogin() end
      if ns.Enabled(m.key) and m.onEnable then m.onEnable() end
    end
    if not QoLKitDB.welcomed then
      QoLKitDB.welcomed = true
      say("설치 감사합니다! 빠른 줍기·회색 템 판매·자동 수리·쿨다운 숫자·우편 모두 받기·퀘스트 빠른 진행이 켜졌습니다. 켜고 끄기: " .. KEY .. "/편의|r")
    else
      say("버전 " .. versionText() .. " 로드됨. 설정: " .. KEY .. "/편의|r")
    end
  end
end)

ns.refreshAll = refreshAll
