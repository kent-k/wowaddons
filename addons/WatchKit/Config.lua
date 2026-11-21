-- 표시판 설정 창과 명령어
local _, ns = ...
local say, OK, NG, DIM, KEY = ns.say, ns.OK, ns.NG, ns.DIM, ns.KEY

local MAX = 16

local function changed()
  ns.LayoutBar()
  ns.QueueRescan()
  if ns.RefreshConfig then ns.RefreshConfig() end
end

local function same(a, b)
  return a.t == b.t and a.id == b.id and a.name == b.name and a.slot == b.slot
end

function ns.AddEntry(e)
  local list = ns.char.list
  for _, x in ipairs(list) do
    if same(x, e) then say(ns.EntryName(e) .. " 은(는) 이미 있습니다.") return false end
  end
  if #list >= MAX then say(NG .. "최대 " .. MAX .. "개까지입니다.|r") return false end
  if e.glow == nil then e.glow = true end
  list[#list + 1] = e
  say(OK .. "추가:|r " .. ns.EntryName(e) .. " " .. DIM .. "(" .. ns.KIND_TEXT[e.t] .. ")|r")
  changed()
  return true
end

-- 커서에 들고 있는 것(주문책·가방·단축바에서 끌어온 것)을 항목으로
local function entryFromCursor()
  local kind, a, b, c = GetCursorInfo()
  if kind == "spell" then
    local id = c
    if not id and C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
      local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, a, b)
      id = ok and info and (info.spellID or info.actionID)
    end
    if not id and GetSpellBookItemInfo then id = select(2, GetSpellBookItemInfo(a, b)) end
    if not id then return nil end
    return { t = ns.AUTO[id] and "auto" or "spell", id = id, src = "spell" }
  elseif kind == "item" then
    return { t = "item", id = a, src = "item" }
  elseif kind == "macro" then
    local sid = GetMacroSpell and GetMacroSpell(a)
    if sid then return { t = ns.AUTO[sid] and "auto" or "spell", id = sid, src = "spell" } end
    local _, link = GetMacroItem and GetMacroItem(a)
    local iid = link and tonumber(link:match("item:(%d+)"))
    if iid then return { t = "item", id = iid, src = "item" } end
  end
end

-- 종류 바꾸기: 기술 → 버프 → (자동 반복) / 아이템 → 주 무기 강화 → 보조 무기 강화
local function cycleKind(e)
  if e.src == "spell" then
    if e.t == "spell" then
      e.t, e.name, e.icon = "buff", ns.SpellName(e.id), nil
    elseif e.t == "buff" and ns.AUTO[e.id] then
      e.t = "auto"
    else
      e.t = "spell"
    end
  elseif e.src == "item" then
    if e.t == "item" then e.t, e.slot = "enchant", "main"
    elseif e.slot == "main" then e.slot = "off"
    else e.t, e.slot = "item", nil end
  end
end

-- 창 -------------------------------------------------------------------------------

local frame, rows = nil, {}

local function check(parent, x, y, label, get, set)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", x, y)
  local t = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  t:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  t:SetText(label)
  cb.refresh = function() cb:SetChecked(get() and true or false) end
  cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  return cb
end

