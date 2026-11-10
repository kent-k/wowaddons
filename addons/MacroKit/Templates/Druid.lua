-- 드루이드 템플릿
-- 변신 번호는 배운 변신에 따라 바뀌므로 [form:N] 대신 "!변신" (이미 그 변신이면 풀지 않음) 을 쓴다.
local _, ns = ...
local S = ns.S

local FORMS = {
  { value = "bear", label = "곰", spell = S(5487) },
  { value = "direbear", label = "광포한 곰", spell = S(9634) },
  { value = "cat", label = "표범", spell = S(768) },
  { value = "moonkin", label = "달빛야수", spell = S(24858) },
}

ns.AddTemplates("DRUID", {
  {
    id = "dr.formskill", cat = "form", name = "변신기술",
    title = "변신 + 기술",
    desc = "변신하지 않았으면 먼저 변신하고, 이미 그 모습이면 기술을 씁니다. 한 버튼으로 변신과 기술을 함께 씁니다.",
    params = {
      { key = "form", type = "choice", label = "변신", default = "bear", options = FORMS },
      { key = "spell", type = "spell", label = "기술", spells = { S(6807), S(779), S(6795), S(99), S(5211), S(1082), S(5221), S(1822), S(22568), S(1079), S(8921), S(5176), S(2912) } },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip {spell}", "/cast !{form.spell}", "/cast {t}{spell}" },
  },
  {
    id = "dr.cancelheal", cat = "form", name = "풀고치유",
    title = "변신 풀고 치유",
    desc = "곰·표범 모습이면 변신을 풀고 바로 치유 주문을 씁니다 (한 번 더 누르면 시전).",
    help = true,
    needs = "cancelform",
    params = {
      { key = "spell", type = "spell", label = "치유 주문", spells = { S(5185), S(8936), S(774) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip {spell}", "/cancelform [form]", "/cast {t}{spell}" },
  },
  {
    id = "dr.heal", cat = "heal", name = "치유",
    title = "치유 (마우스오버 → 대상 → 자신)",
    desc = "공격대 창에 마우스를 올리고 누르면 그 사람을 치유합니다. 없으면 내 아군 대상, 그것도 없으면 나.",
    help = true,
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(5185), S(774), S(8936) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "dr.ns", cat = "heal", name = "신속치유",
    title = "자연의 신속함 + 치유의 손길",
    desc = "자연의 신속함을 켜고 바로 치유합니다. 처음 누르면 신속함, 한 번 더 누르면 즉시 치유가 나갑니다.",
    help = true,
    params = {
      { key = "ns", type = "spell", label = "신속함", spells = { S(17116) } },
      { key = "spell", type = "spell", label = "치유 주문", spells = { S(5185), S(8936) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip {spell}", "/cast {ns}", "/cast {t}{spell}" },
  },
  {
    id = "dr.dispel", cat = "dispel", name = "해제",
    title = "저주 해제 / 독 해제 (마우스오버)",
    desc = "그냥 누르면 저주 해제, Shift 를 누르고 누르면 독 해제. 마우스를 올린 아군 → 대상 → 나.",
    help = true,
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(2782), S(2893) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(2893), S(2782) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip", "/cast {t+mod:shift}{b}; {t}{a}" },
  },
  {
    id = "dr.cc", cat = "control", name = "뿌리",
    title = "휘감는 뿌리 / 겨울잠 (마우스오버 / 주시)",
    desc = "마우스를 올린 적이나 주시 대상에게 묶기를 겁니다. 내 대상을 바꾸지 않아도 됩니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(339), S(2637) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "dr.innervate", cat = "buff", name = "정신자극",
    title = "정신 자극 (마우스오버 → 대상 → 자신)",
    desc = "마나가 부족한 치유사에게 정신 자극을 겁니다.",
    help = true,
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(29166) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
      { key = "say", type = "check", label = "귓속말로 알리기", default = true },
    },
    lines = { "#showtooltip", "/cast {t}{spell}", "?say /w %t 정신 자극 걸었어요!" },
  },
  {
    id = "dr.rebirth", cat = "buff", name = "환생",
    title = "환생 (마우스오버)",
    desc = "죽은 아군에게 마우스를 올리고 누르면 전투 중 부활을 겁니다. 없으면 내 대상.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(20484) } },
      { key = "say", type = "check", label = "파티에 알리기", default = true },
    },
    lines = { "#showtooltip", "/cast [@mouseover,help,dead][] {spell}", "?say /p %t 님 환생 겁니다." },
  },
  {
    id = "dr.prowl", cat = "stealth", name = "숨기",
    title = "숨기 + 시작 기술",
    desc = "표범 모습에서 숨지 않았으면 숨고, 숨어 있으면 시작 기술을 씁니다. 표범이 아니면 먼저 표범으로 변신합니다.",
    params = {
      { key = "spell", type = "spell", label = "시작 기술", spells = { S(6785), S(9005), S(5221), S(1822) } },
      { key = "prowl", type = "spell", label = "숨기", spells = { S(5215) } },
      { key = "cat", type = "spell", label = "표범 변신", spells = { S(768) } },
    },
    lines = { "#showtooltip {spell}", "/cast !{cat}", "/cast [nostealth] {prowl}; {spell}" },
  },
})
