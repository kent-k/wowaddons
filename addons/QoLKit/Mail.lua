-- 우편 모두 받기: 우편함에 [모두 받기] 버튼. 돈과 아이템을 차례로 받는다
local _, ns = ...

local MAX_ATTACH = ATTACHMENTS_MAX_RECEIVE or 16
local running = false
local gotMoney, gotItems = 0, 0
local button

local function finish(reason)
  running = false
  if button then button:SetText("모두 받기") end
  local parts = {}
  if gotMoney > 0 then parts[#parts + 1] = ns.Money(gotMoney) end
  if gotItems > 0 then parts[#parts + 1] = ("아이템 %d개"):format(gotItems) end
  if #parts > 0 then
    ns.say("우편 받음: " .. table.concat(parts, ", ") .. (reason and ("  " .. reason) or ""))
  elseif reason then
    ns.say(reason)
  end
end

-- 받을 것이 남은 첫 우편을 찾아 하나만 받는다. 받았으면 true
local function takeOne()
  for i = GetInboxNumItems(), 1, -1 do
    local _, _, _, _, money, cod, _, itemCount = GetInboxHeaderInfo(i)
    if (cod or 0) == 0 then          -- 착불 우편은 건너뜀 (돈을 내야 하므로 직접)
      if (money or 0) > 0 then
        TakeInboxMoney(i)
        gotMoney = gotMoney + money
        return true
      end
      if (itemCount or 0) > 0 then
        for a = 1, MAX_ATTACH do
          if GetInboxItem(i, a) then
            if ns.Bag.freeSlots() == 0 then return false, "가방이 꽉 차서 멈췄습니다." end
            TakeInboxItem(i, a)
            gotItems = gotItems + 1
            return true
          end
        end
      end
    end
  end
  return false
end

local function step()
  if not running then return end
  if not (InboxFrame and InboxFrame:IsVisible()) then finish("우편함을 닫아서 멈췄습니다.") return end
  local ok, reason = takeOne()
  if not ok then finish(reason) return end
  C_Timer.After(0.35, step)
end

local function start()
  if running then running = false finish("멈췄습니다.") return end
  running, gotMoney, gotItems = true, 0, 0
  button:SetText("멈추기")
  step()
end

local function makeButton()
  if button or not InboxFrame then return end
  button = CreateFrame("Button", "QoLKitOpenAll", InboxFrame, "UIPanelButtonTemplate")
  button:SetSize(100, 22)
  button:SetPoint("TOP", InboxFrame, "TOP", 0, -42)
  button:SetText("모두 받기")
  button:SetScript("OnClick", start)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("우편 모두 받기 (편의 모음)", 1, 1, 1)
    GameTooltip:AddLine("돈과 첨부 아이템을 차례로 받습니다. 착불 우편은 건너뜁니다. 한 번 더 누르면 멈춥니다.", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, event)
  if event == "MAIL_SHOW" then
    makeButton()
    if button then button:SetShown(ns.Enabled("mail")) end
  elseif event == "MAIL_CLOSED" then
    running = false
  end
end)
f:RegisterEvent("MAIL_SHOW")
f:RegisterEvent("MAIL_CLOSED")

ns.AddModule({
  key = "mail",
  title = "우편 모두 받기",
  desc = "우편함 위쪽에 [모두 받기] 버튼을 붙입니다. 돈과 첨부 아이템을 한 번에 받습니다 (착불 우편 제외).",
  help = "우편함에 [모두 받기] 버튼",
  onEnable = function() if button then button:Show() end end,
  onDisable = function() if button then button:Hide() end running = false end,
})
