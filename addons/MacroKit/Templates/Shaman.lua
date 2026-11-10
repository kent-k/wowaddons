-- 주술사 템플릿
local _, ns = ...
local S = ns.S

local STOP = { key = "stop", type = "check", label = "시전 중이면 끊고 시전", default = true }

ns.AddTemplates("SHAMAN", {
  {
    id = "sh.shock", cat = "interrupt", name = "충격",
    title = "충격 (차단 / 마우스오버)",
    desc = "대지 충격으로 적의 시전을 끊습니다. 시전 중인 번개를 끊고 바로 나가게 할 수 있습니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(8042), S(8050), S(8056) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
      STOP,
    },
    lines = { "#showtooltip", "?stop /stopcasting", "/cast {t}{spell}" },
  },
  {
    id = "sh.bolt", cat = "attack", name = "번개",
    title = "번개 (Shift = 연쇄 번개)",
    desc = "그냥 누르면 번개 화살, Shift 를 누르고 누르면 연쇄 번개를 씁니다.",
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(403), S(421) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(421), S(403) } },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip", "/cast {t+mod:shift}{b}; {t}{a}" },
  },
  {
    id = "sh.heal", cat = "heal", name = "치유",
    title = "치유 (마우스오버 → 대상 → 자신)",
    desc = "공격대 창에 마우스를 올리고 누르면 그 사람을 치유합니다. 없으면 내 아군 대상, 그것도 없으면 나.",
    help = true,
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(331), S(8004), S(1064) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "sh.ns", cat = "heal", name = "신속치유",
    title = "자연의 신속함 + 치유",
    desc = "자연의 신속함을 켜고 바로 치유합니다. 처음 누르면 신속함, 한 번 더 누르면 즉시 치유가 나갑니다.",
    help = true,
    params = {
      { key = "ns", type = "spell", label = "신속함", spells = { S(16188) } },
      { key = "spell", type = "spell", label = "치유 주문", spells = { S(331), S(8004), S(1064) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip {spell}", "/cast {ns}", "/cast {t}{spell}" },
  },
  {
    id = "sh.purge", cat = "dispel", name = "정화",
    title = "정화 (적의 이로운 효과 지우기)",
    desc = "마우스를 올린 적의 이로운 마법을 지웁니다. 없으면 내 대상.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(370) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "sh.cure", cat = "dispel", name = "해독",
    title = "해독 / 질병 치료 (마우스오버)",
    desc = "그냥 누르면 독, Shift 를 누르고 누르면 질병을 치료합니다. 마우스를 올린 아군 → 대상 → 나.",
    help = true,
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(526), S(2870) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(2870), S(526) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip", "/cast {t+mod:shift}{b}; {t}{a}" },
  },
  {
    id = "sh.totems", cat = "totem", name = "토템",
    title = "토템 네 개 차례로",
    desc = "누를 때마다 다음 토템을 세웁니다 (대지 → 불 → 물 → 바람). 전투가 끝나거나 15초가 지나면 처음부터.",
    needs = "castsequence",
    params = {
      { key = "earth", type = "spell", label = "대지", spells = { S(8075), S(8071), S(8143), S(2484) } },
      { key = "fire", type = "spell", label = "불", spells = { S(3599), S(27623) } },
      { key = "water", type = "spell", label = "물", spells = { S(5394), S(5675), S(16190) } },
      { key = "air", type = "spell", label = "바람", spells = { S(8512), S(8835), S(8177) } },
    },
    lines = { "#showtooltip", "/castsequence reset=combat/15 {earth}, {fire}, {water}, {air}" },
  },
  {
    id = "sh.wolf", cat = "move", name = "늑대",
    title = "늑대 정령",
    desc = "늑대 정령으로 변신합니다. 이미 늑대면 풀립니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(2645) } },
    },
    lines = { "#showtooltip", "/cast {spell}" },
  },
})
