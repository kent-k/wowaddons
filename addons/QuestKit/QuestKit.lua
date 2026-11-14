-- 퀘스트 비서 (QuestKit)
-- 1) 끝낸 퀘스트의 퀘스트 아이템이 가방에 남아 칸을 먹지 않게: 찾아서 표시하고, 클릭 한 번으로 지운다.
-- 2) 몹/아이템 툴팁에 퀘스트 진행도, 3) 퀘스트 목표를 다 채우면 알림, 4) 퀘스트 목록에 레벨 표시.
-- 퀘스트 데이터베이스(Questie 같은 지도 표시)는 없다. 게임이 주는 퀘스트 목록과 가방만 본다.

local ADDON = ...
local TAG = "|cffffd100[퀘스트 비서]|r "
local OK, NG, DIM, KEY, WARN = "|cff44ff44", "|cffff5555", "|cffaaaaaa", "|cffffff00", "|cffffaa33"
local function say(msg) print(TAG .. msg) end

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local VERSION = getMeta(ADDON, "Version") or "?"
local function versionText()
  if VERSION:find("@project%-version@") then return NG .. "빌드 안 됨|r" end
  return OK .. VERSION .. "|r"
end

local QUEST_CLASS = 12          -- 아이템 분류: 퀘스트
local DEFAULT_OPT = { tooltip = true, alert = true, level = true, popup = true, bagmark = true }
local db, cdb                   -- QuestKitDB (공용: 설정, 아이템↔퀘스트 연결), QuestKitCharDB (캐릭터: 끝낸/포기한 퀘스트)

-- API (새/옛 이름 둘 다) -----------------------------------------------------------

