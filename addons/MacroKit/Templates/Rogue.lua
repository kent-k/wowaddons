-- 도적 템플릿
local _, ns = ...
local S = ns.S

ns.AddTemplates("ROGUE", {
  {
    id = "ro.opener", cat = "stealth", name = "시작기술",
    title = "은신 + 시작 기술",
    desc = "은신하지 않았으면 은신하고, 은신 중이면 시작 기술을 씁니다.",
    params = {
      { key = "spell", type = "spell", label = "시작 기술", spells = { S(1833), S(8676), S(703), S(6770), S(921) } },
      { key = "stealth", type = "spell", label = "은신", spells = { S(1784) } },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip {spell}", "/cast [nostealth] {stealth}; {t}{spell}" },
  },
  {
    id = "ro.sap", cat = "control", name = "기절",
    title = "기절시키기 (마우스오버 / 주시)",
    desc = "마우스를 올린 적이나 주시 대상을 기절시킵니다. 은신 중에만 쓸 수 있습니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(6770) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "ro.cc", cat = "control", name = "실명",
    title = "실명 / 급소 가격 / 후려치기",
    desc = "제어 기술을 마우스를 올린 적이나 주시 대상에게 씁니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(2094), S(408), S(1776) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "ro.kick", cat = "interrupt", name = "발차기",
    title = "발차기 (마우스오버 / 주시)",
    desc = "적의 시전을 끊습니다. 내 대상을 바꾸지 않아도 됩니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(1766) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "ro.builder", cat = "attack", name = "기본기술",
    title = "기본 기술 + 공격 시작",
    desc = "자동 공격을 켜면서 연계 점수를 쌓는 기술을 씁니다.",
    params = {
      { key = "spell", type = "spell", label = "기술", spells = { S(1752), S(53) } },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip", "/startattack", "/cast {t}{spell}" },
  },
  {
    id = "ro.finisher", cat = "attack", name = "마무리",
    title = "마무리 기술 두 개 한 버튼",
    desc = "그냥 누르면 첫째 마무리, Shift 를 누르고 누르면 둘째 마무리.",
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(2098), S(5171), S(1943), S(408) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(5171), S(2098), S(1943), S(408) } },
      { key = "cb", type = "check", label = "냉혈 먼저 (특성)", default = false },
    },
    lines = { "#showtooltip", "?cb /cast {cb_spell}", "/startattack", "/cast [mod:shift] {b}; {a}" },
    fix = function(body) return (body:gsub("{cb_spell}", ns.SpellInfo(14177) or "냉혈")) end,
  },
  {
    id = "ro.escape", cat = "defense", name = "위급",
    title = "위급 버튼",
    desc = "그냥 누르면 회피, Shift 를 누르고 누르면 소멸.",
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(5277), S(2983), S(1856) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(1856), S(2983), S(5277) } },
    },
    lines = { "#showtooltip", "/cast [mod:shift] {b}; {a}" },
  },
})
