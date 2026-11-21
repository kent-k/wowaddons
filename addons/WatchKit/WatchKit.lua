-- 표시판 (WatchKit) — 판단하지 않고 "보여 주기만" 하는 아이콘 줄 + 단축바 버튼 반짝임
-- 최신 엔진은 애드온이 전투 값을 숫자로 판단하는 것은 막지만, 화면 위젯에 그대로 넘겨 보여 주는 것은 허용한다.
-- 그래서 쿨다운·버프 시간은 위젯(쿨다운 회전)에 넘기기만 하고, 비밀 값이면 비교하지 않는다.
--
-- 항목 종류 (e.t)
--   spell   : 기술. 쿨다운 회전, 쓸 수 없으면 어둡게
--   buff    : 내 버프 이름. 있으면 밝게 + 남은 시간, 없으면 어둡게 + 반짝
--   auto    : 자동 반복(마법봉 사격 5019, 자동 사격 75, 자동 공격 6603). 켜져 있으면 밝게, 전투 중 꺼져 있으면 반짝
--   item    : 아이템. 개수와 쿨다운, 0개면 어둡게
--   enchant : 무기 강화(독·숫돌 등). e.slot = "main"|"off". 있으면 밝게 + 남은 시간, 없으면 반짝

local ADDON, ns = ...
local TAG = "|cffffd100[표시판]|r "
local OK, NG, DIM, KEY = "|cff44ff44", "|cffff5555", "|cffaaaaaa", "|cffffff00"
local function say(msg) print(TAG .. msg) end
ns.say, ns.TAG, ns.OK, ns.NG, ns.DIM, ns.KEY = say, TAG, OK, NG, DIM, KEY

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.VERSION = getMeta(ADDON, "Version") or "?"

local secret = issecretvalue or function() return false end
ns.secret = secret

ns.AUTO = { [5019] = true, [75] = true, [6603] = true } -- 사격(마법봉), 자동 사격, 자동 공격
local WAND_SLOT = 18

-- API 감싸기 (새/옛 이름) -------------------------------------------------------------

function ns.SpellName(id)
  if not id then return nil end
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  if C_Spell and C_Spell.GetSpellInfo then local i = C_Spell.GetSpellInfo(id) return i and i.name end
  return GetSpellInfo and (GetSpellInfo(id))
end
function ns.SpellIcon(id)
  if not id then return nil end
  if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
  if GetSpellTexture then return GetSpellTexture(id) end
  return GetSpellInfo and select(3, GetSpellInfo(id))
end
function ns.ItemName(id)
  if C_Item and C_Item.GetItemNameByID then local n = C_Item.GetItemNameByID(id) if n then return n end end
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  return f and (f(id)) or ("아이템 #" .. tostring(id))
end
function ns.ItemIcon(id)
  if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
  if GetItemIcon then return GetItemIcon(id) end
  local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  return f and select(5, f(id))
end
local itemCount = (C_Item and C_Item.GetItemCount) or GetItemCount
local itemCD = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown

local function findBuff(name)
  if not name then return nil end
  if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
    local ok, a = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
    if ok then return a end
    return nil
  end
  if AuraUtil and AuraUtil.FindAuraByName then
    local n, icon, count, _, duration, expirationTime = AuraUtil.FindAuraByName(name, "player", "HELPFUL")
    if n then return { name = n, icon = icon, applications = count, duration = duration, expirationTime = expirationTime } end
    return nil
  end
  for i = 1, 40 do
    local n, icon, count, _, duration, expirationTime = UnitBuff("player", i)
    if not n then break end
    if n == name then return { name = n, icon = icon, applications = count, duration = duration, expirationTime = expirationTime } end
  end
end

-- 위젯에 넘기기만 한다. 비밀 값이면 산수를 못 하므로 "기간 객체" API 를 먼저 쓴다
local function cdSet(cd, start, dur)
  if not start then cd:Clear() return end
  if not pcall(cd.SetCooldown, cd, start, dur) then cd:Clear() end
end
local function cdFromDuration(cd, getter, ...)
  if getter and cd.SetCooldownFromDurationObject then
    local ok, d = pcall(getter, ...)
    if ok and d and pcall(cd.SetCooldownFromDurationObject, cd, d) then return true end
  end
  return false
