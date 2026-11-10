-- 매크로 공방 (MacroKit) - 코어
-- 템플릿 등록, 매크로 본문 만들기, 매크로 생성/덮어쓰기/삭제, 클라이언트 기능 검사.
-- 화면은 UI.lua, 템플릿 데이터는 Templates/*.lua.

local ADDON, ns = ...

ns.TAG = "|cffffd100[매크로 공방]|r "
ns.OK, ns.NG, ns.DIM, ns.KEY = "|cff44ff44", "|cffff5555", "|cffaaaaaa", "|cffffff00"
ns.ICON = "INV_Misc_QuestionMark"   -- #showtooltip 과 함께 쓰면 게임이 주문 아이콘으로 바꿔 보여 준다
ns.NAME_MAX = 16                    -- 매크로 이름 최대 글자 수
ns.BODY_MAX = 255                   -- 매크로 본문 최대 글자 수

function ns.say(msg) print(ns.TAG .. msg) end

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.VERSION = getMeta(ADDON, "Version") or "?"
function ns.versionText()
  if ns.VERSION:find("@project%-version@") then return ns.NG .. "빌드 안 됨|r" end
  return ns.OK .. ns.VERSION .. "|r"
end

-- 직업 / 분류 ------------------------------------------------------------------

ns.ClassOrder = { "COMMON", "WARLOCK", "SHAMAN", "DRUID", "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "MAGE" }
ns.ClassNames = {
  COMMON = "공통", WARLOCK = "흑마법사", SHAMAN = "주술사", DRUID = "드루이드", WARRIOR = "전사",
  PALADIN = "성기사", HUNTER = "사냥꾼", ROGUE = "도적", PRIEST = "사제", MAGE = "마법사",
}
ns.ClassShort = {
  COMMON = "공통", WARLOCK = "흑마", SHAMAN = "술사", DRUID = "드루", WARRIOR = "전사",
  PALADIN = "성기사", HUNTER = "사냥꾼", ROGUE = "도적", PRIEST = "사제", MAGE = "법사",
}
ns.CatOrder = { "attack", "interrupt", "control", "curse", "heal", "dispel", "buff", "defense", "form", "stealth", "totem", "pet", "item", "move", "target", "utility" }
ns.CatNames = {
  attack = "공격", interrupt = "차단", control = "제어", curse = "저주", heal = "치유", dispel = "해제",
  buff = "보호", defense = "위급", form = "변신·태세", stealth = "은신", totem = "토템", pet = "소환수",
  item = "아이템", move = "이동", target = "대상", utility = "유틸",
}

-- 템플릿 등록 -------------------------------------------------------------------

ns.Templates = {}   -- [직업] = { 템플릿, ... }
ns.ById = {}

function ns.S(id) return id end   -- 템플릿 안의 주문 번호 표시 (tools/casc/check_spells.py 가 이걸로 찾는다)

function ns.AddTemplates(class, list)
  ns.Templates[class] = ns.Templates[class] or {}
  for _, t in ipairs(list) do
    assert(t.id and not ns.ById[t.id], "MacroKit: 템플릿 ID 중복/없음 " .. tostring(t.id))
    t.class = class
    t.params = t.params or {}
    table.insert(ns.Templates[class], t)
    ns.ById[t.id] = t
  end
end

-- 주문 / 아이템 정보 ------------------------------------------------------------

function ns.SpellInfo(id)
  if C_Spell and C_Spell.GetSpellInfo then
    local i = C_Spell.GetSpellInfo(id)
    if i then return i.name, i.iconID end
  end
  if GetSpellInfo then
    local name, _, icon = GetSpellInfo(id)
    return name, icon
  end
end

-- 배운 주문인가? (등급이 여러 개면 같은 이름의 아무 등급이나 배웠으면 true)
function ns.SpellKnown(id)
  if IsSpellKnown and (IsSpellKnown(id) or IsSpellKnown(id, true)) then return true end
  if IsPlayerSpell and IsPlayerSpell(id) then return true end
  local name = ns.SpellInfo(id)
  if not name then return false end
  -- 이름으로 물으면 배운 주문일 때만 정보를 준다
  if C_Spell and C_Spell.GetSpellInfo then
    if C_Spell.GetSpellInfo(name) then return true end
  elseif GetSpellInfo then
    if GetSpellInfo(name) then return true end
  end
  return false
end

-- 주문책의 주문 목록 (같은 이름은 하나로, 지속 효과 제외). "아무 주문" 빈칸에 쓴다
function ns.SpellbookSpells()
  local list, seen = {}, {}
  local numTabs = (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines()) or (GetNumSpellTabs and GetNumSpellTabs()) or 0
  for tab = 1, numTabs do
    local offset, count
    if GetSpellTabInfo then
      local _, _, o, n = GetSpellTabInfo(tab)
      offset, count = o, n
    else
      local info = C_SpellBook.GetSpellBookSkillLineInfo(tab)
      offset, count = info.itemIndexOffset, info.numSpellBookItems
    end
    for i = offset + 1, offset + count do
      local id, passive
      if GetSpellBookItemInfo then
        local kind, sid = GetSpellBookItemInfo(i, BOOKTYPE_SPELL or "spell")
        if kind == "SPELL" then id = sid end
        passive = IsPassiveSpell and IsPassiveSpell(i, BOOKTYPE_SPELL or "spell")
      else
        local info = C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Player)
        if info and info.itemType == Enum.SpellBookItemType.Spell then id = info.spellID; passive = info.isPassive end
      end
      if id and not passive then
        local name, icon = ns.SpellInfo(id)
        if name then
          if seen[name] then
            list[seen[name]].id = id   -- 나중에 나오는 것이 높은 등급
          else
            list[#list + 1] = { id = id, name = name, icon = icon }
            seen[name] = #list
          end
        end
      end
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

function ns.ItemInfo(id)
  local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local name, _, _, _, _, _, _, _, _, icon = getInfo(id)
  return name, icon
end

local function itemSpell(id)
  local f = (C_Item and C_Item.GetItemSpell) or GetItemSpell
  return f and f(id)
end

-- 가방에 있는 아이템 목록 (같은 아이템은 하나로). filter = "use" 면 사용 효과가 있는 것만
function ns.BagItems(filter)
  local numSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  local itemID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
  local seen, list = {}, {}
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, (numSlots(bag) or 0) do
      local id = itemID(bag, slot)
      if id and not seen[id] then
        seen[id] = true
        local name, icon = ns.ItemInfo(id)
        if name and (filter ~= "use" or itemSpell(id)) then
          list[#list + 1] = { id = id, name = name, icon = icon }
        end
      end
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

function ns.PlayerClass()
  local _, class = UnitClass("player")
  return class
end

-- 클라이언트 기능 검사 ------------------------------------------------------------

ns.Caps = {}

local function parses(opt)
  if not SecureCmdOptionParse then return false end
  local ok, r = pcall(SecureCmdOptionParse, opt .. " 예; 아니오")
  return ok and r == "예"
end

function ns.DetectCaps()
  local c = ns.Caps
  c.at = parses("[@player,exists]")                 -- [@unit] 표기
  c.legacy = parses("[target=player,exists]")       -- [target=unit] 표기
  c.focus = SLASH_FOCUS1 ~= nil                     -- /focus 명령이 있으면 주시 대상 사용 가능
  c.mod = parses("[nomod]")
  c.nodead = parses("[@player,nodead]") or parses("[target=player,nodead]")
  c.macroApi = CreateMacro and EditMacro and DeleteMacro and GetNumMacros and GetMacroIndexByName and PickupMacro and true or false
  c.castsequence = SLASH_CASTSEQUENCE1 ~= nil
  c.startattack = SLASH_STARTATTACK1 ~= nil
  c.cancelform = SLASH_CANCELFORM1 ~= nil
  c.tm = SLASH_TARGET_MARKER1 ~= nil
  return c
end

-- 대상 규칙 --------------------------------------------------------------------
-- 각 규칙은 조건 묶음 목록이다. 비어 있으면 조건 없음 (= 내 대상).

ns.TargetRules = {
  harm = {
    { key = "target",    label = "내 대상" },
    { key = "mouseover", label = "마우스오버 → 대상" },
    { key = "focus",     label = "주시 → 대상",              focus = true },
    { key = "mofocus",   label = "마우스오버 → 주시 → 대상",  focus = true },
  },
  help = {
    { key = "target",    label = "내 대상" },
    { key = "mouseover", label = "마우스오버 → 대상" },
    { key = "moself",    label = "마우스오버 → 대상 → 자신" },
    { key = "self",      label = "자신" },
    { key = "focus",     label = "주시 → 대상",              focus = true },
  },
}

local function unit(u)
  if ns.Caps.at or not ns.Caps.legacy then return "@" .. u end
  return "target=" .. u
end

local function ruleGroups(rule, help)
  local kind = help and "help" or "harm"
  local dead = ns.Caps.nodead == false and "" or ",nodead"
  local mo = unit("mouseover") .. "," .. kind .. dead
  local fo = unit("focus") .. "," .. kind .. dead
  if rule == "mouseover" then return { mo, "" } end
  if rule == "focus" then return { fo, "" } end
  if rule == "mofocus" then return { mo, fo, "" } end
  if rule == "self" then return { unit("player") } end
  if rule == "moself" then return { mo, kind .. dead, unit("player") } end
  return {}
end

-- 조건 문자열. extra 가 있으면 모든 묶음에 덧붙인다 (예: "mod:shift")
function ns.Condition(rule, help, extra)
  local groups = ruleGroups(rule, help)
  if #groups == 0 then
    return extra and ("[" .. extra .. "] ") or ""
  end
  local out = {}
  for _, g in ipairs(groups) do
    if extra then g = (g == "" and extra) or (g .. "," .. extra) end
    out[#out + 1] = "[" .. g .. "]"
  end
  return table.concat(out) .. " "
end

function ns.RuleUsable(r)
  return not r.focus or ns.Caps.focus
end

-- 템플릿 → 매크로 본문 ------------------------------------------------------------
-- 줄 문법:
--   {key}            빈칸 값 (주문 = 한글 이름, 대상 = 조건, 선택 = 값, 아이템 = 이름)
--   {key+mod:shift}  대상 조건 모든 묶음에 조건 덧붙이기
--   {key.spell}      선택지에 딸린 주문 이름
--   ?key 줄          체크가 켜졌을 때만 넣는 줄,  ?!key 줄  꺼졌을 때만

local function paramOf(t, key)
  for _, p in ipairs(t.params) do
    if p.key == key then return p end
  end
end

local function choiceOption(p, v)
  for _, o in ipairs(p.options) do
    if o.value == v then return o end
  end
end

function ns.Render(t, values)
  local missing
  local function value(key, extra, field)
    local p = paramOf(t, key)
    if not p then return "{" .. key .. "}" end
    local v = values[key]
    if p.type == "target" then
      return ns.Condition(v or p.default or "target", t.help or p.help, extra)
    elseif p.type == "spell" then
      local name = v and ns.SpellInfo(v)
      if not name then missing = missing or p.label return "" end
      return name
    elseif p.type == "item" then
      if not (v and v.name) then missing = missing or p.label return "" end
      return v.name
    elseif p.type == "choice" then
      local o = choiceOption(p, v or p.default)
      if not o then missing = missing or p.label return "" end
      if field == "spell" then
        local name = o.spell and ns.SpellInfo(o.spell)
        if not name then missing = missing or p.label return "" end
        return name
      end
      return o.value
    elseif p.type == "check" then
      return ""
    end
    return ""
  end

  local out = {}
  for _, line in ipairs(t.lines) do
    local keep = true
    local neg, key, rest = line:match("^%?(!?)([%w_]+)%s+(.*)$")
    if key then
      local on = values[key]
      if on == nil then on = (paramOf(t, key) or {}).default end
      on = on and true or false
      if neg == "!" then on = not on end
      keep = on
      line = rest
    end
    if keep then
      line = line:gsub("{([%w_]+)%+([^}]+)}", function(k, extra) return value(k, extra) end)
      line = line:gsub("{([%w_]+)%.([%w_]+)}", function(k, field) return value(k, nil, field) end)
      line = line:gsub("{([%w_]+)}", function(k) return value(k) end)
      line = line:gsub("%s+$", "")
      if line:match("%S") then out[#out + 1] = line end
    end
  end
  if missing then return nil, "빈칸을 채우세요: " .. missing end
  local body = table.concat(out, "\n")
  if t.fix then body = t.fix(body, values) end
  if #body > ns.BODY_MAX then
    return body, ("매크로가 너무 깁니다 (%d / %d 바이트). 옵션을 줄이세요."):format(#body, ns.BODY_MAX)
  end
  return body
end

-- 템플릿을 쓸 수 있는가? (주문 빈칸마다 배운 주문이 하나라도 있어야 함)
local NEEDS = {
  focus = { "focus", "이 클라이언트는 주시 대상을 지원하지 않음" },
  castsequence = { "castsequence", "이 클라이언트는 /castsequence 를 지원하지 않음" },
  startattack = { "startattack", "이 클라이언트는 /startattack 을 지원하지 않음" },
  cancelform = { "cancelform", "이 클라이언트는 /cancelform 을 지원하지 않음" },
  tm = { "tm", "이 클라이언트는 /tm (징표) 을 지원하지 않음" },
}

function ns.TemplateUsable(t)
  if t.needs then
    local n = NEEDS[t.needs]
    if n and not ns.Caps[n[1]] then return false, n[2] end
  end
  for _, p in ipairs(t.params) do
    if p.type == "spell" and (p.pet or p.any) then
      -- 소환수 주문 / 아무 주문: 항상 고를 수 있음
    elseif p.type == "spell" then
      local any = false
      for _, id in ipairs(p.spells) do
        if ns.SpellKnown(id) then any = true break end
      end
      if not any then return false, "필요한 주문을 아직 배우지 않음" end
    elseif p.type == "choice" then
      local any = false
      for _, o in ipairs(p.options) do
        if not o.spell or ns.SpellKnown(o.spell) then any = true break end
      end
      if not any then return false, "필요한 주문을 아직 배우지 않음" end
    end
  end
  return true
end

-- 기본 빈칸 값
function ns.DefaultValues(t)
  local v = {}
  for _, p in ipairs(t.params) do
    if p.type == "spell" then
      for _, id in ipairs(p.spells) do
        if p.pet or ns.SpellKnown(id) then v[p.key] = id break end
      end
      v[p.key] = v[p.key] or (p.pet and p.spells[1]) or nil
    elseif p.type == "target" then
      local d = p.default or "target"
      local rules = ns.TargetRules[(t.help or p.help) and "help" or "harm"]
      for _, r in ipairs(rules) do
        if r.key == d and not ns.RuleUsable(r) then d = "mouseover" end
      end
      v[p.key] = d
    elseif p.type == "check" then
      v[p.key] = p.default and true or false
    elseif p.type == "choice" then
      v[p.key] = p.default or p.options[1].value
      local o = choiceOption(p, v[p.key])
      if o and o.spell and not ns.SpellKnown(o.spell) then
        for _, o2 in ipairs(p.options) do
          if not o2.spell or ns.SpellKnown(o2.spell) then v[p.key] = o2.value break end
        end
      end
    elseif p.type == "item" then
      local items = ns.BagItems(p.filter)
      if p.match then
        for _, it in ipairs(items) do
          if it.name:find(p.match, 1, true) then v[p.key] = { id = it.id, name = it.name } break end
        end
      end
    end
  end
  return v
end

-- 매크로 다루기 ------------------------------------------------------------------

function ns.MacroLimits()
  local acc, char = GetNumMacros()
  return acc or 0, char or 0, MAX_ACCOUNT_MACROS or 120, MAX_CHARACTER_MACROS or 18
end

local function isCharIndex(idx)
  return idx > (MAX_ACCOUNT_MACROS or 120)
end

local function ownedStore(perChar)
  return perChar and MacroKitCharDB.owned or MacroKitDB.owned
end

-- 이 애드온이 만든 매크로 기록 (지금도 남아 있는 것만)
function ns.Owned(name)
  local idx = GetMacroIndexByName(name)
  if not idx or idx == 0 then return nil end
  local rec = (isCharIndex(idx) and MacroKitCharDB.owned or MacroKitDB.owned)[name]
  return rec, idx
end

-- 같은 템플릿으로 만든 기존 매크로 이름 (다시 열면 그 이름을 기본으로 보여 준다)
function ns.OwnedNameFor(tid, perChar)
  for name, rec in pairs(ownedStore(perChar)) do
    if rec.tid == tid and ns.Owned(name) then return name, rec end
  end
end

-- 남아 있는 내 매크로 목록 (지워진 기록은 정리)
function ns.OwnedList()
  local list = {}
  for _, perChar in ipairs({ false, true }) do
    local store = ownedStore(perChar)
    for name, rec in pairs(store) do
      local idx = GetMacroIndexByName(name)
      if idx and idx > 0 and isCharIndex(idx) == perChar then
        list[#list + 1] = { name = name, rec = rec, index = idx, perChar = perChar }
      else
        store[name] = nil
      end
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

local function copy(v)
  local c = {}
  for k, x in pairs(v) do c[k] = type(x) == "table" and copy(x) or x end
  return c
end

local function utf8len(s)
  return (strlenutf8 and strlenutf8(s)) or #s
end

-- 등록 상태: "new" / "overwrite" / 오류 문자열
function ns.RegisterState(name, perChar)
  if InCombatLockdown() then return "전투 중에는 매크로를 만들 수 없습니다. 전투가 끝나면 다시 누르세요." end
  if not ns.Caps.macroApi then return "이 클라이언트는 애드온의 매크로 만들기를 지원하지 않습니다." end
  name = strtrim(name or "")
  if name == "" then return "매크로 이름을 입력하세요." end
  if utf8len(name) > ns.NAME_MAX then return ("이름은 %d글자까지입니다."):format(ns.NAME_MAX) end
  local idx = GetMacroIndexByName(name)
  if idx and idx > 0 then
    local rec = ns.Owned(name)
    if not rec then return "같은 이름의 매크로가 이미 있습니다 (직접 만든 매크로는 건드리지 않습니다). 이름을 바꾸세요." end
    if isCharIndex(idx) ~= perChar then
      return ("이 이름은 이미 %s 매크로로 있습니다. 이름을 바꾸거나 '내 매크로'에서 지우세요."):format(isCharIndex(idx) and "캐릭터 전용" or "공용")
    end
    return "overwrite"
  end
  local acc, char, maxAcc, maxChar = ns.MacroLimits()
  if perChar and char >= maxChar then return ("캐릭터 전용 매크로 칸이 꽉 찼습니다 (%d/%d)."):format(char, maxChar) end
  if not perChar and acc >= maxAcc then return ("공용 매크로 칸이 꽉 찼습니다 (%d/%d)."):format(acc, maxAcc) end
  return "new"
end

-- 등록. 성공하면 true, 매크로 번호, 안내 / 실패하면 false, 이유
function ns.Register(t, values, name, perChar)
  name = strtrim(name or "")
  local state = ns.RegisterState(name, perChar)
  if state ~= "new" and state ~= "overwrite" then return false, state end
  local body, err = ns.Render(t, values)
  if not body or err then return false, err end

  local idx
  if state == "overwrite" then
    idx = EditMacro(GetMacroIndexByName(name), name, ns.ICON, body)
  else
    idx = CreateMacro(name, ns.ICON, body, perChar)
  end
  idx = GetMacroIndexByName(name)
  if not idx or idx == 0 then return false, "매크로를 만들지 못했습니다 (게임이 거절함)." end
  ownedStore(perChar)[name] = { tid = t.id, values = copy(values), time = time() }
  local scope = perChar and "캐릭터 전용" or "공용"
  return true, idx, ("'%s' 를 %s 매크로로 %s. 아이콘을 행동 단축바로 끌어다 놓으세요."):format(name, scope, state == "overwrite" and "고쳤습니다" or "만들었습니다")
end

function ns.Delete(name)
  if InCombatLockdown() then return false, "전투 중에는 매크로를 지울 수 없습니다." end
  local rec, idx = ns.Owned(name)
  if not rec then return false, "이 애드온이 만든 매크로가 아닙니다." end
  local perChar = isCharIndex(idx)
  DeleteMacro(idx)
  ownedStore(perChar)[name] = nil
  return true, ("'%s' 매크로를 지웠습니다."):format(name)
end