local function button(parent, w, text, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function makeRow(i)
  local r = CreateFrame("Frame", nil, frame)
  r:SetSize(420, 26)
  r:SetPoint("TOPLEFT", 16, -196 - (i - 1) * 28)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(22, 22)
  r.icon:SetPoint("LEFT")
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
  r.name:SetWidth(170)
  r.name:SetJustifyH("LEFT")
  r.name:SetWordWrap(false)
  r.kind = button(r, 92, "", function()
    cycleKind(r.entry)
    changed()
  end)
  r.kind:SetPoint("LEFT", r.name, "RIGHT", 4, 0)
  r.glow = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
  r.glow:SetSize(22, 22)
  r.glow:SetPoint("LEFT", r.kind, "RIGHT", 4, 0)
  r.glow:SetScript("OnClick", function(self)
    r.entry.glow = self:GetChecked() and true or false
    ns.QueueRescan()
  end)
  r.glow:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("단축바 버튼 반짝")
    GameTooltip:AddLine("깜빡했을 때 이 항목의 단축바 버튼을 반짝입니다.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  r.glow:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r.up = button(r, 24, "▲", function()
    local l, k = ns.char.list, r.index
    if k > 1 then l[k], l[k - 1] = l[k - 1], l[k] changed() end
  end)
  r.up:SetPoint("LEFT", r.glow, "RIGHT", 2, 0)
  r.down = button(r, 24, "▼", function()
    local l, k = ns.char.list, r.index
    if k < #l then l[k], l[k + 1] = l[k + 1], l[k] changed() end
  end)
  r.down:SetPoint("LEFT", r.up, "RIGHT", 0, 0)
  r.del = button(r, 24, "X", function()
    table.remove(ns.char.list, r.index)
    changed()
  end)
  r.del:SetPoint("LEFT", r.down, "RIGHT", 4, 0)
  rows[i] = r
  return r
end

local function build()
  frame = CreateFrame("Frame", "WatchKitFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(460, 240)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("HIGH")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  tinsert(UISpecialFrames, "WatchKitFrame")
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -5)
  title:SetText("표시판  " .. DIM .. ns.VERSION .. "|r")

  -- 켜기/끄기
  frame.checks = {
    check(frame, 14, -30, "아이콘 줄 보이기", function() return ns.db.showBar ~= false end,
      function(v) ns.db.showBar = v ns.UpdateBarVisible() end),
    check(frame, 14, -54, "깜빡하면 단축바 버튼 반짝이기", function() return ns.db.glow ~= false end,
      function(v) ns.db.glow = v end),
    check(frame, 240, -30, "아이콘 줄은 전투 중에만", function() return ns.db.combatOnly end,
      function(v) ns.db.combatOnly = v ns.UpdateBarVisible() end),
  }
  frame.lock = button(frame, 110, "", function()
    ns.db.locked = not ns.db.locked
    ns.LayoutBar()
    ns.RefreshConfig()
  end)
  frame.lock:SetPoint("TOPLEFT", 244, -56)
  local minus = button(frame, 24, "-", function() ns.db.size = math.max(20, (ns.db.size or 36) - 4) ns.LayoutBar() end)
  minus:SetPoint("LEFT", frame.lock, "RIGHT", 8, 0)
  local plus = button(frame, 24, "+", function() ns.db.size = math.min(64, (ns.db.size or 36) + 4) ns.LayoutBar() end)
  plus:SetPoint("LEFT", minus, "RIGHT", 0, 0)
  local sz = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sz:SetPoint("LEFT", plus, "RIGHT", 4, 0)
  sz:SetText("크기")

  -- 끌어 놓는 칸
  local drop = CreateFrame("Button", nil, frame, "BackdropTemplate")
  drop:SetPoint("TOPLEFT", 16, -86)
  drop:SetSize(428, 40)
  if drop.SetBackdrop then
    drop:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    drop:SetBackdropColor(0.1, 0.3, 0.5, 0.5)
  end
  local dt = drop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  dt:SetPoint("CENTER")
  dt:SetText("여기에 기술·아이템을 끌어다 놓기  " .. DIM .. "(주문책·가방·단축바에서)|r")
  local function onDrop()
    local e = entryFromCursor()
    if e then
      ClearCursor()
      ns.AddEntry(e)
    elseif GetCursorInfo() then
      say(NG .. "이건 넣을 수 없습니다.|r 기술·아이템·매크로만 됩니다.")
      ClearCursor()
    end
  end
  drop:SetScript("OnReceiveDrag", onDrop)
  drop:SetScript("OnClick", onDrop)

  -- 버프 이름 직접 넣기 (다른 사람이 걸어 주는 버프 등)
  local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  lbl:SetPoint("TOPLEFT", 18, -138)
  lbl:SetText("버프 이름:")
  local eb = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  eb:SetSize(150, 20)
  eb:SetPoint("LEFT", lbl, "RIGHT", 10, 0)
  eb:SetAutoFocus(false)
  local function addBuff()
    local n = strtrim(eb:GetText() or "")
    if n == "" then return end
    if ns.AddEntry({ t = "buff", name = n, src = "name" }) then eb:SetText("") end
    eb:ClearFocus()
  end
  eb:SetScript("OnEnterPressed", addBuff)
  eb:SetScript("OnEscapePressed", eb.ClearFocus)
  local add = button(frame, 50, "추가", addBuff)
  add:SetPoint("LEFT", eb, "RIGHT", 6, 0)
  local wm = button(frame, 70, "주 무기", function() ns.AddEntry({ t = "enchant", slot = "main", src = "slot" }) end)
  wm:SetPoint("LEFT", add, "RIGHT", 10, 0)
  local wo = button(frame, 70, "보조 무기", function() ns.AddEntry({ t = "enchant", slot = "off", src = "slot" }) end)
  wo:SetPoint("LEFT", wm, "RIGHT", 0, 0)
  local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 18, -162)
  hint:SetWidth(426)
  hint:SetJustifyH("LEFT")
  hint:SetText("[종류] 를 누르면 바뀝니다: 기술 ↔ 버프(내게 걸렸는지) / 아이템 ↔ 무기 강화(독·숫돌).  무기 강화 버튼은 독·숫돌 없이 무기만 볼 때.")

  frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  frame.empty:SetPoint("TOPLEFT", 18, -200)
  frame.empty:SetText("아직 아무것도 없습니다. 위 칸에 기술이나 아이템을 끌어다 놓으세요.")