end

-- 상태 -------------------------------------------------------------------------------

local state = { repeating = false, melee = false, idleSince = nil }

local function attackableTarget()
  if not UnitExists("target") then return false end
  local ok1, can = pcall(UnitCanAttack, "player", "target")
  local ok2, dead = pcall(UnitIsDeadOrGhost, "target")
  if not ok1 or not ok2 or secret(can) or secret(dead) then return false end
  return can and not dead
end

local function busyCasting()
  return (UnitCastingInfo and UnitCastingInfo("player")) or (UnitChannelInfo and UnitChannelInfo("player"))
end

-- 항목 하나의 지금 상태: lit(밝게), attention(반짝), count(숫자 글자)
-- lit 가 nil 이면 "모름" — 바꾸지 않는다
function ns.Evaluate(e)
  if e.t == "auto" then
    local on = (e.id == 6603) and state.melee or state.repeating
    local need = false
    if not on and InCombatLockdown() and attackableTarget() and not busyCasting() then
      if e.id ~= 5019 or GetInventoryItemID("player", WAND_SLOT) then
        state.idleSince = state.idleSince or GetTime()
        need = GetTime() - state.idleSince >= (ns.db.grace or 1.5)
      end
    end
    return on, need
  elseif e.t == "buff" then
    local a = findBuff(e.name)
    return a ~= nil, a == nil
  elseif e.t == "enchant" then
    local ok, hasMain, mainMs, _, _, hasOff, offMs = pcall(GetWeaponEnchantInfo)
    if not ok then return nil, false end
    local has, ms = hasMain, mainMs
    if e.slot == "off" then has, ms = hasOff, offMs end
    if secret(has) then return nil, false end
    local left
    if has and ms and not secret(ms) and ms > 0 then left = math.ceil(ms / 60000) .. "분" end
    return has and true or false, not has, left
  elseif e.t == "item" then
    local n = itemCount and itemCount(e.id, false, true) or 0
    if secret(n) then return nil, false, nil end
    return n > 0, false, n
  else -- spell
    local f = (C_Spell and C_Spell.IsSpellUsable) or IsUsableSpell
    if not f then return true, false end
    local ok, usable = pcall(f, e.id)
    if not ok or secret(usable) then return nil, false end
    return usable and true or false, false
  end
end

-- 쿨다운/남은 시간 위젯 채우기 (이벤트 때만)
function ns.FillCooldown(e, cd)
  if e.t == "spell" then
    if cdFromDuration(cd, C_Spell and C_Spell.GetSpellCooldownDuration, e.id) then return end
    if C_Spell and C_Spell.GetSpellCooldown then
      local ok, i = pcall(C_Spell.GetSpellCooldown, e.id)
      if ok and i then cdSet(cd, i.startTime, i.duration) return end
    elseif GetSpellCooldown then
      cdSet(cd, GetSpellCooldown(e.id)) return
    end
    cd:Clear()
  elseif e.t == "item" then
    if itemCD then
      local ok, s, d = pcall(itemCD, e.id)
      if ok then cdSet(cd, s, d) return end
    end
    cd:Clear()
  elseif e.t == "buff" then
    local a = findBuff(e.name)
    if not a then cd:Clear() return end
    if a.auraInstanceID and cdFromDuration(cd, C_UnitAuras and C_UnitAuras.GetAuraDuration, "player", a.auraInstanceID) then return end
    local ok = pcall(function()
      if a.duration and a.duration > 0 then cd:SetCooldown(a.expirationTime - a.duration, a.duration) else cd:Clear() end
    end)
    if not ok then cd:Clear() end
  else
    cd:Clear()
  end
end

-- 항목 이름/아이콘 ------------------------------------------------------------------

function ns.EntryName(e)
  if e.t == "buff" then return e.name or "?" end
  if e.t == "item" then return ns.ItemName(e.id) end
  if e.t == "enchant" then
    local w = (e.slot == "off") and "보조 무기 강화" or "주 무기 강화"
    return e.id and (w .. " (" .. ns.ItemName(e.id) .. ")") or w
  end
  return ns.SpellName(e.id) or e.name or ("기술 #" .. tostring(e.id))
end

