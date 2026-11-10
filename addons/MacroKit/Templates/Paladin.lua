-- 성기사 템플릿
local _, ns = ...
local S = ns.S

ns.AddTemplates("PALADIN", {
  {
    id = "pa.heal", cat = "heal", name = "치유",
    title = "치유 (마우스오버 → 대상 → 자신)",
    desc = "공격대 창에 마우스를 올리고 누르면 그 사람을 치유합니다. 없으면 내 아군 대상, 그것도 없으면 나.",
    help = true,
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(635), S(19750), S(20473) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "pa.favor", cat = "heal", name = "은총치유",
    title = "신의 은총 + 성스러운 빛",
    desc = "신의 은총을 켜고 바로 치유합니다 (다음 치유가 극대화).",
    help = true,
    params = {
      { key = "fav", type = "spell", label = "신의 은총", spells = { S(20216) } },
      { key = "spell", type = "spell", label = "치유 주문", spells = { S(635), S(19750) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip {spell}", "/cast {fav}", "/cast {t}{spell}" },
  },
  {
    id = "pa.cleanse", cat = "dispel", name = "정화",
    title = "정화 (마우스오버 → 대상 → 자신)",
    desc = "아군의 해로운 효과를 지웁니다.",
    help = true,
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(4987), S(1152) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "pa.blessing", cat = "buff", name = "축복",
    title = "보호용 축복 (마우스오버 → 대상 → 자신)",
    desc = "보호의 축복·자유의 축복 같은 위급 축복을 마우스를 올린 아군에게 바로 겁니다.",
    help = true,
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(1022), S(1044), S(6940) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "pa.loh", cat = "defense", name = "신축",
    title = "신의 축복 (마우스오버 → 대상 → 자신)",
    desc = "마우스를 올린 아군의 생명력을 모두 채웁니다.",
    help = true,
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(633) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
      { key = "say", type = "check", label = "파티에 알리기", default = false },
    },
    lines = { "#showtooltip", "/cast {t}{spell}", "?say /p %t 님에게 신의 축복!" },
  },
  {
    id = "pa.bubble", cat = "defense", name = "무적",
    title = "천상의 보호막 (위급 버튼)",
    desc = "천상의 보호막을 켭니다. Shift 를 누르고 누르면 보호막을 끕니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(642) } },
    },
    lines = { "#showtooltip", "/cancelaura [mod:shift] {spell}", "/stopmacro [mod:shift]", "/cast {spell}" },
  },
  {
    id = "pa.judge", cat = "attack", name = "심판",
    title = "심판 + 문장",
    desc = "그냥 누르면 심판, Shift 를 누르고 누르면 문장을 다시 겁니다. 자동 공격도 켭니다.",
    params = {
      { key = "judge", type = "spell", label = "심판", spells = { S(20271) } },
      { key = "seal", type = "spell", label = "문장 (Shift)", spells = { S(21084), S(21082) } },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip", "/startattack", "/cast [mod:shift] {seal}; {t}{judge}" },
  },
  {
    id = "pa.hoj", cat = "control", name = "망치",
    title = "심판의 망치 (마우스오버 / 주시)",
    desc = "마우스를 올린 적이나 주시 대상을 기절시켜 시전을 끊습니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(853) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
})
