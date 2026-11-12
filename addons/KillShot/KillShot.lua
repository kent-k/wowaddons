-- 킬각 (KillShot)
-- 내 대상의 남은 체력보다 한 방 데미지가 큰 스킬이 단축바에 있으면 그 버튼을 초록색으로 반짝이게 한다.
-- 데미지는 전투 기록에서 배운 실제 직접 피해(도트 제외)를 우선 쓰고, 없으면 툴팁 숫자로 추정한다.

local ADDON = ...
local TAG = "|cffffd100[킬각]|r "
local OK, NG, DIM, KEY = "|cff44ff44", "|cffff5555", "|cffaaaaaa", "|cffffff00"
local function say(msg) print(TAG .. msg) end

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local VERSION = getMeta(ADDON, "Version") or "?"
local function versionText()
  if VERSION:find("@project%-version@") then return NG .. "빌드 안 됨|r" end
  return OK .. VERSION .. "|r"
end

local MAX_SAMPLES = 20
local IGNORE = { [75] = true, [5019] = true, [6603] = true }   -- 자동 사격, 마법봉 사격, 공격
local db, cdb                                                 -- KillShotDB (공용 설정), KillShotCharDB (캐릭터별 기록)

local function spellInfo(id)
  if C_Spell and C_Spell.GetSpellInfo then
    local i = C_Spell.GetSpellInfo(id)
    if i then return i.name, i.iconID end
  end
  if GetSpellInfo then
    local name, _, icon = GetSpellInfo(id)
    return name, icon
  end
end

-- 1. 전투 기록에서 배우기 ----------------------------------------------------------

local playerGUID
local ignoreNames = {}