function ns.EntryIcon(e)
  if e.t == "item" then return ns.ItemIcon(e.id) or 134400 end
  if e.t == "enchant" then
    if e.id then return ns.ItemIcon(e.id) or 134400 end
    return GetInventoryItemTexture("player", e.slot == "off" and 17 or 16) or 134400
  end
  if e.t == "buff" then
    if e.icon then return e.icon end
    local a = findBuff(e.name)
    if a and a.icon and not secret(a.icon) then e.icon = a.icon return a.icon end
    if e.id then return ns.SpellIcon(e.id) or 134400 end
    local ok, ic = pcall(ns.SpellIcon, e.name)
    return (ok and ic) or 134400
  end
  if e.id == 5019 then return GetInventoryItemTexture("player", WAND_SLOT) or ns.SpellIcon(5019) or 135139 end
  return ns.SpellIcon(e.id) or 134400
end

ns.KIND_TEXT = { spell = "기술", buff = "버프", auto = "자동 반복", item = "아이템", enchant = "무기 강화" }

-- 아이콘 줄 ---------------------------------------------------------------------------

local bar, icons = nil, {}

local function savePos()
  local p, _, rp, x, y = bar:GetPoint()
  ns.db.pos = { p, rp, x, y }
end

local function buildBar()
  bar = CreateFrame("Frame", "WatchKitBar", UIParent)
  bar:SetSize(40, 40)
  bar:SetClampedToScreen(true)
  bar:SetMovable(true)
  bar:SetFrameStrata("MEDIUM")
  local p = ns.db.pos
  if p then bar:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else bar:SetPoint("CENTER", UIParent, "CENTER", 0, -160) end
  bar.handle = CreateFrame("Frame", nil, bar)
  bar.handle:SetAllPoints()
  bar.handle:EnableMouse(true)
  bar.handle:RegisterForDrag("LeftButton")
  bar.handle:SetScript("OnDragStart", function() bar:StartMoving() end)
  bar.handle:SetScript("OnDragStop", function() bar:StopMovingOrSizing() savePos() end)
  local bg = bar.handle:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.2, 0.6, 1, 0.25)
  bar.handle.label = bar.handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bar.handle.label:SetPoint("BOTTOM", bar.handle, "TOP", 0, 2)
  bar.handle.label:SetText("표시판 — 끌어서 옮기기, /표시판 잠금")
end

