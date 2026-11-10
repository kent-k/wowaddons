-- 매크로 공방 (MacroKit) - 화면
-- [직업 탭] [템플릿 목록] [빈칸 채우기 + 미리보기 + 등록]  /  [내 매크로]

local ADDON, ns = ...
local say, OK, NG, DIM, KEY = ns.say, ns.OK, ns.NG, ns.DIM, ns.KEY

local W, H = 800, 520
local LIST_W = 236
local MAX_PARAMS = 6

local state = {
  class = nil,      -- 지금 보고 있는 탭 (직업 키 또는 "MINE")
  tid = nil,        -- 고른 템플릿 ID
  values = {},      -- 빈칸 값
  perChar = true,   -- 캐릭터 전용으로 만들지
  lastIndex = nil,  -- 방금 만든 매크로 번호
}

-- 창 -------------------------------------------------------------------------

local f = CreateFrame("Frame", "MacroKitFrame", UIParent, "BasicFrameTemplateWithInset")
f:Hide()
f:SetSize(W, H)
f:SetFrameStrata("HIGH")
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local point, _, rel, x, y = self:GetPoint()
  MacroKitDB.point = { point, rel, x, y }
end)
tinsert(UISpecialFrames, "MacroKitFrame")

f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", 0, -5)

local function bg(frame, a)
  local t = frame:CreateTexture(nil, "BACKGROUND")
  t:SetAllPoints()
  t:SetColorTexture(0, 0, 0, a or 0.35)
  return t
end

-- 아래 띠: 남은 칸 / 안내
local countText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
countText:SetPoint("BOTTOMLEFT", 14, 10)
local footHint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footHint:SetPoint("BOTTOMRIGHT", -14, 10)
footHint:SetText("끌기: 창 이동   ESC: 닫기   도움말: /매공 도움말")

local function updateCounts()
  if not GetNumMacros then return end
  local acc, char, maxAcc, maxChar = ns.MacroLimits()
  local function c(n, m) return (n >= m and NG or "|cffffffff") .. n .. "|r/" .. m end
  countText:SetText("매크로 칸  공용 " .. c(acc, maxAcc) .. "   캐릭터 " .. c(char, maxChar)
    .. (InCombatLockdown() and ("   " .. NG .. "전투 중 - 등록 불가|r") or ""))
end

-- 드롭다운 (직접 만든 목록 창) ------------------------------------------------------

local menu = CreateFrame("Frame", "MacroKitMenu", f)
menu:Hide()
menu:SetFrameStrata("FULLSCREEN_DIALOG")
menu:EnableMouse(true)
menu:SetClampedToScreen(true)
bg(menu, 0.92)
do  -- 금색 테두리
  for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
    local t = menu:CreateTexture(nil, "BORDER")
    t:SetColorTexture(0.8, 0.65, 0.2, 0.9)
    t:SetPoint(side[1])
    t:SetPoint(side[2])
    if side[3] then t:SetWidth(1) else t:SetHeight(1) end
  end
end
local menuScroll = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
menuScroll:SetPoint("TOPLEFT", 4, -4)
menuScroll:SetPoint("BOTTOMRIGHT", -26, 4)
local menuContent = CreateFrame("Frame", nil, menuScroll)
menuContent:SetSize(10, 10)
menuScroll:SetScrollChild(menuContent)
local menuButtons = {}
local menuOwner

