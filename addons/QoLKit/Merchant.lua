-- 상인: 회색 템 판매, 자동 수리
local _, ns = ...
local Bag = ns.Bag

local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

-- 회색 템 판매 ---------------------------------------------------------------------

local selling = false
local soldCount, soldMoney = 0, 0

local function grayList()
  local list = {}
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, (Bag.slots(bag) or 0) do
      local quality, link, count, noValue = Bag.info(bag, slot)
      if quality == 0 and link and not noValue then
        local price = select(11, getItemInfo(link)) or 0
        if price > 0 then list[#list + 1] = { bag = bag, slot = slot, money = price * (count or 1) } end
      end
    end
  end
  return list
end

local function sellNext(list, i)
  if not selling then return end
  if not (MerchantFrame and MerchantFrame:IsShown()) then   -- 상인 창을 닫으면 멈춤
    selling = false
    return
  end
  local e = list[i]
  if not e then
    selling = false
    if soldCount > 0 then
      ns.say(("회색 아이템 %d개 판매: %s"):format(soldCount, ns.Money(soldMoney)))
    end
    return
  end
  local quality = Bag.info(e.bag, e.slot)
  if quality == 0 then          -- 그 사이에 칸이 바뀌지 않았으면
    Bag.use(e.bag, e.slot)
    soldCount = soldCount + 1
    soldMoney = soldMoney + e.money
  end
  C_Timer.After(0.2, function() sellNext(list, i + 1) end)
end

local sellFrame = CreateFrame("Frame")
sellFrame:SetScript("OnEvent", function(_, event)
  if event == "MERCHANT_CLOSED" then selling = false return end
  if selling then return end
  local list = grayList()
  if #list == 0 then return end
  selling, soldCount, soldMoney = true, 0, 0
  sellNext(list, 1)
end)

ns.AddModule({
  key = "sellgray",
  title = "회색 템 자동 판매",
  desc = "상인 창을 열면 가방의 회색(잡동사니) 아이템을 팝니다. 판 금액은 채팅에 한 줄로 알려 줍니다.",
  help = "상인 창 열면 회색 아이템 판매",
  onEnable = function() sellFrame:RegisterEvent("MERCHANT_SHOW") sellFrame:RegisterEvent("MERCHANT_CLOSED") end,
  onDisable = function() sellFrame:UnregisterAllEvents() selling = false end,
})

-- 자동 수리 ------------------------------------------------------------------------

local repairFrame = CreateFrame("Frame")
repairFrame:SetScript("OnEvent", function()
  if not (CanMerchantRepair and CanMerchantRepair()) then return end
  local cost, canRepair = GetRepairAllCost()
  if not canRepair or not cost or cost <= 0 then return end
  if GetMoney() < cost then
    ns.say(ns.NG .. "수리비가 모자랍니다|r (필요: " .. ns.Money(cost) .. ")")
    return
  end
  RepairAllItems()
  ns.say("수리: " .. ns.Money(cost))
end)

ns.AddModule({
  key = "repair",
  title = "자동 수리",
  desc = "수리할 수 있는 상인 창을 열면 내 돈으로 장비를 모두 수리합니다.",
  help = "수리 상인 창 열면 모두 수리",
  onEnable = function() repairFrame:RegisterEvent("MERCHANT_SHOW") end,
  onDisable = function() repairFrame:UnregisterAllEvents() end,
})