local Bag = {
  slots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots,
  pickup = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem,
}
local function slotInfo(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local i = C_Container.GetContainerItemInfo(bag, slot)
    if i then return i.itemID, i.hyperlink, i.stackCount, i.iconFileID end
    return nil
  end
  local icon, count, _, _, _, _, link, _, _, id = GetContainerItemInfo(bag, slot)
  return id, link, count, icon
end
-- 퀘스트를 시작하는 아이템이면 그 퀘스트 번호, 그 퀘스트를 지금 진행 중인지
local function slotQuest(bag, slot)
  if C_Container and C_Container.GetContainerItemQuestInfo then
    local q = C_Container.GetContainerItemQuestInfo(bag, slot)
    if q then return q.questID, q.isActive end
    return nil
  end
  if GetContainerItemQuestInfo then
    local _, qid, active = GetContainerItemQuestInfo(bag, slot)
    return qid, active
  end
end
local function itemClass(id)
  if GetItemInfoInstant then
    local _, _, _, _, _, classID = GetItemInfoInstant(id)
    if classID then return classID end
  end
  local r = { GetItemInfo(id) }
  return r[12]
end
local function questDoneFlag(qid)
  if type(qid) ~= "number" then return false end
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(qid) and true or false end
  if IsQuestFlaggedCompleted then return IsQuestFlaggedCompleted(qid) and true or false end
  return false
end
local function isDone(qid) return cdb.done[qid] or questDoneFlag(qid) end

-- 1. 퀘스트 목록 읽기 ---------------------------------------------------------------

-- "멧돼지 고기: 3/10" / "3/10 멧돼지 고기" → 이름, 가진 수, 필요 수
local function parseObjective(text)
  if not text then return nil end
  local name, have, need = text:match("^(.-):%s*(%d+)%s*/%s*(%d+)")
  if not name then
    have, need, name = text:match("^(%d+)%s*/%s*(%d+)%s+(.+)$")
  end
  if not name then return text, nil, nil end
  name = name:gsub("%s+처치$", ""):gsub("%s+죽임$", ""):gsub("%s+slain$", "")
  return name, tonumber(have), tonumber(need)
end

local active = {}       -- [퀘스트 키] = { title, level, complete, objs = { {name, have, need, kind, done, text} } }
local objIndex = {}     -- [목표 이름] = { {key, obj}, ... }
local logReady = false

local function scanLog()
  local new, idx = {}, {}
  local n = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
  for i = 1, n do
    local title, level, _, isHeader, _, isComplete, _, qid = GetQuestLogTitle(i)
    if title and not isHeader then
      local key = qid or title
      local q = { title = title, level = level, index = i, objs = {}, complete = (isComplete == 1 or isComplete == true) }
      local count = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(i) or 0
      local allDone = count > 0
      for j = 1, count do
        local text, kind, finished = GetQuestLogLeaderBoard(j, i)
        local name, have, need = parseObjective(text)
        local o = { name = name, have = have, need = need, kind = kind, done = finished and true or false, text = text }
        q.objs[#q.objs + 1] = o
        if not o.done then allDone = false end
        if name then
          idx[name] = idx[name] or {}
          table.insert(idx[name], { key = key, obj = o })
        end
      end
      q.allDone = allDone or q.complete
      new[key] = q
      if type(qid) == "number" then db.titles[qid] = title end
    end
  end
  return new, idx
end

-- 2. 가방 읽기와 분류 ---------------------------------------------------------------
-- 분류: need(진행 중 퀘스트에 필요) / done(끝낸 퀘스트 → 지워도 됨) / dropped(포기한 퀘스트) / unknown(어디 쓰는지 모름)

local items = {}        -- 가방의 퀘스트 아이템 목록
local byID = {}         -- [아이템 번호] = 분류 결과 (툴팁·가방 표시용)
local seenAt = {}       -- [아이템 번호] = 처음 가방에 들어온 시각
local pendingAccept = {} -- { qid, t } 막 받은 퀘스트 (같이 들어온 아이템을 연결)
local present = {}

local function link(id, key)
  if type(key) ~= "number" then return end      -- 퀘스트 번호를 모르는 옛 클라이언트면 연결 안 함
  db.links[id] = db.links[id] or {}
  db.links[id][key] = true
end

local function questTitle(key)
  if active[key] then return active[key].title end
  return (type(key) == "number" and db.titles[key]) or tostring(key)
end

local function classify(id, name, startQid, startActive)
  -- 진행 중 퀘스트 목표에 이름이 있음
  local hits = name and objIndex[name]
  if hits then
    local h = hits[1]
    local o = h.obj
    local prog = (o.have and o.need) and (" " .. o.have .. "/" .. o.need) or ""
    return "need", questTitle(h.key) .. prog, h.key
  end
  -- 진행 중 퀘스트와 연결돼 있음 (받을 때 같이 들어온 아이템 등)
  local links = db.links[id]
  if links then
    for key in pairs(links) do
      if active[key] then return "need", questTitle(key), key end
    end
  end
  -- 퀘스트를 시작하는 아이템
  if startQid then
    if startActive or active[startQid] then return "need", "진행 중: " .. questTitle(startQid), startQid end
    if isDone(startQid) then return "done", "이미 끝낸 퀘스트를 시작하는 아이템", startQid end
    return "need", "아직 안 받은 퀘스트를 시작하는 아이템", startQid
  end
  -- 연결된 퀘스트가 전부 끝났거나 포기됨
  if links then
    local anyDone, anyDropped, k
    for key in pairs(links) do
      if isDone(key) then anyDone, k = true, k or key
      elseif cdb.dropped[key] then anyDropped, k = true, k or key end
    end
    if anyDone then return "done", "끝낸 퀘스트: " .. questTitle(k), k end
    if anyDropped then return "dropped", "포기한 퀘스트: " .. questTitle(k), k end
  end
  return "unknown", "진행 중 퀘스트 목표에 없음 (다음 퀘스트에 쓰일 수도)", nil
end

local function scanBags()
  if not logReady then return end
  local now = GetTime()
  local list, ids, nowPresent = {}, {}, {}
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, (Bag.slots(bag) or 0) do
      local id, lnk, count, icon = slotInfo(bag, slot)
      if id then
        nowPresent[id] = true
        local startQid, startActive = slotQuest(bag, slot)
        local cls = itemClass(id)
        local name = (lnk and lnk:match("%[(.-)%]")) or GetItemInfo(id)
        local isObj = name and objIndex[name]
        if cls == QUEST_CLASS or startQid or isObj then
          -- 배우기: 목표와 이름이 같으면 그 퀘스트와 연결
          if isObj then for _, h in ipairs(isObj) do link(id, h.key) end end
          -- 처음 들어온 아이템이고 방금 받은 퀘스트가 있으면 연결 (전달용 편지 같은 것)
          if not present[id] then
            seenAt[id] = now
            for _, p in ipairs(pendingAccept) do
              if now - p.t <= 3 and cls == QUEST_CLASS then link(id, p.qid) end
            end
          end
          local kind, why, qkey = classify(id, name, startQid, startActive)
          local it = { bag = bag, slot = slot, id = id, link = lnk, name = name, count = count or 1, icon = icon, kind = kind, why = why, qkey = qkey }
          list[#list + 1] = it
          ids[id] = it
        end
      end
    end
  end
  present = nowPresent
  items, byID = list, ids
end

-- 3. 지우기 ---------------------------------------------------------------------------

local function deleteItem(it)
  if InCombatLockdown and InCombatLockdown() then say(NG .. "전투 중에는 못 지웁니다.|r") return false end
  local id = slotInfo(it.bag, it.slot)
  if id ~= it.id then say(NG .. "가방이 바뀌었습니다. 다시 확인합니다.|r") return false end
  ClearCursor()
  Bag.pickup(it.bag, it.slot)
  if CursorHasItem and not CursorHasItem() then ClearCursor() return false end
  DeleteCursorItem()
  say("지움: " .. (it.link or it.name or it.id) .. (it.count > 1 and (" x" .. it.count) or ""))
  return true
end

-- 4. 정리 창 --------------------------------------------------------------------------

local win, rows, refreshWindow = nil, {}, nil
local KIND_ORDER = { done = 1, dropped = 2, unknown = 3, need = 4 }
local KIND_LABEL = {
  done = OK .. "지워도 됨|r", dropped = WARN .. "포기한 퀘스트|r",
  unknown = DIM .. "확인 필요|r", need = "|cff88bbff진행 중|r",
}
local confirmKey      -- 확인 필요 아이템은 두 번 눌러야 지운다

local function deletable(it) return it.kind == "done" end   -- 전부 지우기·가방 X 표시 대상 (포기한 퀘스트는 하나씩)

local function makeRow(parent, i)
  local r = CreateFrame("Frame", nil, parent)
  r:SetSize(470, 30)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * 32)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(26, 26)
  r.icon:SetPoint("LEFT", 2, 0)
  r.hit = CreateFrame("Button", nil, r)
  r.hit:SetAllPoints(r.icon)
  r.hit:SetScript("OnEnter", function(self)
    if not r.item then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(r.item.bag, r.item.slot)
    GameTooltip:Show()
  end)
  r.hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, 0)
  r.name:SetWidth(300)
  r.name:SetJustifyH("LEFT")
  r.why = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.why:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 6, 0)
  r.why:SetWidth(320)
  r.why:SetJustifyH("LEFT")
  r.del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
  r.del:SetSize(70, 22)
  r.del:SetPoint("RIGHT", -4, 0)
  r.del:SetText("지우기")
  r.del:SetScript("OnClick", function()
    local it = r.item
    if not it then return end
    if it.kind == "unknown" then
      local k = it.bag .. ":" .. it.slot
      if confirmKey ~= k then
        confirmKey = k
        r.del:SetText(NG .. "정말?|r")
        return
      end
    end
    confirmKey = nil
    deleteItem(it)
  end)
  return r
