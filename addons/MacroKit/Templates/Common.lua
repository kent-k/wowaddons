-- 공통 템플릿 (모든 직업)
-- 형식은 docs/MacroKit.md 7장. 주문 번호는 S(번호) 로 쓴다 (check_spells.py 가 검증).
local _, ns = ...

ns.AddTemplates("COMMON", {
  {
    id = "common.startattack", cat = "attack", name = "공격+기술",
    needs = "startattack",
    title = "공격 시작 + 기술",
    desc = "근접 자동 공격을 켜면서 기술을 씁니다. 기술이 실패해도 자동 공격은 시작됩니다.",
    params = {
      { key = "spell", type = "spell", label = "기술", spells = {}, any = true },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip", "/startattack", "/cast {t}{spell}" },
  },
  {
    id = "common.stopcast", cat = "attack", name = "끊고시전",
    title = "시전 끊고 시전",
    desc = "지금 시전 중인 주문을 끊고 바로 이 주문을 씁니다. 차단·위급 주문에 좋습니다.",
    params = {
      { key = "spell", type = "spell", label = "주문", spells = {}, any = true },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip", "/stopcasting", "/cast {t}{spell}" },
  },
  {
    id = "common.trinket", cat = "item", name = "장신구+주문",
    title = "장신구 + 주문",
    desc = "장신구를 켜고 이어서 주문을 씁니다. 장신구는 장착한 칸 번호로 씁니다.",
    params = {
      { key = "slot", type = "choice", label = "장신구", default = "13", options = {
        { value = "13", label = "위 칸 (13)" },
        { value = "14", label = "아래 칸 (14)" },
        { value = "both", label = "둘 다" },
      } },
      { key = "spell", type = "spell", label = "주문", spells = {}, any = true },
      { key = "t", type = "target", label = "대상", default = "target" },
    },
    lines = { "#showtooltip {spell}", "/use {slot}", "/cast {t}{spell}" },
    fix = function(body)   -- "둘 다" 는 두 줄로
      return (body:gsub("/use both", "/use 13\n/use 14"))
    end,
  },
  {
    id = "common.potion", cat = "item", name = "회복",
    title = "생명석 / 물약 한 버튼",
    desc = "그냥 누르면 첫째 아이템, Shift 를 누르고 누르면 둘째 아이템을 씁니다.",
    params = {
      { key = "a", type = "item", label = "그냥 누르면", filter = "use", match = "생명석" },
      { key = "b", type = "item", label = "Shift+누르면", filter = "use", match = "물약" },
    },
    lines = { "#showtooltip", "/use [mod:shift] {b}; {a}" },
  },
  {
    id = "common.fooddrink", cat = "item", name = "먹기",
    title = "음식 / 음료 한 버튼",
    desc = "그냥 누르면 음식, Shift 를 누르고 누르면 음료를 먹습니다.",
    params = {
      { key = "food", type = "item", label = "음식", filter = "use" },
      { key = "drink", type = "item", label = "음료 (Shift)", filter = "use" },
    },
    lines = { "#showtooltip", "/use [mod:shift] {drink}; {food}" },
  },
  {
    id = "common.mount", cat = "move", name = "탈것",
    title = "탈것 타기 / 내리기",
    desc = "타고 있지 않으면 탈것을 부르고, 타고 있으면 내립니다.",
    params = {
      { key = "mount", type = "item", label = "탈것 아이템", filter = "use" },
    },
    lines = { "#showtooltip {mount}", "/dismount [mounted]", "/use [nomounted] {mount}" },
  },
  {
    id = "common.nearest", cat = "target", name = "가까운적",
    needs = "startattack",
    title = "가까운 적 잡고 공격",
    desc = "대상이 없거나 죽었거나 적이 아니면 가까운 적을 대상으로 잡고 자동 공격을 시작합니다.",
    params = {},
    lines = { "/targetenemy [noharm][dead]", "/startattack" },
  },
  {
    id = "common.focus", cat = "target", name = "주시",
    title = "주시 대상 지정 / 해제",
    desc = "마우스를 올린 대상(없으면 내 대상)을 주시 대상으로 지정합니다. Shift 를 누르고 누르면 해제합니다. 주시를 지원하는 클라이언트에서만 동작합니다.",
    needs = "focus",
    params = {},
    lines = { "/clearfocus [mod:shift]", "/stopmacro [mod:shift]", "/focus [@mouseover,exists][]" },
  },
  {
    id = "common.mark", cat = "target", name = "징표",
    needs = "tm",
    title = "공격대 징표 붙이기",
    desc = "대상에 징표를 붙입니다. Shift 를 누르고 누르면 지웁니다.",
    params = {
      { key = "mark", type = "choice", label = "징표", default = "8", options = {
        { value = "8", label = "해골" }, { value = "7", label = "가위표" }, { value = "6", label = "네모" },
        { value = "5", label = "달" }, { value = "4", label = "세모" }, { value = "3", label = "다이아몬드" },
        { value = "2", label = "동그라미" }, { value = "1", label = "별" },
      } },
    },
    lines = { "/tm [mod:shift] 0; {mark}" },
  },
})