local function record(key, amount)
  local list = cdb.hits[key]
  if not list then list = {} cdb.hits[key] = list end
  list[#list + 1] = amount
  while #list > MAX_SAMPLES do table.remove(list, 1) end
end

local function onCombatLog()
  local _, sub, _, src, _, _, _, _, _, _, _, spellId, spellName, _, amount, _, _, _, _, _, critical, glancing = CombatLogGetCurrentEventInfo()
  if src ~= playerGUID then return end
  if sub ~= "SPELL_DAMAGE" and sub ~= "RANGE_DAMAGE" then return end   -- 지속 피해(PERIODIC)는 안 받음 = 도트 제외
  if critical or glancing or not amount or amount <= 0 then return end
  if IGNORE[spellId] or ignoreNames[spellName] then return end
  if spellId and spellId > 0 then record(spellId, amount) end
  if spellName then record(spellName, amount) end
end

-- 기록 → 확정 킬 값 (치명타 제외, 낮은 쪽)
local function learned(id, name)
  local list = (id and cdb.hits[id]) or (name and cdb.hits[name])
  if not list or #list == 0 then return nil end
  local s = {}
  for i, v in ipairs(list) do s[i] = v end
  table.sort(s)
  if #s >= 5 then return s[math.ceil(#s * 0.2)], #s end
  return s[1], #s
end

-- 2. 툴팁으로 추정 ---------------------------------------------------------------

local tip = CreateFrame("GameTooltip", "KillShotScanTip", nil, "GameTooltipTemplate")
tip:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
local tipCache = {}

-- 한 줄에서 직접 피해 최솟값 찾기. 도트("~초에 걸쳐 ... 피해")면 nil
local function parseLine(text)
  if not text or not text:find("피해") then return nil end
  local a, b, lo = text:find("(%d+)%s*~%s*%d+")
  if not a then a, b, lo = text:find("(%d+)의 [^%d]-피해") end
  if not a then return nil end
  local before = text:sub(1, a - 1)
  if before:find("걸쳐") then return nil end   -- 지속 피해 설명이 먼저 나옴 = 도트
  return tonumber(lo)
end

local function tooltipDamage(id)
  if tipCache[id] ~= nil then return tipCache[id] or nil end
  local value = false
  tip:ClearLines()
  if tip.SetSpellByID then
    tip:SetSpellByID(id)
    for i = 2, tip:NumLines() do
      local fs = _G["KillShotScanTipTextLeft" .. i]
      local v = fs and parseLine(fs:GetText())
      if v then value = v break end
    end
  end
  tipCache[id] = value
  return value or nil
end

-- 스킬 하나의 확정 킬 데미지와 출처 ("log" / "tip")
local function damageOf(id)
  if not id or IGNORE[id] then return nil end
  local name = spellInfo(id)
  if name and ignoreNames[name] then return nil end
  local v, n = learned(id, name)
  if v then return v, "log", n end
  v = tooltipDamage(id)
  if v then return v, "tip" end
end

-- 3. 대상 체력 ------------------------------------------------------------------

-- 남은 체력 (실제 숫자일 때만). 두 번째 값: 상태 설명
local function targetHealth()
  if not UnitExists("target") then return nil, "대상 없음" end
  if not UnitCanAttack("player", "target") then return nil, "공격할 수 없는 대상" end
  if UnitIsDeadOrGhost("target") then return nil, "죽은 대상" end
  local hp, max = UnitHealth("target"), UnitHealthMax("target")
  if not hp or not max or max <= 0 then return nil, "체력 정보 없음" end
  local level = UnitLevel("target") or 0
  if max == 100 and (level >= 10 or level == -1) then
    return nil, "체력이 % 로만 나옴"
  end
  return hp, ("%d / %d"):format(hp, max)
end

-- 4. 단축바 ---------------------------------------------------------------------

local BARS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton" }
local buttons = {}

local function actionSlot(b)
  return b.action or (b.GetPagedID and b:GetPagedID()) or (b.GetAttribute and b:GetAttribute("action"))
end

local function actionSpell(slot)
  if not slot or not HasAction(slot) then return nil end
  local kind, id = GetActionInfo(slot)
  if kind == "spell" then return id end
  if kind == "macro" and GetMacroSpell then
    local s = GetMacroSpell(id)
    return s
  end
end

local function decorate(b)
  if b.killShot then return b.killShot end
  local o = CreateFrame("Frame", nil, b)
  o:SetAllPoints()
  o:SetFrameLevel(b:GetFrameLevel() + 5)
  o.glow = o:CreateTexture(nil, "OVERLAY")
  o.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
  o.glow:SetBlendMode("ADD")
  o.glow:SetVertexColor(0.2, 1, 0.2)
  o.glow:SetPoint("TOPLEFT", -3, 3)
  o.glow:SetPoint("BOTTOMRIGHT", 3, -3)
  o.border = o:CreateTexture(nil, "OVERLAY")
  o.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  o.border:SetBlendMode("ADD")
  o.border:SetVertexColor(0.2, 1, 0.2)
  o.border:SetPoint("CENTER")
  o.border:SetSize(b:GetWidth() * 1.8, b:GetHeight() * 1.8)
  o.num = o:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  o.num:SetPoint("BOTTOM", 0, 2)
  if o.CreateAnimationGroup then
    local ag = o:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0.35)
    a:SetDuration(0.45)
    o.anim = ag
  end
  o:Hide()
  b.killShot = o
  return o
end

local function collectButtons()
  wipe(buttons)
  for _, prefix in ipairs(BARS) do
    for i = 1, 12 do
      local b = _G[prefix .. i]
      if b then
        decorate(b)
        buttons[#buttons + 1] = b
      end
    end
  end
end

local function hideAll()
  for _, b in ipairs(buttons) do
    local o = b.killShot
    if o and o:IsShown() then
      if o.anim then o.anim:Stop() end
      o:Hide()
    end
  end
end

local function update()
  local hp = targetHealth()
  if not hp or not db.enabled then hideAll() return end
  for _, b in ipairs(buttons) do
    local o = b.killShot
    local slot = b:IsVisible() and actionSlot(b)
    local id = slot and actionSpell(slot)
    local dmg, src = damageOf(id)
    local usable = slot and IsUsableAction(slot)
    if dmg and usable and dmg >= hp then
      o.num:SetText(db.showNumber and tostring(dmg) or "")
      o.num:SetTextColor(src == "log" and 1 or 0.7, src == "log" and 1 or 0.7, src == "log" and 1 or 0.7)
      if not o:IsShown() then
        o:Show()
        if o.anim then o.anim:Play() end
      end
    elseif o:IsShown() then
      if o.anim then o.anim:Stop() end
      o:Hide()
    end
  end
end

local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, dt)
  acc = acc + dt
  if acc < 0.1 then return end
  acc = 0
  if UnitExists("target") then update() else hideAll() end
