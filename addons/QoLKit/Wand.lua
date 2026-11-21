-- 마법봉 알림: 전투 중 마법봉을 차고 적을 잡고 있는데, 사격도 주문도 안 하고 놀고 있으면 화면 가운데에 크게 알린다
local _, ns = ...
local say, OK, NG, DIM, KEY = ns.say, ns.OK, ns.NG, ns.DIM, ns.KEY

local WAND_CLASS, WAND_SUB = 2, 19 -- 무기 / 마법봉
local RANGED_SLOT = 18
local SHOOT = 5019                 -- 사격(마법봉)

local itemInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local secret = issecretvalue or function() return false end

local shooting = false -- 사격 자동 반복 중 (START/STOP_AUTOREPEAT_SPELL)
local idleSince        -- 놀기 시작한 시각
local warned = false   -- 이번에 소리를 이미 냈나

local function hasWand()
  local id = GetInventoryItemID("player", RANGED_SLOT)
  if not id or not itemInstant then return false end
  local ok, _, _, _, _, _, classID, subID = pcall(itemInstant, id)
  return ok and classID == WAND_CLASS and subID == WAND_SUB
end

-- 비밀 값이면 "모름" → 알리지 않는다
local function truthy(fn, ...)
  local ok, v = pcall(fn, ...)
  if not ok or secret(v) then return nil end
  return v and true or false
end

local function inRange()
  local f = (C_Spell and C_Spell.IsSpellInRange) or IsSpellInRange
  if not f then return true end
  local ok, v = pcall(f, SHOOT, "target")
  if not ok or v == nil or secret(v) then return true end -- 모르면 막지 않는다
  return v == true or v == 1
end

local function shouldWarn()
  if shooting or not InCombatLockdown() then return false end
  if not UnitExists("target") then return false end
  if truthy(UnitCanAttack, "player", "target") ~= true then return false end
  if truthy(UnitIsDeadOrGhost, "target") ~= false then return false end
  if UnitCastingInfo("player") or UnitChannelInfo("player") then return false end
  if (GetUnitSpeed("player") or 0) > 0 then return false end -- 움직이는 중엔 못 쏜다
  if not hasWand() or not inRange() then return false end
  return true
end

-- 화면 표시 --------------------------------------------------------------------------

local alert
local function buildAlert()
  alert = CreateFrame("Frame", "QoLKitWandAlert", UIParent)
  alert:SetSize(64, 64)
  alert:SetPoint("CENTER", 0, 140)
  alert:SetFrameStrata("HIGH")
  alert:Hide()
  alert.icon = alert:CreateTexture(nil, "ARTWORK")
  alert.icon:SetAllPoints()
  alert.text = alert:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  alert.text:SetPoint("TOP", alert, "BOTTOM", 0, -4)
  alert.text:SetText("마법봉!")
  alert.text:SetTextColor(1, 0.3, 0.9)
  local t = 0
  alert:SetScript("OnUpdate", function(self, dt)
    t = t + dt
    self:SetAlpha(0.55 + 0.45 * math.abs(math.sin(t * 4)))
  end)
end

local function showAlert()
  if not alert then buildAlert() end
  alert.icon:SetTexture(GetInventoryItemTexture("player", RANGED_SLOT) or 135139)
  if not alert:IsShown() then
    alert:Show()
    if QoLKitDB.wandSound ~= false and not warned then
      warned = true
      local kit = SOUNDKIT and SOUNDKIT.RAID_WARNING
      if kit then pcall(PlaySound, kit) end
    end
  end
end

local function hideAlert()
  if alert then alert:Hide() end
end

-- 감시 ------------------------------------------------------------------------------

local watch = CreateFrame("Frame")
local acc = 0
local function tick(_, dt)
  acc = acc + dt
  if acc < 0.2 then return end
  acc = 0
  if shouldWarn() then
    idleSince = idleSince or GetTime()
    if GetTime() - idleSince >= (QoLKitDB.wandDelay or 2) then showAlert() end
  else
    idleSince = nil
    hideAlert()
  end
end

watch:SetScript("OnEvent", function(_, event)
  if event == "START_AUTOREPEAT_SPELL" then
    shooting = true
    hideAlert()
  elseif event == "STOP_AUTOREPEAT_SPELL" then
    shooting = false
  elseif event == "PLAYER_REGEN_DISABLED" then
    warned = false
    watch:SetScript("OnUpdate", tick)
  elseif event == "PLAYER_REGEN_ENABLED" then
    watch:SetScript("OnUpdate", nil)
    idleSince = nil
    hideAlert()
  end
end)

local EVENTS = { "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

SLASH_QOLKITWAND1 = "/마법봉"
SLASH_QOLKITWAND2 = "/wand"
SlashCmdList.QOLKITWAND = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "소리" or msg == "sound" then
    QoLKitDB.wandSound = (QoLKitDB.wandSound == false)
    say("마법봉 알림 소리: " .. (QoLKitDB.wandSound and (OK .. "켬|r") or (NG .. "끔|r")))
  elseif tonumber(msg) then
    QoLKitDB.wandDelay = math.max(0.5, math.min(10, tonumber(msg)))
    say(("마법봉 알림: 전투 중 %.1f초 동안 놀면 알립니다."):format(QoLKitDB.wandDelay))
  elseif msg == "시험" or msg == "test" then
    showAlert()
    C_Timer.After(3, hideAlert)
    say("알림을 3초 보여 줍니다.")
  else
    local state = ns.Enabled("wand") and (OK .. "켜짐|r") or (NG .. "꺼짐|r")
    say(("마법봉 알림 [%s]  지금 마법봉: %s"):format(state, hasWand() and (OK .. "착용|r") or (DIM .. "없음|r")))
    print(ns.TAG .. ("  전투 중 적을 잡고 %.1f초 동안 사격도 주문도 안 하면 화면 가운데에 크게 알립니다."):format(QoLKitDB.wandDelay or 2))
    print(ns.TAG .. "  " .. KEY .. "/마법봉 시험|r 미리 보기   " .. KEY .. "/마법봉 3|r 기다리는 초 바꾸기   " .. KEY .. "/마법봉 소리|r 소리 켜기/끄기")
    print(ns.TAG .. "  켜고 끄기: " .. KEY .. "/편의|r")
  end
end

ns.AddModule({
  key = "wand",
  title = "마법봉 알림",
  desc = "전투 중 적을 잡고 마법봉 사격도 주문도 안 하고 놀면 화면 가운데에 크게 알립니다. 마법봉을 찼을 때만. " .. KEY .. "/마법봉|r",
  help = "전투 중 놀면 '마법봉!' 알림 (/마법봉)",
  onEnable = function() for _, e in ipairs(EVENTS) do pcall(watch.RegisterEvent, watch, e) end end,
  onDisable = function()
    watch:UnregisterAllEvents()
    watch:SetScript("OnUpdate", nil)
    hideAlert()
  end,
  onLogin = function()
    if QoLKitDB.welcomed and not QoLKitDB.wandAnnounced and hasWand() then
      say("새 기능: 전투 중 마법봉을 깜빡하면 화면에 '마법봉!' 이 뜹니다. 설정: " .. KEY .. "/마법봉|r")
    end
    if hasWand() then QoLKitDB.wandAnnounced = true end
  end,
  extra = function(parent, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", x - 4, y + 2)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    t:SetText("알릴 때 소리도 내기")
    cb:SetChecked(QoLKitDB.wandSound ~= false)
    cb:SetScript("OnClick", function(self) QoLKitDB.wandSound = self:GetChecked() and true or false end)
    return 22
  end,
})
