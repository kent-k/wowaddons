-- 빠른 줍기: 자동 줍기 상태에서 루팅 창이 뜨는 즉시 전부 줍는다
local _, ns = ...

local getCVarBool = (C_CVar and C_CVar.GetCVarBool) or GetCVarBool
local setCVar = (C_CVar and C_CVar.SetCVar) or SetCVar

local f = CreateFrame("Frame")
local lastLoot = 0

local function autoLootActive()
  -- 게임의 자동 줍기 설정과 줍기 키(기본 Shift)로 뒤집은 상태를 그대로 따른다
  local auto = getCVarBool("autoLootDefault")
  if IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") then auto = not auto end
  return auto
end

f:SetScript("OnEvent", function()
  if GetTime() - lastLoot < 0.3 then return end   -- 같은 시체에 이벤트가 두 번 오는 경우
  if not autoLootActive() then return end
  lastLoot = GetTime()
  for i = GetNumLootItems(), 1, -1 do
    LootSlot(i)
  end
end)

local status
ns.AddModule({
  key = "fastloot",
  title = "빠른 줍기",
  desc = "자동 줍기일 때 루팅 창이 뜨자마자 전부 줍습니다. (게임 설정의 '자동 줍기' 가 켜져 있어야 합니다)",
  help = "자동 줍기일 때 즉시 전부 줍기",
  onEnable = function() f:RegisterEvent("LOOT_READY") end,
  onDisable = function() f:UnregisterEvent("LOOT_READY") end,
  extra = function(parent, x, y)
    status = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", x, y)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(120, 20)
    b:SetPoint("LEFT", status, "RIGHT", 8, 0)
    b:SetText("자동 줍기 켜기")
    local function refresh()
      local on = getCVarBool("autoLootDefault")
      status:SetText("게임의 자동 줍기: " .. (on and (ns.OK .. "켜짐|r") or (ns.NG .. "꺼짐|r")))
      b:SetShown(not on)
    end
    b:SetScript("OnClick", function()
      setCVar("autoLootDefault", "1")
      ns.say("게임 설정의 자동 줍기를 켰습니다. 줍기 키(Shift)를 누른 채 열면 이번만 수동으로 줍습니다.")
      refresh()
    end)
    ns.OnPanelRefresh(refresh)
    refresh()
    return 24
  end,
})
