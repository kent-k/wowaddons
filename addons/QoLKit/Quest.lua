-- 퀘스트 빠른 진행: Shift 를 누른 채 NPC 와 대화하면 수락/완료를 자동으로 누른다
local _, ns = ...

local function wanted()
  if QoLKitDB.questAlways then return true end
  return IsShiftKeyDown()
end

local G = C_GossipInfo
local function gossipPick()
  -- 완료할 수 있는 퀘스트가 있으면 그것, 없으면 받을 수 있는 퀘스트가 하나뿐일 때 그것
  if G and G.GetActiveQuests then
    for _, q in ipairs(G.GetActiveQuests() or {}) do
      if q.isComplete then G.SelectActiveQuest(q.questID) return end
    end
    local avail = G.GetAvailableQuests() or {}
    if #avail == 1 then G.SelectAvailableQuest(avail[1].questID) end
  elseif GetGossipActiveQuests then
    -- 옛 API: 항목마다 이름, 레벨, 하위, 완료여부, ... (6개씩)
    local act = { GetGossipActiveQuests() }
    local per = 6
    for i = 1, #act / per do
      if act[(i - 1) * per + 4] then SelectGossipActiveQuest(i) return end
    end
    local avail = { GetGossipAvailableQuests() }
    if #avail > 0 and #avail <= 7 then SelectGossipAvailableQuest(1) end
  end
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, event)
  if not wanted() then return end
  if event == "QUEST_DETAIL" then
    AcceptQuest()
  elseif event == "QUEST_PROGRESS" then
    if IsQuestCompletable() then CompleteQuest() end
  elseif event == "QUEST_COMPLETE" then
    local n = GetNumQuestChoices()
    if n <= 1 then
      GetQuestReward(n)
    else
      ns.say("보상을 골라야 하는 퀘스트입니다. 직접 고르세요.")
    end
  elseif event == "QUEST_GREETING" then
    for i = 1, (GetNumActiveQuests() or 0) do
      local _, done = GetActiveTitle(i)
      if done then SelectActiveQuest(i) return end
    end
    if (GetNumAvailableQuests() or 0) == 1 then SelectAvailableQuest(1) end
  elseif event == "GOSSIP_SHOW" then
    gossipPick()
  end
end)

local EVENTS = { "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "GOSSIP_SHOW" }

ns.AddModule({
  key = "quest",
  title = "퀘스트 빠른 진행",
  desc = "Shift 를 누른 채 NPC 에게 말을 걸면 퀘스트 수락·완료를 자동으로 누릅니다. 보상을 골라야 하면 멈춥니다.",
  help = "Shift+대화로 수락/완료 자동",
  onEnable = function() for _, e in ipairs(EVENTS) do pcall(f.RegisterEvent, f, e) end end,
  onDisable = function() f:UnregisterAllEvents() end,
  extra = function(parent, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", x - 4, y + 2)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    t:SetText("Shift 없이 항상 자동으로")
    cb:SetChecked(QoLKitDB.questAlways and true or false)
    cb:SetScript("OnClick", function(self)
      QoLKitDB.questAlways = self:GetChecked() and true or false
      ns.say("퀘스트 빠른 진행: " .. (QoLKitDB.questAlways and "항상 자동" or "Shift 를 누를 때만"))
    end)
    return 22
  end,
})