local function menuButton(i)
  local b = menuButtons[i]
  if b then return b end
  b = CreateFrame("Button", nil, menuContent)
  b:SetHeight(20)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(16, 16)
  b.icon:SetPoint("LEFT", 4, 0)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
  b.text:SetPoint("RIGHT", -4, 0)
  b.text:SetJustifyH("LEFT")
  b:SetScript("OnEnter", function(self)
    if self.tip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  menuButtons[i] = b
  return b
end

-- items = { { text, icon, value, disabled, tip }, ... }
local function openMenu(owner, items, onPick)
  if menu:IsShown() and menuOwner == owner then menu:Hide() return end
  menuOwner = owner
  local width = math.max(owner:GetWidth(), 220)
  for i, it in ipairs(items) do
    local b = menuButton(i)
    b:SetWidth(width - 30)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
    b.icon:SetTexture(it.icon or nil)
    b.icon:SetShown(it.icon ~= nil)
    b.text:SetText(it.text)
    b.text:SetTextColor(it.disabled and 0.5 or 1, it.disabled and 0.5 or 1, it.disabled and 0.5 or 1)
    b.tip = it.tip
    b:SetScript("OnClick", function()
      if it.disabled then return end
      menu:Hide()
      onPick(it.value)
    end)
    b:Show()
  end
  for i = #items + 1, #menuButtons do menuButtons[i]:Hide() end
  if #items == 0 then
    local b = menuButton(1)
    b:SetWidth(width - 30)
    b.icon:Hide()
    b.text:SetText("(고를 것이 없습니다)")
    b.text:SetTextColor(0.5, 0.5, 0.5)
    b.tip = nil
    b:SetScript("OnClick", function() menu:Hide() end)
    b:Show()
  end
  menuContent:SetSize(width - 30, math.max(1, #items) * 20)
  menu:SetSize(width, math.min(320, math.max(1, #items) * 20 + 8))
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
  menuScroll:SetVerticalScroll(0)
  menu:Show()
end
f:HookScript("OnHide", function() menu:Hide() end)

-- 직업 탭 ----------------------------------------------------------------------

local tabs = {}
local selectTab   -- 아래에서 정의

local function tabColor(key)
  if key == "COMMON" or key == "MINE" then return 1, 0.82, 0 end
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[key]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

do
  local keys = {}
  for _, k in ipairs(ns.ClassOrder) do keys[#keys + 1] = k end
  keys[#keys + 1] = "MINE"
  local tw = math.floor((W - 24) / #keys)
  for i, key in ipairs(keys) do
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(tw - 2, 22)
    b:SetPoint("TOPLEFT", 12 + (i - 1) * tw, -28)
    b:SetText(key == "MINE" and "내 매크로" or ns.ClassShort[key])
    b:GetFontString():SetTextColor(tabColor(key))
    b.key = key
    b:SetScript("OnClick", function() selectTab(key) end)
    tabs[key] = b
  end
end

-- 왼쪽: 템플릿 목록 ------------------------------------------------------------------

local left = CreateFrame("Frame", nil, f)
left:SetPoint("TOPLEFT", 12, -56)
left:SetPoint("BOTTOMLEFT", 12, 30)
left:SetWidth(LIST_W)
bg(left)
local listScroll = CreateFrame("ScrollFrame", nil, left, "UIPanelScrollFrameTemplate")
listScroll:SetPoint("TOPLEFT", 4, -4)
listScroll:SetPoint("BOTTOMRIGHT", -26, 4)
local listContent = CreateFrame("Frame", nil, listScroll)
listContent:SetSize(LIST_W - 30, 10)
listScroll:SetScrollChild(listContent)
local listRows, listHeads = {}, {}
local selectTemplate   -- 아래에서 정의

local function listRow(i)
  local b = listRows[i]
  if b then return b end
  b = CreateFrame("Button", nil, listContent)
  b:SetSize(LIST_W - 34, 20)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  b.sel = b:CreateTexture(nil, "BACKGROUND")
  b.sel:SetAllPoints()
  b.sel:SetColorTexture(1, 0.82, 0, 0.18)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("LEFT", 8, 0)
  b.text:SetPoint("RIGHT", -2, 0)
  b.text:SetJustifyH("LEFT")
  b:SetScript("OnClick", function(self) selectTemplate(self.tid) end)
  b:SetScript("OnEnter", function(self)
    if self.reason then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.reason, 1, 0.5, 0.5, 1, true)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  listRows[i] = b
  return b
end

local function listHead(i)
  local h = listHeads[i]
  if h then return h end
  h = listContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  h:SetJustifyH("LEFT")
  listHeads[i] = h
  return h
end

local function isMine(class)
  return class == "COMMON" or class == ns.PlayerClass()
end

local function refreshList()
  local list = ns.Templates[state.class] or {}
  local byCat = {}
  for _, t in ipairs(list) do
    byCat[t.cat] = byCat[t.cat] or {}
    table.insert(byCat[t.cat], t)
  end
  local y, ri, hi = 0, 0, 0
  local mine = isMine(state.class)
  for _, cat in ipairs(ns.CatOrder) do
    if byCat[cat] then
      hi = hi + 1
      local h = listHead(hi)
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", 4, -y - 4)
      h:SetText(ns.CatNames[cat] or cat)
      h:Show()
      y = y + 20
      for _, t in ipairs(byCat[cat]) do
        ri = ri + 1
        local b = listRow(ri)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 0, -y)
        b.tid = t.id
        local usable, reason = ns.TemplateUsable(t)
        if not mine then usable, reason = true, nil end
        b.reason = (not usable) and reason or nil
        b.text:SetText(t.title)
        if usable then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(0.5, 0.5, 0.5) end
        b.sel:SetShown(state.tid == t.id)
        b:Show()
        y = y + 20
      end
    end
  end
  for i = ri + 1, #listRows do listRows[i]:Hide() end
  for i = hi + 1, #listHeads do listHeads[i]:Hide() end
  listContent:SetHeight(y + 4)
end

-- 오른쪽: 템플릿 편집 ------------------------------------------------------------------

local right = CreateFrame("Frame", nil, f)
right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
right:SetPoint("BOTTOMRIGHT", -12, 30)
local RW = W - LIST_W - 36

local rTitle = right:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
rTitle:SetPoint("TOPLEFT", 4, -4)
rTitle:SetWidth(RW - 8)
rTitle:SetJustifyH("LEFT")

local rDesc = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
rDesc:SetPoint("TOPLEFT", rTitle, "BOTTOMLEFT", 0, -6)
rDesc:SetWidth(RW - 8)
rDesc:SetJustifyH("LEFT")
rDesc:SetSpacing(2)

local paramArea = CreateFrame("Frame", nil, right)
paramArea:SetPoint("TOPLEFT", rDesc, "BOTTOMLEFT", 0, -10)
paramArea:SetSize(RW - 8, MAX_PARAMS * 28)

local refreshRight   -- 아래에서 정의
local paramRows = {}
for i = 1, MAX_PARAMS do
  local row = {}
  row.label = paramArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.label:SetPoint("TOPLEFT", 0, -(i - 1) * 28 - 5)
  row.label:SetWidth(120)
  row.label:SetJustifyH("LEFT")

  row.drop = CreateFrame("Button", nil, paramArea, "UIPanelButtonTemplate")
  row.drop:SetSize(260, 24)
  row.drop:SetPoint("TOPLEFT", 124, -(i - 1) * 28)
  row.drop.icon = row.drop:CreateTexture(nil, "OVERLAY")
  row.drop.icon:SetSize(16, 16)
  row.drop.icon:SetPoint("LEFT", 8, 0)
  local fs = row.drop:GetFontString()
  fs:ClearAllPoints()
  fs:SetPoint("LEFT", row.drop.icon, "RIGHT", 6, 0)
  fs:SetPoint("RIGHT", -20, 0)
  fs:SetJustifyH("LEFT")
  row.drop.arrow = row.drop:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.drop.arrow:SetPoint("RIGHT", -8, 0)
  row.drop.arrow:SetText("▼")

  row.check = CreateFrame("CheckButton", nil, paramArea, "UICheckButtonTemplate")
  row.check:SetSize(24, 24)
  row.check:SetPoint("TOPLEFT", 120, -(i - 1) * 28)

  paramRows[i] = row
end

-- 미리보기
local pvLabel = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
pvLabel:SetPoint("TOPLEFT", paramArea, "BOTTOMLEFT", 0, -4)
pvLabel:SetText("미리보기 (만들어질 매크로)")
local pvCount = right:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
pvCount:SetPoint("BOTTOMRIGHT", right, "TOPLEFT", RW - 4, 0)
local pvBox = CreateFrame("Frame", nil, right)
pvBox:SetPoint("TOPLEFT", pvLabel, "BOTTOMLEFT", 0, -4)
pvBox:SetSize(RW - 8, 92)
bg(pvBox, 0.5)
local pvText = pvBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
pvText:SetPoint("TOPLEFT", 8, -6)
pvText:SetPoint("BOTTOMRIGHT", -8, 6)
pvText:SetJustifyH("LEFT")
pvText:SetJustifyV("TOP")
pvCount:ClearAllPoints()
pvCount:SetPoint("BOTTOMRIGHT", pvBox, "TOPRIGHT", 0, 3)

-- 이름 / 공용·캐릭터 / 등록
local nameLabel = right:CreateFontString(nil, "OVERLAY", "GameFontNormal")
nameLabel:SetPoint("TOPLEFT", pvBox, "BOTTOMLEFT", 0, -12)
nameLabel:SetText("매크로 이름")
local nameBox = CreateFrame("EditBox", "MacroKitNameBox", right, "InputBoxTemplate")
nameBox:SetSize(150, 22)
nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 12, 0)
nameBox:SetAutoFocus(false)
nameBox:SetMaxLetters(ns.NAME_MAX)
nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

local charCheck = CreateFrame("CheckButton", nil, right, "UICheckButtonTemplate")
charCheck:SetSize(24, 24)
charCheck:SetPoint("LEFT", nameBox, "RIGHT", 14, 0)
charCheck.label = right:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
charCheck.label:SetPoint("LEFT", charCheck, "RIGHT", 2, 0)
charCheck.label:SetText("이 캐릭터 전용")
charCheck:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText("이 캐릭터 전용 매크로", 1, 1, 1)
  GameTooltip:AddLine("켜면 이 캐릭터에만 생깁니다 (최대 18개). 끄면 모든 캐릭터가 같이 쓰는 공용 매크로가 됩니다 (최대 120개).", nil, nil, nil, true)
  GameTooltip:Show()
end)
charCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

local regBtn = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
regBtn:SetSize(130, 28)
regBtn:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -14)

local status = right:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("LEFT", regBtn, "RIGHT", 12, 0)
status:SetPoint("RIGHT", right, "RIGHT", -60, 0)
status:SetJustifyH("LEFT")

-- 만든 매크로 아이콘 (끌어서 단축바로)
local dragIcon = CreateFrame("Button", "MacroKitDragIcon", right)
dragIcon:SetSize(40, 40)
dragIcon:SetPoint("TOPRIGHT", pvBox, "BOTTOMRIGHT", 0, -10)
dragIcon.tex = dragIcon:CreateTexture(nil, "ARTWORK")
dragIcon.tex:SetAllPoints()
dragIcon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
dragIcon.label = right:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
dragIcon.label:SetPoint("TOP", dragIcon, "BOTTOM", 0, -2)
dragIcon.label:SetText("끌어서 단축바로")
dragIcon:RegisterForDrag("LeftButton")
dragIcon:Hide()
local function pickupCurrent()
  local idx = GetMacroIndexByName(strtrim(nameBox:GetText() or ""))
  if idx and idx > 0 then PickupMacro(idx) end
end
dragIcon:SetScript("OnDragStart", pickupCurrent)
dragIcon:SetScript("OnClick", pickupCurrent)
dragIcon:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText("행동 단축바에 놓기", 1, 1, 1)
  GameTooltip:AddLine("이 아이콘을 끌어서 단축바 칸에 놓으세요. (블리자드가 애드온이 단축바에 직접 놓는 것을 막아 두었습니다.)", nil, nil, nil, true)
  GameTooltip:Show()
end)
dragIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- 빈칸 위젯 채우기 ----------------------------------------------------------------

local function spellItems(t, p, mine)
  local items = {}
  local ids = p.spells
  if p.any then
    for _, s in ipairs(ns.SpellbookSpells()) do
      items[#items + 1] = { text = s.name, icon = s.icon, value = s.id }
    end
    return items
  end
  for _, id in ipairs(ids) do
    local name, icon = ns.SpellInfo(id)
    if name then
      local known = (not mine) or p.pet or ns.SpellKnown(id)
      items[#items + 1] = {
        text = name .. ((p.pet and mine) and (DIM .. "  (소환수)|r") or ""), icon = icon, value = id,
        disabled = not known, tip = (not known) and "아직 배우지 않은 주문입니다." or nil,
      }
    end
  end
  return items
end

local function targetItems(t, p)
  local items = {}
  for _, r in ipairs(ns.TargetRules[(t.help or p.help) and "help" or "harm"]) do
    local usable = ns.RuleUsable(r)
    items[#items + 1] = {
      text = r.label, value = r.key, disabled = not usable,
      tip = (not usable) and "이 클라이언트는 주시 대상을 지원하지 않습니다." or nil,
    }
  end
  return items
end

local function targetLabel(t, p, v)
  for _, r in ipairs(ns.TargetRules[(t.help or p.help) and "help" or "harm"]) do
    if r.key == v then return r.label end
  end
  return v or "?"
end

local function choiceItems(p, mine)
  local items = {}
  for _, o in ipairs(p.options) do
    local icon, disabled
    if o.spell then
      local _, ic = ns.SpellInfo(o.spell)
      icon = ic
      disabled = mine and not ns.SpellKnown(o.spell)
    end
    items[#items + 1] = { text = o.label, icon = icon, value = o.value, disabled = disabled, tip = disabled and "아직 배우지 않은 주문입니다." or nil }
  end
  return items
end

local function itemItems(p)
  local items = {}
  for _, it in ipairs(ns.BagItems(p.filter)) do
    items[#items + 1] = { text = it.name, icon = it.icon, value = { id = it.id, name = it.name } }
  end
  return items
end

local function fillParam(row, t, p, mine)
  row.label:SetText(p.label)
  row.label:Show()
  row.drop:Hide()
  row.check:Hide()
  local v = state.values[p.key]
  if p.type == "check" then
    row.check:SetChecked(v and true or false)
    row.check:SetScript("OnClick", function(self)
      state.values[p.key] = self:GetChecked() and true or false
      refreshRight()
    end)
    row.check:Show()
    return
  end
  local text, icon = "고르세요", nil
  local getItems
  if p.type == "spell" then
    if v then text, icon = ns.SpellInfo(v) end
    getItems = function() return spellItems(t, p, mine) end
  elseif p.type == "target" then
    text = targetLabel(t, p, v)
    getItems = function() return targetItems(t, p) end
  elseif p.type == "choice" then
    for _, o in ipairs(p.options) do
      if o.value == v then
        text = o.label
        if o.spell then icon = select(2, ns.SpellInfo(o.spell)) end
      end
    end
    getItems = function() return choiceItems(p, mine) end
  elseif p.type == "item" then
    if v and v.name then
      text = v.name
      icon = select(2, ns.ItemInfo(v.id))
    else
      text = "가방에서 고르세요"
    end
    getItems = function() return itemItems(p) end
  end
  row.drop:SetText(text or "?")
  row.drop.icon:SetTexture(icon or nil)
  row.drop.icon:SetShown(icon ~= nil)
  row.drop:SetScript("OnClick", function(self)
    openMenu(self, getItems(), function(value)
      state.values[p.key] = value
      refreshRight()
    end)
  end)
  row.drop:Show()
end

local function setStatus(msg, r, g, b)
  status:SetText(msg or "")
  status:SetTextColor(r or 1, g or 1, b or 1)
end

local function showWelcome()
  rTitle:SetText("매크로 공방 사용법")
  rDesc:SetText(
    "1. 위에서 직업 탭을 고릅니다 (내 직업이 먼저 열립니다).\n" ..
    "2. 왼쪽 목록에서 만들고 싶은 매크로를 고릅니다.\n" ..
    "3. 오른쪽 빈칸(주문·대상 등)을 눌러 고르면 아래에 매크로가 미리 보입니다.\n" ..
    "4. [등록] 을 누르면 매크로가 만들어집니다.\n" ..
    "5. 오른쪽에 나타난 아이콘을 끌어서 행동 단축바에 놓으면 끝.\n\n" ..
    DIM .. "· 마우스오버 = 공격대 창이나 적에게 마우스를 올린 채 단축키를 누르는 방식입니다.\n" ..
    "· 전투 중에는 만들 수 없습니다 (블리자드 제한).\n" ..
    "· 이 애드온이 만든 매크로만 고치거나 지웁니다. 직접 만든 매크로는 건드리지 않습니다.\n" ..
    "· 만든 매크로는 '내 매크로' 탭에서 다시 고치거나 지울 수 있습니다.|r")
  paramArea:Hide()
  for _, w in ipairs({ pvLabel, pvBox, pvCount, nameLabel, nameBox, charCheck, charCheck.label, regBtn, status, dragIcon, dragIcon.label }) do w:Hide() end
end

local function showEditor()
  paramArea:Show()
  for _, w in ipairs({ pvLabel, pvBox, pvCount, nameLabel, nameBox, charCheck, charCheck.label, regBtn, status }) do w:Show() end
end

function refreshRight()
  updateCounts()
  local t = state.tid and ns.ById[state.tid]
  if not t then showWelcome() return end
  showEditor()
  local mine = isMine(t.class)
  rTitle:SetText(t.title .. (mine and "" or (DIM .. "  (" .. ns.ClassNames[t.class] .. ")|r")))
  rDesc:SetText(t.desc or "")

  for i, row in ipairs(paramRows) do
    local p = t.params[i]
    if p then
      fillParam(row, t, p, mine)
    else
      row.label:Hide(); row.drop:Hide(); row.check:Hide()
    end
  end
  paramArea:SetHeight(math.max(1, #t.params) * 28)

  local body, err = ns.Render(t, state.values)
  pvText:SetText(body or (DIM .. "(빈칸을 모두 채우면 여기에 매크로가 보입니다)|r"))
  local len = body and #body or 0
  pvCount:SetText(("%s%d|r / %d 바이트"):format(len > ns.BODY_MAX and NG or "|cffffffff", len, ns.BODY_MAX))

  -- 등록 버튼 상태
  local name = strtrim(nameBox:GetText() or "")
  local usable, reason = ns.TemplateUsable(t)
  if not mine then
    regBtn:SetText("등록")
    regBtn:Disable()
    setStatus("다른 직업 템플릿은 보기만 할 수 있습니다.", 0.7, 0.7, 0.7)
  elseif not usable then
    regBtn:SetText("등록")
    regBtn:Disable()
    setStatus(reason, 1, 0.4, 0.4)
  elseif err then
    regBtn:SetText("등록")
    regBtn:Disable()
    setStatus(err, 1, 0.82, 0)
  else
    local st = ns.RegisterState(name, state.perChar)
    if st == "new" or st == "overwrite" then
      regBtn:SetText(st == "overwrite" and "덮어쓰기" or "등록")
      regBtn:Enable()
      if status.keep then
        status.keep = nil
      else
        setStatus(st == "overwrite" and "이미 만든 매크로입니다. 누르면 지금 내용으로 고칩니다." or "준비됐습니다. [등록] 을 누르세요.", 0.6, 1, 0.6)
      end
    else
      regBtn:SetText("등록")
      regBtn:Disable()
      setStatus(st, 1, 0.4, 0.4)
    end
  end

  -- 이미 있는 내 매크로면 아이콘 표시
  local rec, idx = ns.Owned(name)
  if rec and idx then
    local _, icon = GetMacroInfo(idx)
    dragIcon.tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    dragIcon:Show()
    dragIcon.label:Show()
  else
    dragIcon:Hide()
    dragIcon.label:Hide()
  end
end

nameBox:SetScript("OnTextChanged", function(_, user) if user then refreshRight() end end)
charCheck:SetScript("OnClick", function(self)
  state.perChar = self:GetChecked() and true or false
  refreshRight()
end)

regBtn:SetScript("OnClick", function()
  local t = state.tid and ns.ById[state.tid]
  if not t then return end
  local ok, idx, msg = ns.Register(t, state.values, nameBox:GetText(), state.perChar)
  if ok then
    say(OK .. msg .. "|r")
    status.keep = true
    setStatus(msg, 0.6, 1, 0.6)
  else
    say(NG .. idx .. "|r")
    status.keep = true
    setStatus(idx, 1, 0.4, 0.4)
  end
  refreshRight()
  if ok then refreshList() end
end)

function selectTemplate(tid, values, name, perChar)
  local t = ns.ById[tid]
  if not t then return end
  menu:Hide()
  state.tid = tid
  if perChar == nil then perChar = t.class ~= "COMMON" end
  state.perChar = perChar
  local ownedName, rec = ns.OwnedNameFor(tid, perChar)
  state.values = values or (rec and rec.values) or ns.DefaultValues(t)
  nameBox:SetText(name or ownedName or t.name or "")
  charCheck:SetChecked(state.perChar)
  status.keep = nil
  refreshList()
  refreshRight()
end

-- 내 매크로 탭 ----------------------------------------------------------------------

local mine = CreateFrame("Frame", nil, f)
mine:SetPoint("TOPLEFT", 12, -56)
mine:SetPoint("BOTTOMRIGHT", -12, 30)
mine:Hide()
bg(mine)
local mineScroll = CreateFrame("ScrollFrame", nil, mine, "UIPanelScrollFrameTemplate")
mineScroll:SetPoint("TOPLEFT", 6, -6)
mineScroll:SetPoint("BOTTOMRIGHT", -28, 6)
local mineContent = CreateFrame("Frame", nil, mineScroll)
mineContent:SetSize(W - 60, 10)
mineScroll:SetScrollChild(mineContent)
local mineEmpty = mine:CreateFontString(nil, "OVERLAY", "GameFontDisable")
mineEmpty:SetPoint("CENTER")
mineEmpty:SetText("아직 이 애드온으로 만든 매크로가 없습니다.\n직업 탭에서 템플릿을 골라 등록해 보세요.")
local mineRows = {}

local function mineRow(i)
  local r = mineRows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, mineContent)
  r:SetSize(W - 64, 40)
  r.icon = CreateFrame("Button", nil, r)
  r.icon:SetSize(34, 34)
  r.icon:SetPoint("LEFT", 2, 0)
  r.icon.tex = r.icon:CreateTexture(nil, "ARTWORK")
  r.icon.tex:SetAllPoints()
  r.icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  r.icon:RegisterForDrag("LeftButton")
  local function pick() local idx = r.name and GetMacroIndexByName(r.name) if idx and idx > 0 then PickupMacro(idx) end end
  r.icon:SetScript("OnDragStart", pick)
  r.icon:SetScript("OnClick", pick)
  r.icon:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(r.name or "", 1, 1, 1)
    GameTooltip:AddLine(r.body or "", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("끌어서 행동 단축바에 놓으세요.", 0.4, 1, 0.4)
    GameTooltip:Show()
  end)
  r.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r.name = nil
  r.title = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  r.title:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 10, -2)
  r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 10, 2)
  r.del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
  r.del:SetSize(80, 22)
  r.del:SetPoint("RIGHT", -4, 0)
  r.edit = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
  r.edit:SetSize(80, 22)
  r.edit:SetPoint("RIGHT", r.del, "LEFT", -6, 0)
  r.edit:SetText("고치기")
  mineRows[i] = r
  return r
end

local refreshMine
function refreshMine()
  updateCounts()
  local list = ns.OwnedList()
  mineEmpty:SetShown(#list == 0)
  for i, e in ipairs(list) do
    local r = mineRow(i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -(i - 1) * 44)
    r.name = e.name
    local _, icon, body = GetMacroInfo(e.index)
    r.body = body
    r.icon.tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local t = ns.ById[e.rec.tid]
    r.title:SetText(e.name)
    r.sub:SetText((t and (ns.ClassNames[t.class] .. " · " .. t.title) or (DIM .. "(템플릿이 없어짐)|r"))
      .. DIM .. "   " .. (e.perChar and "캐릭터 전용" or "공용") .. "|r")
    r.edit:SetEnabled(t ~= nil)
    r.edit:SetScript("OnClick", function()
      selectTab(t.class)
      selectTemplate(t.id, e.rec.values, e.name, e.perChar)
    end)
    r.del:SetText("지우기")
    r.del.armed = nil
    r.del:SetScript("OnClick", function(self)
      if not self.armed then    -- 실수 방지: 한 번 더 눌러야 지운다
        self.armed = true
        self:SetText(NG .. "정말?|r")
        C_Timer.After(3, function() if self.armed then self.armed = nil self:SetText("지우기") end end)
        return
      end
      local ok, msg = ns.Delete(e.name)
      say((ok and OK or NG) .. msg .. "|r")
      refreshMine()
    end)
    r:Show()
  end
  for i = #list + 1, #mineRows do mineRows[i]:Hide() end
  mineContent:SetHeight(#list * 44 + 4)
end

-- 탭 고르기 ---------------------------------------------------------------------------

function selectTab(key)
  menu:Hide()
  state.class = key
  for k, b in pairs(tabs) do
    if k == key then b:LockHighlight() else b:UnlockHighlight() end
  end
  if key == "MINE" then
    left:Hide(); right:Hide(); mine:Show()
    f.title:SetText("매크로 공방 - 내 매크로")
    refreshMine()
    return
  end
  mine:Hide(); left:Show(); right:Show()
  f.title:SetText("매크로 공방 - " .. ns.ClassNames[key] .. (isMine(key) and "" or "  (보기만)"))
  local t = state.tid and ns.ById[state.tid]
  if not t or t.class ~= key then state.tid = nil end
  listScroll:SetVerticalScroll(0)
  refreshList()
  refreshRight()
end

-- 열기 / 닫기 -----------------------------------------------------------------------

function MacroKit_Toggle()
  if f:IsShown() then f:Hide() return end
  f:Show()
  if not state.class then
    local my = ns.PlayerClass()
    selectTab(ns.Templates[my] and my or "COMMON")
  else
    selectTab(state.class)
  end
end
BINDING_HEADER_MACROKIT = "매크로 공방"
BINDING_NAME_MACROKIT_TOGGLE = "매크로 공방 열기/닫기"

-- 검사 결과 창 ------------------------------------------------------------------------

local report
local function showReport(lines)
  if not report then
    report = CreateFrame("Frame", "MacroKitReport", UIParent, "BasicFrameTemplateWithInset")
    report:SetSize(560, 440)
    report:SetPoint("CENTER")
    report:SetFrameStrata("DIALOG")
    report:SetMovable(true)
    report:EnableMouse(true)
    report:RegisterForDrag("LeftButton")
    report:SetScript("OnDragStart", report.StartMoving)
    report:SetScript("OnDragStop", report.StopMovingOrSizing)
    tinsert(UISpecialFrames, "MacroKitReport")
    report.title = report:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    report.title:SetPoint("TOP", 0, -5)
    report.title:SetText("매크로 공방 검사 결과 (끌어서 이동, ESC 로 닫기)")
    local sc = CreateFrame("ScrollFrame", nil, report, "UIPanelScrollFrameTemplate")
    sc:SetPoint("TOPLEFT", 12, -30)
    sc:SetPoint("BOTTOMRIGHT", -32, 12)
    local c = CreateFrame("Frame", nil, sc)
    c:SetSize(500, 10)
    sc:SetScrollChild(c)
    report.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    report.text:SetPoint("TOPLEFT")
    report.text:SetWidth(500)
    report.text:SetJustifyH("LEFT")
    report.text:SetSpacing(3)
    report.content = c
  end
  report.text:SetText(table.concat(lines, "\n"))
  report.content:SetHeight(report.text:GetStringHeight() + 10)
  report:Show()
end

function ns.RunCheck()
  local c = ns.DetectCaps()
  local function yn(v) return v and (OK .. "됨|r") or (NG .. "안 됨|r") end
  local L = {}
  local function add(s) L[#L + 1] = s end
  local ver, _, _, iface = GetBuildInfo()
  add("|cffffd100■ 버전|r")
  add(("  애드온 %s · 게임 빌드 %s (Interface %s)"):format(ns.versionText(), tostring(ver), tostring(iface)))
  add("")
  add("|cffffd100■ 매크로 기능|r")
  add("  애드온이 매크로를 만들 수 있나: " .. yn(c.macroApi))
  local acc, char, maxAcc, maxChar = ns.MacroLimits()
  add(("  매크로 칸: 공용 %d/%d, 캐릭터 %d/%d"):format(acc, maxAcc, char, maxChar))
  add("")
  add("|cffffd100■ 매크로 문법 (이 클라이언트가 알아듣는지)|r")
  add("  [@대상] 표기: " .. yn(c.at) .. "    [target=대상] 표기: " .. yn(c.legacy))
  add("  주시 대상 (/focus): " .. yn(c.focus) .. (c.focus and "" or (DIM .. "  → '주시' 대상 선택지는 꺼 둡니다|r")))
  add("  nodead 조건: " .. yn(c.nodead) .. "    mod 조건(Shift 등): " .. yn(c.mod))
  add("  /castsequence: " .. yn(c.castsequence) .. "    /startattack: " .. yn(c.startattack))
  add("  /cancelform: " .. yn(c.cancelform) .. "    /tm (징표): " .. yn(c.tm))
  add("")
  add("|cffffd100■ 템플릿 주문|r " .. DIM .. "(게임이 이름을 모르는 주문은 목록에서 빠집니다)|r")
  local missing, total = {}, 0
  for _, class in ipairs(ns.ClassOrder) do
    for _, t in ipairs(ns.Templates[class] or {}) do
      for _, p in ipairs(t.params) do
        for _, id in ipairs(p.spells or {}) do
          total = total + 1
          if not ns.SpellInfo(id) then missing[#missing + 1] = ("%s %s: %d"):format(ns.ClassShort[class], t.title, id) end
        end
      end
    end
  end
  if #missing == 0 then
    add(("  %s모든 주문(%d개)의 이름을 받았습니다.|r"):format(OK, total))
  else
    add(("  %s이름을 못 받은 주문 %d개|r (스샷을 보내 주세요)"):format(NG, #missing))
    for i = 1, math.min(#missing, 30) do add("   · " .. missing[i]) end
  end
  add("")
  local my = ns.PlayerClass()
  local usable, n = 0, 0
  for _, t in ipairs(ns.Templates[my] or {}) do
    n = n + 1
    if ns.TemplateUsable(t) then usable = usable + 1 end
  end
  add(("|cffffd100■ 내 직업 (%s)|r  지금 쓸 수 있는 템플릿 %d / %d"):format(ns.ClassNames[my] or tostring(my), usable, n))
  add(DIM .. "  배우지 않은 주문만 쓰는 템플릿은 목록에서 흐리게 보입니다.|r")
  showReport(L)
end

-- 명령어 / 이벤트 -----------------------------------------------------------------------

local function showHelp()
  say("버전 " .. ns.versionText())
  local lines = {
    "|cffffd100템플릿을 골라 빈칸만 채우면 매크로를 만들어 줍니다.|r",
    "  " .. KEY .. "/매공|r            창 열기/닫기",
    "  " .. KEY .. "/매공 검사|r       이 클라이언트에서 되는 매크로 기능 검사 (결과 창)",
    "  " .. KEY .. "/매공 초기화|r     창 위치 되돌리기",
    "  " .. KEY .. "/매공 도움말|r     이 안내",
    "  영어: " .. KEY .. "/mk|r, " .. KEY .. "/macrokit|r",
    "|cffffd100순서:|r 직업 탭 → 템플릿 고르기 → 빈칸 채우기 → [등록] → 아이콘을 단축바로 끌기",
    "|cffffd100단축키:|r ESC > 설정 > 단축키 > 매크로 공방 에서 지정할 수 있습니다.",
  }
  for _, l in ipairs(lines) do print(ns.TAG .. l) end
end

local function slash(msg)
  msg = strtrim(msg or "")
  local lower = msg:lower()
  if msg == "" then
    MacroKit_Toggle()
  elseif lower == "도움말" or lower == "help" or lower == "?" then
    showHelp()
  elseif lower == "검사" or lower == "check" then
    ns.RunCheck()
  elseif lower == "초기화" or lower == "reset" then
    MacroKitDB.point = nil
    f:ClearAllPoints()
    f:SetPoint("CENTER")
    say("창 위치를 되돌렸습니다.")
  else
    say(NG .. "모르는 명령입니다: " .. msg .. "|r  " .. KEY .. "/매공 도움말|r")
  end
end

SLASH_MACROKIT1 = "/매공"
SLASH_MACROKIT2 = "/매크로공방"
SLASH_MACROKIT3 = "/mk"
SLASH_MACROKIT4 = "/macrokit"
SlashCmdList.MACROKIT = slash

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("UPDATE_MACROS")
ev:RegisterEvent("SPELLS_CHANGED")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    MacroKitDB = MacroKitDB or {}
    MacroKitDB.owned = MacroKitDB.owned or {}
    MacroKitCharDB = MacroKitCharDB or {}
    MacroKitCharDB.owned = MacroKitCharDB.owned or {}
    f:ClearAllPoints()
    local p = MacroKitDB.point
    if p then f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else f:SetPoint("CENTER") end
  elseif event == "PLAYER_LOGIN" then
    ns.DetectCaps()
    if not MacroKitDB.welcomed then
      MacroKitDB.welcomed = true
      say("설치 감사합니다! " .. KEY .. "/매공|r 으로 창을 열어 템플릿을 고르면 매크로를 만들어 줍니다. 사용법: " .. KEY .. "/매공 도움말|r")
    else
      say("버전 " .. ns.versionText() .. " 로드됨. 열기: " .. KEY .. "/매공|r")
    end
  elseif f:IsShown() then
    if state.class == "MINE" then
      refreshMine()
    elseif event == "SPELLS_CHANGED" then
      refreshList()
      refreshRight()
    else
      refreshRight()
    end
  end
end)
