-- 던전 안에서 어떤 맵/좌표 API가 동작하는지 확인하는 진단 애드온
local out

local function log(fmt, ...)
  local s = string.format(fmt, ...)
  table.insert(out, s)
  print("|cff33ff99[DNP]|r " .. s)
end

local function safe(f, ...)
  if not f then return "API 없음" end
  local r = { pcall(f, ...) }
  if not r[1] then return "에러: " .. tostring(r[2]) end
  local t = {}
  for i = 2, select("#", unpack(r)) do t[#t + 1] = tostring(r[i]) end
  return #t > 0 and table.concat(t, ", ") or "(반환 없음)"
end

local function probe()
  out = {}
  local ver, build, date, iface = GetBuildInfo()
  log("빌드 %s (%s) interface=%s", tostring(ver), tostring(build), tostring(iface))
  log("GetInstanceInfo: %s", safe(GetInstanceInfo))
  log("GetRealZoneText: %s / 서브존: %s", tostring(GetRealZoneText()), tostring(GetSubZoneText()))
  log("UnitPosition: %s", safe(UnitPosition, "player"))

  if C_Map then
    local mapID = C_Map.GetBestMapForUnit("player")
    log("C_Map.GetBestMapForUnit: %s", tostring(mapID))
    if mapID then
      local info = C_Map.GetMapInfo(mapID)
      if info then log("  MapInfo: name=%s type=%s parent=%s", tostring(info.name), tostring(info.mapType), tostring(info.parentMapID)) end
      local pos = C_Map.GetPlayerMapPosition(mapID, "player")
      log("  GetPlayerMapPosition: %s", pos and string.format("%.4f, %.4f", pos:GetXY()) or "nil (제한됨)")
      local layers = C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
      log("  ArtLayers: %s", layers and tostring(#layers) or "nil")
      if layers and layers[1] then
        log("  Layer1 크기 %dx%d 타일 %dx%d", layers[1].layerWidth or 0, layers[1].layerHeight or 0, layers[1].tileWidth or 0, layers[1].tileHeight or 0)
      end
      log("  ArtID: %s", safe(C_Map.GetMapArtID, mapID))
      local group = C_Map.GetMapGroupID and C_Map.GetMapGroupID(mapID)
      log("  MapGroupID(층): %s", tostring(group))
      if group then
        for _, m in ipairs(C_Map.GetMapGroupMembersInfo(group) or {}) do
          log("    층 mapID=%s %s", tostring(m.mapID), tostring(m.name))
        end
      end
    end
  else
    log("C_Map 없음")
  end

  DNProbeDB = DNProbeDB or {}
  DNProbeDB[date and (GetRealZoneText() .. " " .. time()) or tostring(time())] = out
  log("저장 완료 (로그아웃/ /reload 시 파일 기록)")
end

SLASH_DNPROBE1 = "/dnp"
SlashCmdList.DNPROBE = probe
