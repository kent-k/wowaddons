-- 사제 템플릿
local _, ns = ...
local S = ns.S

ns.AddTemplates("PRIEST", {
  {
    id = "pr.heal", cat = "heal", name = "치유",
    title = "치유 (마우스오버 → 대상 → 자신)",
    desc = "공격대 창에 마우스를 올리고 누르면 그 사람을 치유합니다. 없으면 내 아군 대상, 그것도 없으면 나.",
    help = true,
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(2061), S(2054), S(2060), S(2050), S(139) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "pr.shield", cat = "heal", name = "보호막",
    title = "보호막 / 소생 (마우스오버 → 대상 → 자신)",
    desc = "그냥 누르면 신의 권능: 보호막, Shift 를 누르고 누르면 소생.",
    help = true,
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(17), S(139) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(139), S(17) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip", "/cast {t+mod:shift}{b}; {t}{a}" },
  },
  {
    id = "pr.focus", cat = "heal", name = "집중치유",
    title = "내면의 집중력 + 치유",
    desc = "내면의 집중력을 켜고 바로 치유합니다 (마나 소모 없음).",
    help = true,
    params = {
      { key = "if", type = "spell", label = "내면의 집중력", spells = { S(14751) } },
      { key = "spell", type = "spell", label = "치유 주문", spells = { S(2060), S(2054), S(596) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip {spell}", "/cast {if}", "/cast {t}{spell}" },
  },
  {
    id = "pr.dispel", cat = "dispel", name = "해제",
    title = "마법 무효화 / 질병 치료 (마우스오버)",
    desc = "그냥 누르면 마법 무효화, Shift 를 누르고 누르면 질병 치료. 마우스를 올린 아군 → 대상 → 나.",
    help = true,
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(527), S(552), S(528) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(552), S(528), S(527) } },
      { key = "t", type = "target", label = "대상", default = "moself" },
    },
    lines = { "#showtooltip", "/cast {t+mod:shift}{b}; {t}{a}" },
  },
  {
    id = "pr.cc", cat = "control", name = "속박",
    title = "정신 지배 / 언데드 속박 (마우스오버 / 주시)",
    desc = "마우스를 올린 적이나 주시 대상에게 씁니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(9484), S(605) } },
      { key = "t", type = "target", label = "대상", default = "mofocus" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "pr.dot", cat = "attack", name = "고통",
    title = "어둠의 권능: 고통 (마우스오버)",
    desc = "마우스를 올린 적에게 도트를 겁니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(589) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
    },
    lines = { "#showtooltip", "/cast {t}{spell}" },
  },
  {
    id = "pr.nuke", cat = "attack", name = "공격",
    title = "공격 주문",
    desc = "정신 분열·성스러운 일격 같은 공격 주문. '시전 중이면 끊고 시전' 을 켜면 다른 주문을 끊고 바로 씁니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(8092), S(585), S(15407) } },
      { key = "t", type = "target", label = "대상", default = "target" },
      { key = "stop", type = "check", label = "시전 중이면 끊고 시전", default = false },
    },
    lines = { "#showtooltip", "?stop /stopcasting", "/cast {t}{spell}" },
  },
  {
    id = "pr.silence", cat = "interrupt", name = "침묵",
    title = "침묵 (마우스오버 / 주시)",
    desc = "적의 시전을 끊습니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = { S(15487) } },
      { key = "t", type = "target", label = "대상", default = "mouseover" },
    },
    lines = { "#showtooltip", "/stopcasting", "/cast {t}{spell}" },
  },
  {
    id = "pr.escape", cat = "defense", name = "위급",
    title = "위급 버튼",
    desc = "그냥 누르면 소실, Shift 를 누르고 누르면 영혼의 절규.",
    params = {
      { key = "a", type = "spell", label = "그냥 누르면", spells = { S(586), S(8122) } },
      { key = "b", type = "spell", label = "Shift+누르면", spells = { S(8122), S(586) } },
    },
    lines = { "#showtooltip", "/cast [mod:shift] {b}; {a}" },
  },
})
