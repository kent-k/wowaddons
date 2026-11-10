-- 쿨다운 숫자: 단축바 아이콘 위에 남은 시간을 숫자로
-- 게임에 '쿨다운 숫자 표시' 설정(countdownForCooldowns)이 있으면 그걸 켠다. 없으면 직접 그린다.
local _, ns = ...

local getCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
local setCVar = (C_CVar and C_CVar.SetCVar) or SetCVar

local function hasBuiltin()
  return getCVar("countdownForCooldowns") ~= nil
end

-- 직접 그리기 --------------------------------------------------------------------

local active = {}      -- [cooldown 프레임] = { start, duration, text }
local hooked = false
local enabled = false

local function fmt(left)
  if left >= 3600 then return ("%dh"):format(math.ceil(left / 3600)), 0.8, 0.8, 0.8 end
  if left >= 60 then return ("%dm"):format(math.ceil(left / 60)), 1, 1, 1 end
  if left >= 5 then return ("%d"):format(math.ceil(left)), 1, 1, 0.3 end
  return ("%d"):format(math.ceil(left)), 1, 0.3, 0.3
end

local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, dt)
  acc = acc + dt
  if acc < 0.1 then return end
  acc = 0
  local now = GetTime()
  for cd, e in pairs(active) do
    local left = e.start + e.duration - now
    if left <= 0 or not cd:IsVisible() or not enabled then
      e.text:Hide()
      active[cd] = nil
    else
      local s, r, g, b = fmt(left)
      e.text:SetText(s)
      e.text:SetTextColor(r, g, b)
      e.text:Show()
    end
  end
end)

local texts = {}
local function onSetCooldown(cd, start, duration)
  if not enabled or cd.noCooldownCount then return end
  if not start or not duration or duration < 2 or start <= 0 then   -- 전역 쿨다운(1.5초) 제외
    if active[cd] then active[cd].text:Hide() active[cd] = nil end
    return
  end
  local w = cd:GetWidth() or 0
  if w < 20 then return end
  local t = texts[cd]
  if not t then
    t = cd:CreateFontString(nil, "OVERLAY")
    t:SetPoint("CENTER", 0, 0)
    texts[cd] = t
  end
  t:SetFont(STANDARD_TEXT_FONT, math.floor(w * 0.45 + 0.5), "OUTLINE")
  active[cd] = { start = start, duration = duration, text = t }
end

local function hookCooldowns()
  if hooked then return end
  local sample = ActionButton1Cooldown or CreateFrame("Cooldown")
  local mt = getmetatable(sample)
  if mt and mt.__index and mt.__index.SetCooldown then
    hooksecurefunc(mt.__index, "SetCooldown", onSetCooldown)
    hooked = true
  end
end

local mode   -- "builtin" / "own"

ns.AddModule({
  key = "cdcount",
  title = "쿨다운 숫자",
  desc = "단축바 아이콘 위에 재사용 대기시간을 숫자로 보여 줍니다.",
  help = "단축바 아이콘 위에 남은 쿨다운 숫자",
  onEnable = function()
    if hasBuiltin() then
      mode = "builtin"
      setCVar("countdownForCooldowns", "1")
    else
      mode = "own"
      enabled = true
      hookCooldowns()
    end
  end,
  onDisable = function()
    if mode == "builtin" then setCVar("countdownForCooldowns", "0") end
    enabled = false
    for cd, e in pairs(active) do e.text:Hide() active[cd] = nil end
  end,
  extra = function(parent, x, y)
    local s = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    s:SetPoint("TOPLEFT", x, y)
    local function refresh()
      s:SetText(hasBuiltin() and "방식: 게임 기본 기능(쿨다운 숫자 표시)을 켭니다" or "방식: 애드온이 직접 숫자를 그립니다")
    end
    ns.OnPanelRefresh(refresh)
    refresh()
    return 16
  end,
})