end

function ns.RefreshConfig()
  if not frame or not frame:IsShown() then return end
  for _, cb in ipairs(frame.checks) do cb.refresh() end
  frame.lock:SetText(ns.db.locked and "줄 옮기기" or (OK .. "옮기기 끝|r"))
  local list = ns.char.list
  for i, e in ipairs(list) do
    local r = rows[i] or makeRow(i)
    r.entry, r.index = e, i
    r.icon:SetTexture(ns.EntryIcon(e))
    r.name:SetText(ns.EntryName(e))
    local kt = ns.KIND_TEXT[e.t]
    if e.t == "enchant" then kt = (e.slot == "off") and "보조 무기 강화" or "주 무기 강화" end
    r.kind:SetText(kt)
    r.kind:SetEnabled(e.src == "spell" or e.src == "item")
    r.glow:SetChecked(e.glow ~= false)
    r:Show()
  end
  for i = #list + 1, #rows do rows[i]:Hide() end
  frame.empty:SetShown(#list == 0)
  frame:SetHeight(196 + math.max(#list, 1) * 28 + 24)
end

function WatchKit_Toggle()
  if not frame then build() end
  frame:SetShown(not frame:IsShown())
  ns.RefreshConfig()
end
BINDING_HEADER_WATCHKIT = "표시판"
BINDING_NAME_WATCHKIT_TOGGLE = "표시판 설정 열기/닫기"

-- 명령어 ----------------------------------------------------------------------------

local function onoff(v) return v and (OK .. "켬|r") or (NG .. "끔|r") end

local function help()
  say("버전 " .. ns.VERSION .. " — 내 기술·버프·아이템을 아이콘으로 보여 주고, 깜빡한 것은 단축바 버튼을 반짝입니다.")
  print(ns.TAG .. "  " .. KEY .. "/표시판|r         설정 창 (끌어다 놓아 추가)")
  print(ns.TAG .. "  " .. KEY .. "/표시판 줄|r      아이콘 줄 켜기/끄기  지금 " .. onoff(ns.db.showBar ~= false))
  print(ns.TAG .. "  " .. KEY .. "/표시판 반짝|r    단축바 버튼 반짝임 켜기/끄기  지금 " .. onoff(ns.db.glow ~= false))
  print(ns.TAG .. "  " .. KEY .. "/표시판 잠금|r    아이콘 줄 옮기기 시작/끝")
  print(ns.TAG .. "  " .. KEY .. "/표시판 버프 이름|r  버프 이름으로 추가 (예: /표시판 버프 신의 권능: 인내)")
  print(ns.TAG .. "  밝음 = 켜져 있음/있음, 어두움 = 꺼짐/없음, 빨간 테두리 + 단축바 반짝 = 깜빡한 것")
end

SLASH_WATCHKIT1 = "/표시판"
SLASH_WATCHKIT2 = "/wk"
SLASH_WATCHKIT3 = "/watchkit"
SlashCmdList.WATCHKIT = function(msg)
  msg = strtrim(msg or "")
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    WatchKit_Toggle()
  elseif cmd == "줄" or cmd == "bar" then
    ns.db.showBar = (ns.db.showBar == false)
    ns.UpdateBarVisible()
    say("아이콘 줄: " .. onoff(ns.db.showBar))
    ns.RefreshConfig()
  elseif cmd == "반짝" or cmd == "glow" then
    ns.db.glow = (ns.db.glow == false)
    say("단축바 버튼 반짝임: " .. onoff(ns.db.glow))
    ns.RefreshConfig()
  elseif cmd == "잠금" or cmd == "lock" then
    ns.db.locked = not ns.db.locked
    ns.LayoutBar()
    say(ns.db.locked and "아이콘 줄을 잠갔습니다." or "아이콘 줄을 끌어서 옮기세요. 끝나면 다시 " .. KEY .. "/표시판 잠금|r")
    ns.RefreshConfig()
  elseif (cmd == "버프" or cmd == "buff") and rest ~= "" then
    ns.AddEntry({ t = "buff", name = rest, src = "name" })
  else
    help()
  end
end