local function makeIcon(i)
  local b = CreateFrame("Frame", nil, bar)
  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetAllPoints()
  b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints()
  if b.cd.SetDrawEdge then b.cd:SetDrawEdge(false) end
  if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(false) end
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.count:SetPoint("BOTTOMRIGHT", -1, 2)
  b.edge = b:CreateTexture(nil, "OVERLAY")
  b.edge:SetPoint("TOPLEFT", -3, 3)
  b.edge:SetPoint("BOTTOMRIGHT", 3, -3)
  b.edge:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  b.edge:SetBlendMode("ADD")
  b.edge:SetVertexColor(1, 0.25, 0.25)
  b.edge:Hide()
  b:EnableMouse(true)
  b:SetScript("OnEnter", function(self)
    local e = self.entry
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(ns.EntryName(e))
    GameTooltip:AddLine(ns.KIND_TEXT[e.t] or e.t, 0.7, 0.7, 0.7)
    GameTooltip:AddLine("설정: /표시판", 0.5, 0.5, 0.5)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  icons[i] = b
  return b
end

function ns.LayoutBar()
  if not bar then buildBar() end
  local list = ns.char.list
  local size, gap = ns.db.size or 36, 4
  for i, e in ipairs(list) do
    local b = icons[i] or makeIcon(i)
    b.entry = e
    b:SetSize(size, size)
    b:ClearAllPoints()
    b:SetPoint("LEFT", bar, "LEFT", (i - 1) * (size + gap), 0)
    b.tex:SetTexture(ns.EntryIcon(e))
    b:Show()
    ns.FillCooldown(e, b.cd)
  end
  for i = #list + 1, #icons do icons[i]:Hide() icons[i].entry = nil end
  local n = math.max(#list, 1)
  bar:SetSize(n * size + (n - 1) * gap, size)
  bar.handle:SetShown(not ns.db.locked)
  ns.UpdateBarVisible()
end

function ns.UpdateBarVisible()
  if not bar then return end
  local want = ns.db.showBar ~= false and (#ns.char.list > 0 or not ns.db.locked)
  if want and ns.db.combatOnly and ns.db.locked and not InCombatLockdown() then want = false end
  bar:SetShown(want)
end

function ns.RefreshCooldowns()
  for _, b in ipairs(icons) do
    if b.entry and b:IsShown() then ns.FillCooldown(b.entry, b.cd) end
  end
end

-- 단축바 버튼 반짝임 ------------------------------------------------------------------

local BAR_PREFIX = {
  "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
  "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}
local glows = {}       -- 버튼 -> 반짝 프레임
local buttonsFor = {}  -- 항목 -> { 버튼, ... }

local function actionOf(btn)
  local a = btn.action
  if not a and btn.GetAttribute then a = btn:GetAttribute("action") end
  if (not a or a == 0) and ActionButton_GetPagedID then a = ActionButton_GetPagedID(btn) end
  return a
end

-- 버튼에 놓인 것: "spell", 이름 / "item", 번호
local function buttonContent(btn)
  local slot = actionOf(btn)
  if not slot or not HasAction(slot) then return nil end
  local kind, id = GetActionInfo(slot)
  if kind == "spell" then return "spell", ns.SpellName(id), id end
  if kind == "item" then return "item", nil, id end
  if kind == "macro" then
    local sid = GetMacroSpell and GetMacroSpell(id)
    if sid then return "spell", ns.SpellName(sid), sid end
    local _, link = GetMacroItem and GetMacroItem(id)
    local iid = link and tonumber(link:match("item:(%d+)"))
    if iid then return "item", nil, iid end
  end
end

local function matches(e, kind, name, id)
  if e.t == "item" then return kind == "item" and id == e.id end
  if e.t == "enchant" then return e.id and kind == "item" and id == e.id end
  if kind ~= "spell" then return false end
  if e.id and id == e.id then return true end
  local en = (e.t == "buff") and e.name or ns.SpellName(e.id)
  return en ~= nil and name == en
end

local function glowFor(btn)
  local g = glows[btn]
  if g then return g end
  g = CreateFrame("Frame", nil, btn)
  g:SetPoint("TOPLEFT", -6, 6)
  g:SetPoint("BOTTOMRIGHT", 6, -6)
  g:SetFrameLevel(btn:GetFrameLevel() + 5)
  local t = g:CreateTexture(nil, "OVERLAY")
  t:SetAllPoints()
  t:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  t:SetBlendMode("ADD")
  t:SetVertexColor(1, 0.85, 0.2)
  g:Hide()
  local acc = 0
  g:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt
    self:SetAlpha(0.45 + 0.55 * math.abs(math.sin(acc * 4)))
  end)
  glows[btn] = g
  return g
end

local scanPending = false
function ns.ScanButtons()
  if InCombatLockdown() then scanPending = true return end -- 보호된 버튼에 자식 프레임은 전투 밖에서 만든다
  scanPending = false
  wipe(buttonsFor)
  for _, g in pairs(glows) do g:Hide() end
  for _, e in ipairs(ns.char.list) do buttonsFor[e] = {} end
  for _, prefix in ipairs(BAR_PREFIX) do
    for i = 1, 12 do
      local btn = _G[prefix .. i]
      if btn and btn:IsVisible() then
        local kind, name, id = buttonContent(btn)
        if kind then
          for _, e in ipairs(ns.char.list) do
            if e.glow ~= false and matches(e, kind, name, id) then
              local l = buttonsFor[e]
              l[#l + 1] = btn
              glowFor(btn)
            end
          end
        end
      end
    end
  end
end

function ns.ScanPendingAfterCombat()
  if scanPending then ns.ScanButtons() end
end

-- 매 0.2초: 밝기·반짝 ----------------------------------------------------------------

local function tick()
  local list = ns.char.list
  local anyAuto = false
  local lit = {}
  for i, e in ipairs(list) do
    local on, need, count = ns.Evaluate(e)
    if e.t == "auto" then anyAuto = anyAuto or need or false end
    local b = icons[i]
    if b and b:IsShown() then
      if on ~= nil then
        b.tex:SetDesaturated(not on)
        b:SetAlpha(on and 1 or 0.4)
      end
      b.edge:SetShown(need and true or false)
      if count then b.count:SetText(count) else b.count:SetText("") end
    end
    if ns.db.glow ~= false and need then
      for _, btn in ipairs(buttonsFor[e] or {}) do lit[btn] = true end
    end
  end
  -- 자동 반복이 다시 켜지거나 조건이 풀리면 "놀기 시작 시각" 을 지운다
  if not anyAuto and (state.repeating or not InCombatLockdown() or not attackableTarget() or busyCasting()) then
    state.idleSince = nil
  end
  for btn, g in pairs(glows) do g:SetShown(lit[btn] and btn:IsVisible() or false) end
end

-- 이벤트 ------------------------------------------------------------------------------

local ev = CreateFrame("Frame")
local acc = 0
ev:SetScript("OnUpdate", function(_, dt)
  acc = acc + dt
  if acc < 0.2 or not ns.char then return end
  acc = 0
  tick()
end)

local EVENTS = {
  "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
  "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "UNIT_AURA", "UNIT_INVENTORY_CHANGED",
  "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_MACROS",
  "PLAYER_EQUIPMENT_CHANGED",
}
for _, e in ipairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end

local function defaults()
  local _, class = UnitClass("player")
  local list = {}
  if class == "MAGE" or class == "PRIEST" or class == "WARLOCK" then
    list[1] = { t = "auto", id = 5019, glow = true }
  elseif class == "HUNTER" then
    list[1] = { t = "auto", id = 75, glow = true }
  end
  return list
end

local rescanQueued = false
local function queueRescan()
  if rescanQueued then return end
  rescanQueued = true
  C_Timer.After(0.3, function()
    rescanQueued = false
    ns.ScanButtons()
  end)
end
ns.QueueRescan = queueRescan

ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    WatchKitDB = WatchKitDB or {}
    ns.db = WatchKitDB
    WatchKitCharDB = WatchKitCharDB or {}
    ns.char = WatchKitCharDB
    if ns.db.locked == nil then ns.db.locked = true end
    return
  end
  if not ns.char then return end
  if event == "PLAYER_LOGIN" then
    if not ns.char.list then
      ns.char.list = defaults()
      ns.char.fresh = true
    end
    if C_Spell and C_Spell.IsAutoRepeatSpell then
      local ok, v = pcall(C_Spell.IsAutoRepeatSpell, 5019)
      if ok and v and not secret(v) then state.repeating = true end
    end
    ns.LayoutBar()
    queueRescan()
    if not ns.db.welcomed then
      ns.db.welcomed = true
      say("설치 감사합니다! 내 기술·버프·아이템을 아이콘으로 보여 주고, 깜빡한 것은 단축바 버튼을 반짝입니다. 설정: " .. KEY .. "/표시판|r")
      if #ns.char.list > 0 then say("마법봉/자동 사격은 미리 넣어 뒀습니다. 다른 것은 " .. KEY .. "/표시판|r 창에 끌어다 놓으세요.") end
    else
      say("버전 " .. ns.VERSION .. " 로드됨. 설정: " .. KEY .. "/표시판|r")
    end
  elseif event == "START_AUTOREPEAT_SPELL" then
    state.repeating = true state.idleSince = nil
  elseif event == "STOP_AUTOREPEAT_SPELL" then
    state.repeating = false
  elseif event == "PLAYER_ENTER_COMBAT" then
    state.melee = true state.idleSince = nil
  elseif event == "PLAYER_LEAVE_COMBAT" then
    state.melee = false
  elseif event == "PLAYER_REGEN_DISABLED" then
    ns.UpdateBarVisible()
  elseif event == "PLAYER_REGEN_ENABLED" then
    state.idleSince = nil
    ns.UpdateBarVisible()
    ns.ScanPendingAfterCombat()
  elseif event == "UNIT_AURA" then
    if arg1 == "player" then ns.RefreshCooldowns() end
  elseif event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
    if event == "PLAYER_EQUIPMENT_CHANGED" or arg1 == "player" then ns.LayoutBar() end
  elseif event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" or event == "BAG_UPDATE_DELAYED" then
    ns.RefreshCooldowns()
  else -- 단축바가 바뀜
    queueRescan()
  end
end)