end

local function buildWindow()
  win = CreateFrame("Frame", "QuestKitFrame", UIParent, "BasicFrameTemplateWithInset")
  win:SetSize(520, 440)
  win:SetPoint("CENTER")
  win:SetFrameStrata("HIGH")
  win:SetClampedToScreen(true)
  win:SetMovable(true)
  win:EnableMouse(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  tinsert(UISpecialFrames, "QuestKitFrame")
  local title = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -5)
  title:SetText("퀘스트 비서 — 가방의 퀘스트 아이템  " .. DIM .. VERSION .. "|r")
  win.summary = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  win.summary:SetPoint("TOPLEFT", 16, -32)
  win.summary:SetWidth(490)
  win.summary:SetJustifyH("LEFT")

  local sc = CreateFrame("ScrollFrame", "QuestKitScroll", win, "UIPanelScrollFrameTemplate")
  sc:SetPoint("TOPLEFT", 12, -56)
  sc:SetPoint("BOTTOMRIGHT", -32, 76)
  win.content = CreateFrame("Frame", nil, sc)
  win.content:SetSize(470, 10)
  sc:SetScrollChild(win.content)
  win.empty = win.content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  win.empty:SetPoint("TOPLEFT", 8, -8)
  win.empty:SetText("가방에 퀘스트 아이템이 없습니다.")

  win.all = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  win.all:SetSize(260, 26)
  win.all:SetPoint("BOTTOMLEFT", 16, 40)
  win.all:SetScript("OnClick", function()
    for _, it in ipairs(items) do
      if deletable(it) then deleteItem(it) return end    -- 한 번에 하나 (다음 클릭에 다음 것)
    end
  end)
  local tip = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  tip:SetPoint("BOTTOMLEFT", 18, 14)
  tip:SetWidth(480)
  tip:SetJustifyH("LEFT")
  tip:SetText("'확인 필요' 는 두 번 눌러야 지워집니다. 퀘스트를 받은 뒤 들어온 아이템부터 정확히 연결됩니다.  ESC: 닫기")
  win:SetScript("OnShow", function() confirmKey = nil refreshWindow() end)
