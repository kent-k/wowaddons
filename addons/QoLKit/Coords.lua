-- 내 위치(좌표): /위치 로 채팅에 출력, 큰 지도에 내 좌표/마우스 좌표, 원하면 화면에 작은 좌표 창
local _, ns = ...
local say, OK, NG, DIM, KEY = ns.say, ns.OK, ns.NG, ns.DIM, ns.KEY

-- 지금 위치: 지역, 세부 지역, x, y (0~100). 인던 안 등 좌표를 못 받으면 x 가 nil
local function where()
  local zone = (GetRealZoneText and GetRealZoneText()) or GetZoneText() or "?"
  local sub = GetSubZoneText and GetSubZoneText() or ""
  if sub == zone then sub = "" end
  local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local ok, p = pcall(function() return m and C_Map.GetPlayerMapPosition(m, "player") end)
  if ok and p then
    local x, y = p:GetXY()
    if x and (x > 0 or y > 0) then return zone, sub, x * 100, y * 100 end
  end
  return zone, sub, nil, nil
end

local function placeText()
  local zone, sub, x, y = where()
  local name = sub ~= "" and (zone .. " - " .. sub) or zone
  if not x then return name, nil end
  return name, ("%.1f, %.1f"):format(x, y)
end

-- 화면에 띄우는 작은 좌표 창 ------------------------------------------------------

local box
local function buildBox()
  box = CreateFrame("Frame", "QoLKitCoordsBox", UIParent, "BackdropTemplate")
  box:SetSize(150, 22)
  box:SetFrameStrata("MEDIUM")
  box:SetClampedToScreen(true)
  box:SetMovable(true)
  box:EnableMouse(true)
  box:RegisterForDrag("LeftButton")
  box:SetScript("OnDragStart", box.StartMoving)
  box:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    QoLKitDB.coordsPos = { p, rp, x, y }
  end)
  if box.SetBackdrop then
    box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
  end
  local pos = QoLKitDB.coordsPos
  if pos then box:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else box:SetPoint("TOP", Minimap or UIParent, "BOTTOM", 0, -18) end
  box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  box.text:SetPoint("CENTER")
  local t = 0
  box:SetScript("OnUpdate", function(self, dt)
    t = t + dt
    if t < 0.2 then return end
    t = 0
    local _, c = placeText()
    self.text:SetText(c or (DIM .. "좌표 없음|r"))
  end)
  box:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine((placeText()))
    GameTooltip:AddLine("끌어서 옮기기. 끄기: /위치 표시", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  box:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function updateBox()
  local want = ns.Enabled("coords") and QoLKitDB.coordsBox
  if want and not box then buildBox() end
  if box then box:SetShown(want and true or false) end
end

-- 큰 지도 아래 좌표 ----------------------------------------------------------------

local mapText
local function hookMap()
  if mapText or not WorldMapFrame then return end
  local holder = WorldMapFrame.ScrollContainer or WorldMapFrame
  mapText = CreateFrame("Frame", nil, WorldMapFrame)
  mapText:SetSize(1, 1)
  mapText:SetFrameStrata("HIGH")
  mapText:SetPoint("BOTTOM", holder, "BOTTOM", 0, 6)
  local fs = mapText:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("BOTTOM")
  fs:SetShadowOffset(1, -1)
  local t = 0
  mapText:SetScript("OnUpdate", function(_, dt)
    t = t + dt
    if t < 0.1 then return end
    t = 0
    if not ns.Enabled("coords") then fs:SetText("") return end
    local _, c = placeText()
    local s = "내 위치 " .. (c or (DIM .. "없음|r"))
    local sc = WorldMapFrame.ScrollContainer
    if sc and sc.GetNormalizedCursorPosition and sc:IsMouseOver() then
      local ok, cx, cy = pcall(sc.GetNormalizedCursorPosition, sc)
      if ok and cx and cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then
        s = s .. "     |cffffffff마우스 " .. ("%.1f, %.1f"):format(cx * 100, cy * 100) .. "|r"
      end
    end
    fs:SetText(s)
  end)
end

-- /위치 ---------------------------------------------------------------------------

local function printWhere()
  local name, c = placeText()
  if c then
    say(KEY .. name .. "|r  " .. OK .. c .. "|r")
  else
    say(KEY .. name .. "|r  " .. NG .. "여기서는 좌표를 받을 수 없습니다|r (인던 안 등)")
  end
end

local function toChat()
  local name, c = placeText()
  local text = c and (name .. " (" .. c .. ")") or name
  -- 바로 보내지 않고 채팅 입력칸에 넣어 둔다. 보낼 곳은 직접 고르고 Enter
  local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
  if open and pcall(open, text) then
    return
  else
    say(text)
  end
end

local function help()
  say(KEY .. "/위치|r 내 좌표 보기")
  print(ns.TAG .. "  " .. KEY .. "/위치 채팅|r  좌표를 채팅 입력칸에 넣기 (Enter 로 보내기)")
  print(ns.TAG .. "  " .. KEY .. "/위치 표시|r  화면에 작은 좌표 창 켜기/끄기 (끌어서 옮김)")
  print(ns.TAG .. "  큰 지도(M)를 열면 아래쪽에 내 좌표와 마우스 좌표가 나옵니다.")
end

SLASH_QOLKITLOC1 = "/위치"
SLASH_QOLKITLOC2 = "/좌표"
SLASH_QOLKITLOC3 = "/loc"
SlashCmdList.QOLKITLOC = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "" then
    printWhere()
  elseif msg == "채팅" or msg == "공유" or msg == "chat" then
    toChat()
  elseif msg == "표시" or msg == "창" or msg == "show" then
    QoLKitDB.coordsBox = not QoLKitDB.coordsBox
    if QoLKitDB.coordsBox and not ns.Enabled("coords") then QoLKitDB.on.coords = true end
    updateBox()
    say("화면 좌표 창: " .. (QoLKitDB.coordsBox and (OK .. "켬|r") or (NG .. "끔|r")))
  else
    help()
  end
end

ns.AddModule({
  key = "coords",
  title = "내 위치(좌표)",
  desc = "큰 지도 아래에 내 좌표와 마우스 좌표를 보여 줍니다. 채팅에 " .. KEY .. "/위치|r 를 치면 지금 좌표가 나옵니다.",
  help = "/위치 좌표, /위치 채팅, /위치 표시",
  onLogin = function()
    if QoLKitDB.welcomed and not QoLKitDB.coordsAnnounced then
      say("새 기능: 채팅에 " .. KEY .. "/위치|r 를 치면 내 좌표가 나옵니다. 큰 지도 아래에도 좌표가 보입니다.")
    end
    QoLKitDB.coordsAnnounced = true
    hookMap()
    if not mapText then -- 지도 애드온이 나중에 로드되는 클라이언트
      local w = CreateFrame("Frame")
      w:RegisterEvent("ADDON_LOADED")
      w:SetScript("OnEvent", function(self)
        hookMap()
        if mapText then self:UnregisterAllEvents() end
      end)
    end
  end,
  onEnable = function() updateBox() end,
  onDisable = function() updateBox() end,
  extra = function(parent, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", x - 4, y + 2)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    t:SetText("화면에 작은 좌표 창도 띄우기 (끌어서 옮김)")
    cb:SetScript("OnShow", function(self) self:SetChecked(QoLKitDB.coordsBox and true or false) end)
    cb:SetChecked(QoLKitDB.coordsBox and true or false)
    cb:SetScript("OnClick", function(self)
      QoLKitDB.coordsBox = self:GetChecked() and true or false
      updateBox()
    end)
    return 22
  end,
})
