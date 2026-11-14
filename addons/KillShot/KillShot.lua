-- 킬각 (KillShot) — 운영 중지
-- WoW 포에버 클라이언트는 최신 엔진이라 애드온에 두 가지를 막는다.
--   1) 전투 기록(COMBAT_LOG_EVENT_UNFILTERED) 받기 → 등록만 해도 "기능이 차단되었습니다" 창이 뜬다
--   2) 전투 중 대상 체력은 비밀 값(secret value)이라 애드온이 숫자로 비교할 수 없다
-- 그래서 "한 방에 잡을 수 있는가" 를 계산할 방법이 없다. 아무것도 하지 않고 안내만 한다.

local ADDON = ...
local TAG = "|cffffd100[킬각]|r "
local MSG = "블리자드가 이 클라이언트에서 전투 기록과 전투 중 대상 체력을 애드온에 막아 둬서 동작할 수 없습니다. 애드온 도우미에서 |cffffff00킬각|r 체크를 풀어 제거하세요."

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() print(TAG .. MSG) end)

SLASH_KILLSHOT1 = "/킬각"
SLASH_KILLSHOT2 = "/ks"
SLASH_KILLSHOT3 = "/killshot"
SlashCmdList.KILLSHOT = function() print(TAG .. MSG) end