end

refreshWindow = function()
  if not win or not win:IsShown() then return end
  local sorted = {}
  for _, it in ipairs(items) do sorted[#sorted + 1] = it end
  table.sort(sorted, function(a, b)
    if a.kind ~= b.kind then return KIND_ORDER[a.kind] < KIND_ORDER[b.kind] end
    return (a.name or "") < (b.name or "")
  end)
  local nDel = 0
  for _, it in ipairs(sorted) do if deletable(it) then nDel = nDel + 1 end end
  for i, it in ipairs(sorted) do
    local r = rows[i] or makeRow(win.content, i)
    rows[i] = r
    r.item = it
    r.icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    r.name:SetText((it.link or it.name or ("#" .. it.id)) .. (it.count > 1 and (" x" .. it.count) or "") .. "  " .. KIND_LABEL[it.kind])
    r.why:SetText(DIM .. (it.why or "") .. "|r")
    local k = it.bag .. ":" .. it.slot
    r.del:SetText(confirmKey == k and (NG .. "정말?|r") or "지우기")
    r.del:SetShown(it.kind ~= "need")
    r:Show()
  end
  for i = #sorted + 1, #rows do rows[i]:Hide() rows[i].item = nil end
  win.content:SetHeight(math.max(10, #sorted * 32))
  win.empty:SetShown(#sorted == 0)
  win.summary:SetText(("퀘스트 아이템 %s%d칸|r  ·  지워도 되는 것 %s%d칸|r"):format(KEY, #sorted, OK, nDel))
  win.all:SetText(nDel > 0 and ("지워도 되는 것 하나씩 지우기 (" .. nDel .. ")") or "지울 것 없음")
  win.all:SetEnabled(nDel > 0)
end

local function toggleWindow(show)
  if not win then buildWindow() end
  if show == nil then show = not win:IsShown() end
  scanBags()
  win:SetShown(show)
  if show then refreshWindow() end
end
function QuestKit_Toggle() toggleWindow() end
BINDING_HEADER_QUESTKIT = "퀘스트 비서"
BINDING_NAME_QUESTKIT_TOGGLE = "퀘스트 아이템 정리 창 열기/닫기"

-- 5. 가방에 표시 (지워도 되는 아이템에 빨간 X) ----------------------------------------

local function markButton(btn, bag, slot)
  if not btn then return end
  local id = slotInfo(bag, slot)
  local it = id and byID[id]
  local show = db.opt.bagmark and it and deletable(it)
  if show and not btn.questKitMark then
    local t = btn:CreateTexture(nil, "OVERLAY")
    t:SetSize(16, 16)
    t:SetPoint("TOPLEFT", 1, -1)
    t:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    btn.questKitMark = t
  end
  if btn.questKitMark then btn.questKitMark:SetShown(show and true or false) end
end

local function markBags()
  for f = 1, (NUM_CONTAINER_FRAMES or 13) do
    local frame = _G["ContainerFrame" .. f]
    if frame and frame:IsShown() and frame.GetID then
      local bag, name = frame:GetID(), frame:GetName()
      for j = 1, (frame.size or 36) do
        local btn = _G[name .. "Item" .. j]
        if btn and btn.GetID then markButton(btn, bag, btn:GetID()) end
      end
    end
  end
end

-- 6. 툴팁 -----------------------------------------------------------------------------

local function addItemLines(tt)
  if not db.opt.tooltip then return end
  local _, lnk = tt:GetItem()
  if not lnk then return end
  local id = tonumber(lnk:match("item:(%d+)"))
  local it = id and byID[id]
  if it then
    local color = (it.kind == "done" and OK) or (it.kind == "dropped" and WARN) or (it.kind == "need" and "|cff88bbff") or DIM
    tt:AddLine(color .. "퀘스트 비서: " .. KIND_LABEL[it.kind] .. color .. " — " .. (it.why or "") .. "|r", 1, 1, 1, true)
    if deletable(it) then tt:AddLine(DIM .. "/퀘스트 로 정리|r") end
    tt:Show()
    return
  end
  local name = lnk:match("%[(.-)%]")
  local hits = name and objIndex[name]
  if hits then
    for _, h in ipairs(hits) do
      local o = h.obj
      tt:AddLine("|cff88bbff퀘스트: " .. questTitle(h.key) .. (o.have and (" " .. o.have .. "/" .. o.need) or "") .. "|r")
    end
    tt:Show()
  end
end

local function addUnitLines(tt)
  if not db.opt.tooltip then return end
  local unitName = tt:GetUnit()
  if not unitName or unitName == "" then return end
  local added
  for key, q in pairs(active) do
    for _, o in ipairs(q.objs) do
      if o.kind == "monster" and o.name and (o.name == unitName or o.name:find(unitName, 1, true)) then
        local c = o.done and OK or "|cff88bbff"
        tt:AddLine(c .. "퀘스트: " .. q.title .. " — " .. (o.text or o.name) .. "|r")
        added = true
      end
    end
  end
  if added then tt:Show() end
end

-- 7. 퀘스트 목록에 레벨 ----------------------------------------------------------------

local function decorateQuestLog()
  if not db.opt.level then return end
  for i = 1, (QUESTS_DISPLAYED or 6) do
    local btn = _G["QuestLogTitle" .. i]
    if btn and btn:IsShown() then
      local idx = btn:GetID()
      local title, level, _, isHeader = GetQuestLogTitle(idx)
      if title and not isHeader and level and level > 0 then
        btn:SetText("  [" .. level .. "] " .. title)
        local check = _G["QuestLogTitle" .. i .. "Check"]
        if check and check:IsShown() and btn.GetTextWidth then
          check:ClearAllPoints()
          check:SetPoint("LEFT", btn, "LEFT", btn:GetTextWidth() + 24, 0)
        end
      end
    end
  end
end

-- 8. 이벤트 ---------------------------------------------------------------------------

local scanQueued = false
local function refresh()
  scanQueued = false
  local old = active
  active, objIndex = scanLog()
  -- 목표를 다 채운 퀘스트 알림
  if logReady and db.opt.alert then
    for key, q in pairs(active) do
      local o = old[key]
      if o and q.allDone and not o.allDone then
        local msg = "퀘스트 완료: " .. q.title .. " — 보고하러 가세요"
        if UIErrorsFrame then UIErrorsFrame:AddMessage(msg, 0.3, 1, 0.3) end
        say(OK .. msg .. "|r")
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960)
      end
    end
  end
  -- 목록에서 사라진 퀘스트: 보고했으면(QUEST_TURNED_IN) 끝, 아니면 포기
  if logReady then
    for key in pairs(old) do
      if not active[key] and not cdb.done[key] and not questDoneFlag(key) then
        cdb.dropped[key] = true
      end
    end
  end
  for key in pairs(active) do cdb.dropped[key] = nil end
  logReady = true
  scanBags()
  refreshWindow()
  markBags()
end

local function queue(delay)
  if scanQueued then return end
  scanQueued = true
  if C_Timer and C_Timer.After then C_Timer.After(delay or 0.3, refresh) else refresh() end
end

-- 보고한 뒤 남은 퀘스트 아이템 알려 주기
local function afterTurnIn(key)
  local left = {}
  for _, it in ipairs(items) do
    if it.kind == "done" and (it.qkey == key or (db.links[it.id] and db.links[it.id][key])) then
      left[#left + 1] = (it.link or it.name) .. (it.count > 1 and (" x" .. it.count) or "")
    end
  end
  if #left == 0 then return end
  say("'" .. questTitle(key) .. "' 끝. 가방에 남은 퀘스트 아이템: " .. table.concat(left, ", ") .. "  → " .. KEY .. "/퀘스트|r 에서 지우기")
  if db.opt.popup and not (InCombatLockdown and InCombatLockdown()) then toggleWindow(true) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, a1, a2)
  if event == "ADDON_LOADED" then
    if a1 ~= ADDON then return end
    QuestKitDB = QuestKitDB or {}
    QuestKitCharDB = QuestKitCharDB or {}
    db, cdb = QuestKitDB, QuestKitCharDB
    db.opt = db.opt or {}
    for k, v in pairs(DEFAULT_OPT) do if db.opt[k] == nil then db.opt[k] = v end end
    db.links = db.links or {}
    db.titles = db.titles or {}
    cdb.done = cdb.done or {}
    cdb.dropped = cdb.dropped or {}
  elseif event == "PLAYER_LOGIN" then
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED", "UNIT_QUEST_LOG_CHANGED" }) do
      pcall(ev.RegisterEvent, ev, e)
    end
    if GameTooltip and GameTooltip.HookScript then
      pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", addItemLines)
      pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", addUnitLines)
    end
    if hooksecurefunc then
      if QuestLog_Update then hooksecurefunc("QuestLog_Update", function() pcall(decorateQuestLog) end) end
      if ContainerFrame_Update then hooksecurefunc("ContainerFrame_Update", function() pcall(markBags) end) end
    end
    queue(1)
    if not db.welcomed then
      db.welcomed = true
      say("설치 감사합니다! 끝낸 퀘스트의 아이템이 가방에 남으면 알려 주고 바로 지울 수 있게 합니다. 정리 창: " .. KEY .. "/퀘스트|r  사용법: " .. KEY .. "/퀘스트 도움말|r")
    else
      say("버전 " .. versionText() .. " 로드됨. 퀘스트 아이템 정리: " .. KEY .. "/퀘스트|r")
    end
  elseif event == "QUEST_ACCEPTED" then
    local qid = a2
    if type(qid) ~= "number" and a1 then qid = select(8, GetQuestLogTitle(a1)) end
    if type(qid) == "number" then
      local now = GetTime()
      table.insert(pendingAccept, { qid = qid, t = now })
      while #pendingAccept > 5 do table.remove(pendingAccept, 1) end
      -- 수락보다 먼저 가방에 들어온 아이템
      for id, t in pairs(seenAt) do
        if now - t <= 2 and itemClass(id) == QUEST_CLASS then link(id, qid) end
      end
      cdb.dropped[qid] = nil
    end
    queue()
  elseif event == "QUEST_TURNED_IN" then
    local key = a1
    if key then
      cdb.done[key] = true
      cdb.dropped[key] = nil
      if C_Timer and C_Timer.After then
        C_Timer.After(1.5, function() refresh() afterTurnIn(key) end)
      end
    end
    queue()
  elseif event == "UNIT_QUEST_LOG_CHANGED" then
    if a1 == "player" then queue() end
  else
    queue()
  end
end)

-- 9. 명령어 ---------------------------------------------------------------------------

local OPT_NAMES = {
  ["툴팁"] = { "tooltip", "툴팁에 퀘스트 진행도·아이템 정리 표시" },
  ["알림"] = { "alert", "목표를 다 채우면 소리·글자 알림" },
  ["레벨"] = { "level", "퀘스트 목록에 [레벨] 표시" },
  ["자동창"] = { "popup", "보고 뒤 남은 아이템이 있으면 정리 창 자동으로 열기" },
  ["표시"] = { "bagmark", "가방에서 지워도 되는 아이템에 빨간 X" },
}
local OPT_ORDER = { "툴팁", "알림", "레벨", "자동창", "표시" }

local function showHelp()
  say("버전 " .. versionText())
  print(TAG .. "|cffffd100끝낸 퀘스트의 아이템이 가방 칸을 먹지 않게 찾아서 지워 줍니다.|r")
  print(TAG .. "  " .. KEY .. "/퀘스트|r            가방의 퀘스트 아이템 정리 창")
  print(TAG .. "  " .. DIM .. "  지워도 됨 = 끝낸 퀘스트 것 · 포기한 퀘스트 = 다시 받을 거면 두기 · 확인 필요 = 두 번 눌러 지움|r")
  for _, k in ipairs(OPT_ORDER) do
    local o = OPT_NAMES[k]
    local state = db.opt[o[1]] and (OK .. "켜짐|r") or (NG .. "꺼짐|r")
    print(TAG .. ("  %s/퀘스트 %s|r  [%s] %s%s|r"):format(KEY, k, state, DIM, o[2]))
  end
  print(TAG .. "  " .. KEY .. "/퀘스트 도움말|r     이 안내    영어: " .. KEY .. "/qk|r")
end

SLASH_QUESTKIT1 = "/퀘스트"
SLASH_QUESTKIT2 = "/퀘비서"
SLASH_QUESTKIT3 = "/qk"
SLASH_QUESTKIT4 = "/questkit"
SlashCmdList.QUESTKIT = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "" or msg == "정리" then
    toggleWindow()
  elseif msg == "도움말" or msg == "help" or msg == "?" then
    showHelp()
  elseif OPT_NAMES[msg] then
    local o = OPT_NAMES[msg]
    db.opt[o[1]] = not db.opt[o[1]]
    say(o[2] .. ": " .. (db.opt[o[1]] and (OK .. "켬|r") or (NG .. "끔|r")))
    queue()
  else
    say(NG .. "모르는 명령입니다.|r " .. KEY .. "/퀘스트 도움말|r")
  end
end
