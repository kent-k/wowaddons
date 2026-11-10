-- 마법사 템플릿
local _, ns = ...
local S = ns.S

ns.AddTemplates("MAGE", {
  {
    id = "ma.poly", cat = "control", name = "변이",
    title = "변이 (주시 / 마우스오버)",
    desc = "주시 대상이나 마우스를 올린 적을 변이시킵니다. 변이가 풀렸을 때 다시 걸기 쉽습니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(118) } },
      { key = "t", type = "target", label = "대상", default = "mofocus" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "ma.cs", cat = "interrupt", name = "차단",
    title = "마법 차단 (마우스오버 / 주시)",
    desc = "지금 시전 중인 주문을 끊고 적의 시전을 끊습니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(2139) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
    },
    lines = { "#showtooltip", "/stopcasting", "/cast {t}{spell}" },
  },
  {
    id = "ma.nuke", cat = "attack", name = "공격",
    title = "공격 주문",
    desc = "얼음 화살·화염구 같은 공격 주문. '시전 중이면 끊고 시전' 을 켜면 다른 주문을 끊고 바로 씁니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(116), S(133), S(2136), S(2948), S(120), S(1449) } },
      { key = "t", type = "target", label = "대상", default = "target" },
      { key = "stop", type = "check", label = "시전 중이면 끊고 시전", default = false },
    },
    lines = { "#showtooltip", "?stop /stopcasting", "/cast {t}{spell}" },
  },
  {
    id = "ma.cd", cat = "attack", name = "강화",
    title = "강화 주문 + 공격 주문",
    desc = "냉정·신비의 마법 강화·발화를 켜고 바로 공격 주문을 씁니다.",
    params = {
      { key = "cd", type = "spell", label = "강화 주문", spells = { S(12043), S(12042), S(11129) } },
      { key = "spell", type = "spell", label = "공격 주문", spells = { S(116), S(133), S(2136) } },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip {spell}", "/cast {cd}", "/cast {t}{spell}" },
  },
  {
    id = "ma.iceblock", cat = "defense", name = "얼방",
    title = "얼음 방패 (켜기 / 끄기)",
    desc = "얼음 방패를 켭니다. 이미 켜져 있으면 끕니다. Shift 를 누르고 누르면 한파.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(11958) } },
      { key = "snap", type = "spell", label = "Shift+누르면", spells = { S(12472), S(11958) } },
    },
    lines = { "#showtooltip", "/cast [mod:shift] {snap}", "/stopmacro [mod:shift]", "/cancelaura {spell}", "/cast {spell}" },
  },
  {
    id = "ma.nova", cat = "defense", name = "회오리점멸",
    title = "얼음 회오리 + 점멸",
    desc = "그냥 누르면 얼음 회오리, Shift 를 누르고 누르면 점멸.",
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(122), S(1953) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(1953), S(122) } },
    },
    lines = { "#showtooltip", "/cast [mod:shift] {b}; {a}" },
  },
  {
    id = "ma.decurse", cat = "dispel", name = "저주해제",
    title = "하급 저주 해제 (마우스오버 → 대상 → 자신)",
    desc = "아군의 저주를 지웁니다.",
    help = true,
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(475) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "ma.food", cat = "item", name = "음식물",
    title = "음식·음료 먹기 / 만들기",
    desc = "그냥 누르면 음료, Shift 는 음식을 먹습니다. Ctrl 을 누르고 누르면 음료를, Alt 는 음식을 만듭니다.",
    params = {
      { key = "drink", type = "item", label = "음료", filter = "use" },
      { key = "food", type = "item", label = "음식", filter = "use" },
      { key = "mkd", type = "spell", label = "음료 창조", spells = { S(5504) } },
      { key = "mkf", type = "spell", label = "음식 창조", spells = { S(587) } },
    },
    lines = { "#showtooltip", "/cast [mod:ctrl] {mkd}; [mod:alt] {mkf}", "/stopmacro [mod:ctrl][mod:alt]", "/use [mod:shift] {food}; {drink}" },
  },
  {
    id = "ma.gem", cat = "item", name = "마나석",
    title = "마나석 쓰기 / 만들기",
    desc = "그냥 누르면 마나석을 쓰고, Shift 를 누르고 누르면 마나석을 만듭니다.",
    params = {
      { key = "gem", type = "item", label = "마나석", filter = "use", match = "마나" },
      { key = "make", type = "spell", label = "만들기 주문", spells = { S(759) } },
    },
    lines = { "#showtooltip", "/cast [mod:shift] {make}", "/stopmacro [mod:shift]", "/use {gem}" },
  },
})