end)

-- 5. 검사 창 ---------------------------------------------------------------------

local report
local function showReport(lines)
  if not report then
    report = CreateFrame("Frame", "KillShotReport", UIParent, "BasicFrameTemplateWithInset")
    report:SetSize(520, 420)
    report:SetPoint("CENTER")
    report:SetFrameStrata("DIALOG")
    report:SetMovable(true)
    report:EnableMouse(true)
    report:RegisterForDrag("LeftButton")
    report:SetScript("OnDragStart", report.StartMoving)
    report:SetScript("OnDragStop", report.StopMovingOrSizing)
    tinsert(UISpecialFrames, "KillShotReport")
    local t = report:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOP", 0, -5)
    t:SetText("킬각 검사 (끌어서 이동, ESC 로 닫기)")
    local sc = CreateFrame("ScrollFrame", nil, report, "UIPanelScrollFrameTemplate")
    sc:SetPoint("TOPLEFT", 12, -30)
    sc:SetPoint("BOTTOMRIGHT", -32, 12)
    local c = CreateFrame("Frame", nil, sc)
    c:SetSize(460, 10)
    sc:SetScrollChild(c)
    report.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    report.text:SetPoint("TOPLEFT")
    report.text:SetWidth(460)
    report.text:SetJustifyH("LEFT")
    report.text:SetSpacing(3)
    report.content = c
  end
  report.text:SetText(table.concat(lines, "\n"))
  report.content:SetHeight(report.text:GetStringHeight() + 10)
  report:Show()
end

