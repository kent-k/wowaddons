-- 사냥꾼 템플릿
local _, ns = ...
local S = ns.S

ns.AddTemplates("HUNTER", {
  {
    id = "hu.shot", cat = "attack", name = "사격",
    title = "자동 사격 + 사격 기술",
    desc = "자동 사격을 켜면서 사격 기술을 씁니다. 자동 사격은 꺼지지 않습니다.",
    params = {
      { key = "spell", type = "spell", label = "기술", spells = { S(3044), S(2643), S(19434), S(1978), S(5116) } },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip {spell}", "/cast !{auto}", "/cast {t}{spell}" },
    fix = function(body) return (body:gsub("{auto}", ns.SpellInfo(75) or "자동 사격")) end,
  },
  {
    id = "hu.mark", cat = "attack", name = "징표",
    title = "사냥꾼의 징표 + 소환수 공격",
    desc = "대상에 사냥꾼의 징표를 걸고 소환수를 보냅니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(1130) } },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}", "/petattack {t}" },
  },
  {
    id = "hu.sting", cat = "attack", name = "쐐기",
    title = "쐐기 (마우스오버)",
    desc = "마우스를 올린 적에게 쐐기를 겁니다. 여러 적에게 돌릴 때 좋습니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(1978) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "hu.trap", cat = "control", name = "죽척덫",
    title = "덫 (전투 중이면 죽은척하기 먼저)",
    desc = "전투 중이면 먼저 죽은척하기로 전투를 끊고, 한 번 더 누르면 덫을 놓습니다. 전투 중이 아니면 바로 덫.",
    params = {
      { key = "spell", type = "spell", label = "덫", spells = { S(1499), S(13809) } },
      { key = "fd", type = "spell", label = "죽은척하기", spells = { S(5384) } },
    },
    lines = { "#showtooltip {spell}", "/cast [combat] {fd}; {spell}" },
  },
  {
    id = "hu.cc", cat = "control", name = "산탄",
    title = "분산 사격 / 평정의 사격 (마우스오버 / 주시)",
    desc = "마우스를 올린 적이나 주시 대상에게 바로 씁니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(19503), S(19801), S(5116) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "hu.melee", cat = "attack", name = "근접",
    title = "근접 기술 한 버튼",
    desc = "랩터의 일격과 자동 공격을 함께 씁니다. Shift 를 누르고 누르면 날개 절단.",
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(2973), S(1495), S(2974) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(2974), S(1495), S(781) } },
    },
    lines = { "#showtooltip", "/startattack", "/cast [mod:shift] {b}; {a}" },
  },
  {
    id = "hu.pet", cat = "pet", name = "소환수",
    title = "소환수 부르기 / 되살리기 / 치료",
    desc = "소환수가 없으면 부르고, 죽어 있으면 되살리고, 살아 있으면 치료합니다. Shift 를 누르고 누르면 되살리기.",
    params = {
      { key = "call", type = "spell", label = "부르기", spells = { S(883) } },
      { key = "revive", type = "spell", label = "되살리기", spells = { S(982) } },
      { key = "mend", type = "spell", label = "치료", spells = { S(136) } },
    },
    lines = { "#showtooltip", "/cast [mod:shift] {revive}; [nopet] {call}; [@pet,dead] {revive}; [@pet] {mend}" },
  },
  {
    id = "hu.aspect", cat = "buff", name = "상",
    title = "상 두 개 한 버튼",
    desc = "그냥 누르면 첫째 상, Shift 를 누르고 누르면 둘째 상.",
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(13165), S(13163), S(5118), S(13159) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(5118), S(13159), S(13163), S(13165) } },
    },
    lines = { "#showtooltip", "/cast [mod:shift] {b}; {a}" },
  },
})
