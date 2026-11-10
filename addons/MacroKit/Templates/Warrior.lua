-- 전사 템플릿
-- 태세 번호: 1 = 전투, 2 = 방어, 3 = 광폭 (전사는 배운 순서와 상관없이 고정)
local _, ns = ...
local S = ns.S

local STANCES = {
  { value = "1", label = "전투 태세", spell = S(2457) },
  { value = "2", label = "방어 태세", spell = S(71) },
  { value = "3", label = "광폭 태세", spell = S(2458) },
}

ns.AddTemplates("WARRIOR", {
  {
    id = "wa.stanceskill", cat = "form", name = "태세기술",
    title = "태세 + 기술",
    desc = "필요한 태세가 아니면 먼저 태세를 바꾸고, 맞는 태세면 기술을 씁니다. 예) 전투 태세 + 돌진, 광폭 태세 + 봉쇄.",
    params = {
      { key = "stance", type = "choice", label = "태세", default = "1", options = STANCES },
      { key = "spell", type = "spell", label = "기술", spells = { S(100), S(20252), S(7384), S(5308), S(6552), S(72), S(355), S(694), S(6572), S(2565), S(871), S(18499), S(5246), S(1715) } },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip {spell}", "/cast [nostance:{stance}] {stance.spell}; {t}{spell}" },
  },
  {
    id = "wa.interrupt", cat = "interrupt", name = "차단",
    title = "차단 (태세에 맞게 자동)",
    desc = "전투·방어 태세면 방패 가격, 광폭 태세면 자루 공격으로 시전을 끊습니다. 방패가 없으면 방패 가격은 실패합니다.",
    params = {
      { key = "shield", type = "spell", label = "전투·방어 태세", spells = { S(72) } },
      { key = "pummel", type = "spell", label = "광폭 태세", spells = { S(6552) } },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip", "/cast {t+stance:1/2}{shield}; {t}{pummel}" },
  },
  {
    id = "wa.queue", cat = "attack", name = "영격",
    title = "영웅의 일격 / 회전베기",
    desc = "그냥 누르면 영웅의 일격, Shift 를 누르고 누르면 회전베기를 다음 공격에 겁니다.",
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(78), S(845) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(845), S(78) } },
      { key = "atk", type = "check", label = "자동 공격도 켜기", default = true },
    },
    lines = { "#showtooltip", "?atk /startattack", "/cast [mod:shift] {b}; {a}" },
  },
  {
    id = "wa.execute", cat = "attack", name = "제압마무리",
    title = "제압 / 마무리 일격",
    desc = "그냥 누르면 제압, Shift 를 누르고 누르면 마무리 일격.",
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(7384), S(5308) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(5308), S(7384) } },
    },
    lines = { "#showtooltip", "/startattack", "/cast [mod:shift] {b}; {a}" },
  },
  {
    id = "wa.taunt", cat = "defense", name = "도발",
    title = "도발 (마우스오버)",
    desc = "마우스를 올린 적을 도발합니다. 없으면 내 대상. 방어 태세가 아니면 먼저 방어 태세로 바꿉니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(355), S(694) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
      { key = "def", type = "check", label = "방어 태세로 자동 전환", default = true },
    },
    lines = { "#showtooltip {spell}", "?def /cast [nostance:2] {def_spell}", "/cast {t}{spell}" },
    fix = function(body) return (body:gsub("{def_spell}", ns.SpellInfo(71) or "방어 태세")) end,
  },
  {
    id = "wa.lastresort", cat = "defense", name = "방벽",
    title = "위급 버튼 (방패의 벽 + 장신구)",
    desc = "방패의 벽과 장신구를 함께 씁니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(871), S(2565) } },
      { key = "slot", type = "choice", label = "장신구", default = "13", options = {
        { value = "13", label = "위 칸 (13)" }, { value = "14", label = "아래 칸 (14)" }, { value = "", label = "안 씀" },
      } },
    },
    lines = { "#showtooltip {spell}", "/use {slot}", "/cast {spell}" },
    fix = function(body) return (body:gsub("/use\n", "")) end,
  },
  {
    id = "wa.bloodrage", cat = "utility", name = "피분노",
    title = "피의 분노 + 기술",
    desc = "피의 분노로 분노를 채우고 바로 기술을 씁니다.",
    params = {
      { key = "spell", type = "spell", label = "기술", spells = { S(5246), S(7386), S(6343), S(1160), S(78) } },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip {spell}", "/cast {br}", "/cast {t}{spell}" },
    fix = function(body) return (body:gsub("{br}", ns.SpellInfo(2687) or "피의 분노")) end,
  },
})
