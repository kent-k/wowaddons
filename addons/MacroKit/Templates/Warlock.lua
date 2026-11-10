-- 흑마법사 템플릿
local _, ns = ...
local S = ns.S

local STOP = { key = "stop", type = "check", label = "시전 중이면 끊고 시전", default = false }

ns.AddTemplates("WARLOCK", {
  {
    id = "wl.dot", cat = "attack", name = "도트",
    title = "도트 걸기 (마우스오버)",
    desc = "마우스를 올린 적에게 도트를 겁니다. 없으면 내 대상에게. 여러 적에게 도트를 돌릴 때 좋습니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(172), S(980), S(348), S(18265), S(603), S(702), S(1714), S(704) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "wl.nuke", cat = "attack", name = "어화",
    title = "직격 주문",
    desc = "어둠의 화살 같은 직격 주문. '시전 중이면 끊고 시전' 을 켜면 다른 주문을 끊고 바로 씁니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(686), S(5676), S(17877), S(6353), S(17962), S(1120), S(689) } },
      { key = "t", type = "target", label = "대상", default = "target" },
      STOP,
    },
    lines = { "#showtooltip", "?stop /stopcasting", "/cast {t}{spell}" },
  },
  {
    id = "wl.fear", cat = "control", name = "공포",
    title = "공포 (마우스오버 / 주시)",
    desc = "마우스를 올린 적이나 주시 대상에게 공포를 겁니다. 내 대상을 바꾸지 않아도 됩니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(5782), S(6789), S(5484) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
      STOP,
    },
    lines = { "#showtooltip", "?stop /stopcasting", "/cast {t}{spell}" },
  },
  {
    id = "wl.banish", cat = "control", name = "추방",
    title = "추방 (주시 / 마우스오버)",
    desc = "정령·악마를 추방합니다. 주시 대상에게 걸어 두면 다른 적을 때리면서 다시 걸기 쉽습니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(710) } },
      { key = "t", type = "target", label = "대상", default = "mofocus" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "wl.curse2", cat = "curse", name = "저주",
    title = "저주 두 개 한 버튼",
    desc = "그냥 누르면 첫째 저주, Shift 를 누르고 누르면 둘째 저주를 겁니다.",
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(980), S(702), S(1714), S(704), S(603) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(1714), S(702), S(704), S(980), S(603) } },
      { key = "t", type = "target", label = "대상", default = "target" },
      { key = "amp", type = "check", label = "저주 증폭 먼저 (특성)", default = false },
    },
    lines = { "#showtooltip", "?amp /cast {amp_spell}", "/cast {t+mod:shift}{b}; {t}{a}" },
    fix = function(body)
      local amp = ns.SpellInfo(18288) or "저주 증폭"
      return (body:gsub("{amp_spell}", amp))
    end,
  },
  {
    id = "wl.petattack", cat = "pet", name = "소환수공격",
    title = "소환수 공격 + 소환수 주문",
    desc = "소환수에게 공격을 시키고 소환수 주문도 씁니다. 소환수 주문은 그 소환수가 나와 있을 때만 나갑니다.",
    params = {
      { key = "spell", type = "spell", label = "소환수 주문", pet = true, spells = { S(19244), S(6358), S(19505), S(7812) } },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip", "/petattack {t}", "/cast {t}{spell}" },
  },
  {
    id = "wl.spelllock", cat = "interrupt", name = "주문잠금",
    title = "주문 잠금 (지옥사냥개)",
    desc = "지옥사냥개의 주문 잠금으로 적의 시전을 끊습니다. 마우스오버나 주시 대상에게 바로 쓸 수 있습니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", pet = true, spells = { S(19244) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "wl.devour", cat = "dispel", name = "마법삼키기",
    title = "마법 삼키기 (지옥사냥개)",
    desc = "지옥사냥개가 아군의 해로운 마법을 먹어 없앱니다. 마우스를 올린 아군 → 내 대상 → 나 순서.",
    help = true,
    params = {
      { key = "spell", type = "spell", label = "주문", pet = true, spells = { S(19505) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "wl.sacrifice", cat = "pet", name = "희생",
    title = "희생 (공허방랑자)",
    desc = "공허방랑자를 희생해 보호막을 얻습니다. 위급할 때 누르세요.",
    params = {
      { key = "spell", type = "spell", label = "주문", pet = true, spells = { S(7812) } },
    },
    lines = { "#showtooltip", "/cast {spell}" },
  },
  {
    id = "wl.lifetap", cat = "utility", name = "생명력전환",
    title = "생명력 전환",
    desc = "생명력을 마나로 바꿉니다. Shift 를 누르고 누르면 소환수에게 생명력 집중.",
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(1454) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(755), S(1454) } },
    },
    lines = { "#showtooltip", "/cast [mod:shift] {b}; {a}" },
  },
  {
    id = "wl.healthstone", cat = "item", name = "생명석",
    title = "생명석 쓰기 / 만들기",
    desc = "그냥 누르면 가방의 생명석을 쓰고, Shift 를 누르고 누르면 생명석을 만듭니다.",
    params = {
      { key = "stone", type = "item", label = "생명석", filter = "use", match = "생명석" },
      { key = "make", type = "spell", label = "만들기 주문", spells = { S(6201) } },
    },
    lines = { "#showtooltip", "/cast [mod:shift] {make}", "/stopmacro [mod:shift]", "/use {stone}" },
  },
  {
    id = "wl.soulstone", cat = "utility", name = "영혼석",
    title = "영혼석 걸기 (대상 → 자신)",
    desc = "가방의 영혼석을 아군 대상에게 겁니다. 대상이 없거나 적이면 나에게. Shift 를 누르고 누르면 영혼석을 만듭니다.",
    params = {
      { key = "stone", type = "item", label = "영혼석", filter = "use", match = "영혼석" },
      { key = "make", type = "spell", label = "만들기 주문", spells = { S(693) } },
    },
    lines = { "#showtooltip", "/cast [mod:shift] {make}", "/stopmacro [mod:shift]", "/use [help,nodead][@player] {stone}" },
  },
  {
    id = "wl.summon", cat = "utility", name = "소환의식",
    title = "소환 의식 (대상 알림)",
    desc = "소환 의식을 시작하면서 파티에 누구를 소환하는지 알립니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(698) } },
      { key = "say", type = "check", label = "파티에 알리기", default = true },
    },
    lines = { "#showtooltip", "?say /p %t 님 소환합니다. 클릭 부탁드려요!", "/cast {spell}" },
  },
})