local function runCheck()
  local L = {}
  local function add(s) L[#L + 1] = s end
  add("|cffffd100■ 버전|r  " .. versionText() .. "   켜짐: " .. (db.enabled and (OK .. "예|r") or (NG .. "아니오|r")))
  add("")
  add("|cffffd100■ 대상 체력|r")
  local hp, why = targetHealth()
  if hp then
    add("  " .. OK .. "실제 숫자로 받음|r: " .. why .. "  → 킬각 표시 가능")
  else
    add("  " .. NG .. why .. "|r")
    if why == "대상 없음" then add(DIM .. "  아무 적이나 대상으로 잡고 다시 " .. "/킬각 검사|r") end
    if why == "체력이 % 로만 나옴" then add(DIM .. "  이 클라이언트는 몹 체력을 % 로만 줍니다. 킬각을 계산할 수 없습니다.|r") end
  end
  add("")
  add("|cffffd100■ 단축바 스킬 예상 한 방 데미지|r " .. DIM .. "(흰색 = 실전 기록, 회색 = 툴팁 추정)|r")
  local seen, n = {}, 0
  for _, b in ipairs(buttons) do
    local id = actionSpell(actionSlot(b))
    if id and not seen[id] then
      seen[id] = true
      local name = spellInfo(id) or ("주문 " .. id)
      local dmg, src, cnt = damageOf(id)
      if dmg then
        n = n + 1
        if src == "log" then
          add(("  %s: |cffffffff%d|r  (기록 %d번)"):format(name, dmg, cnt))
        else
          add(("  %s: |cffaaaaaa%d|r  (툴팁, 한 번 쓰면 실제 값으로 바뀜)"):format(name, dmg))
        end
      end
    end
  end
  if n == 0 then add(DIM .. "  데미지를 아는 스킬이 아직 없습니다. 몹을 몇 번 때리면 기록됩니다.|r") end
  add("")
  add(DIM .. "도트(지속 피해)와 치명타는 계산에서 뺍니다. 빗나감·저항은 알 수 없습니다.|r")
  showReport(L)
end

-- 6. 명령어 / 시작 ----------------------------------------------------------------

local function showHelp()
  say("버전 " .. versionText())
  local lines = {
    "|cffffd100대상의 남은 체력을 한 방에 깎을 수 있는 스킬을 단축바에서 초록색으로 반짝여 줍니다.|r",
    "  " .. KEY .. "/킬각|r          켜기/끄기 (지금: " .. (db.enabled and (OK .. "켜짐|r") or (NG .. "꺼짐|r")) .. ")",
    "  " .. KEY .. "/킬각 숫자|r     버튼 아래 예상 데미지 숫자 켜기/끄기",
    "  " .. KEY .. "/킬각 검사|r     대상 체력·스킬별 예상 데미지 확인 창",
    "  " .. KEY .. "/킬각 초기화|r   배운 데미지 기록 지우기 (장비를 크게 바꿨을 때)",
    "  " .. KEY .. "/킬각 도움말|r   이 안내    영어: " .. KEY .. "/ks|r",
    DIM .. "데미지는 실제로 넣은 피해(치명타·도트 제외)를 기록해서 씁니다. 처음엔 툴팁 숫자로 추정합니다.|r",
  }
  for _, l in ipairs(lines) do print(TAG .. l) end
end

SLASH_KILLSHOT1 = "/킬각"
SLASH_KILLSHOT2 = "/ks"
SLASH_KILLSHOT3 = "/killshot"
SlashCmdList.KILLSHOT = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "" then
    db.enabled = not db.enabled
    if not db.enabled then hideAll() end
    say("킬각 표시: " .. (db.enabled and (OK .. "켜짐|r") or (NG .. "꺼짐|r")))
  elseif msg == "숫자" or msg == "number" then
    db.showNumber = not db.showNumber
    say("예상 데미지 숫자: " .. (db.showNumber and (OK .. "보임|r") or (NG .. "숨김|r")))
  elseif msg == "검사" or msg == "check" then
    runCheck()
  elseif msg == "초기화" or msg == "reset" then
    wipe(cdb.hits)
    wipe(tipCache)
    say("배운 데미지 기록을 지웠습니다. 다시 싸우면 새로 기록합니다.")
  elseif msg == "도움말" or msg == "help" or msg == "?" then
    showHelp()
  else
    say(NG .. "모르는 명령입니다.|r " .. KEY .. "/킬각 도움말|r")
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
ev:RegisterEvent("SPELLS_CHANGED")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if cdb then onCombatLog() end
  elseif event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    KillShotDB = KillShotDB or {}
    db = KillShotDB
    if db.enabled == nil then db.enabled = true end
    if db.showNumber == nil then db.showNumber = true end
    KillShotCharDB = KillShotCharDB or {}
    cdb = KillShotCharDB
    cdb.hits = cdb.hits or {}
  elseif event == "PLAYER_LOGIN" then
    playerGUID = UnitGUID("player")
    for id in pairs(IGNORE) do
      local n = spellInfo(id)
      if n then ignoreNames[n] = true end
    end
    collectButtons()
    if not db.welcomed then
      db.welcomed = true
      say("설치 감사합니다! 적을 한 방에 잡을 수 있는 스킬이 단축바에서 초록색으로 반짝입니다. 확인: " .. KEY .. "/킬각 검사|r, 사용법: " .. KEY .. "/킬각 도움말|r")
    else
      say("버전 " .. versionText() .. " 로드됨. " .. KEY .. "/킬각 도움말|r")
    end
  elseif event == "SPELLS_CHANGED" then
    wipe(tipCache)   -- 새 등급을 배우면 툴팁 숫자가 바뀐다
  end
end)
