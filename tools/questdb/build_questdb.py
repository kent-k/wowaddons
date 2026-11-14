"""QuestieDB(Forever) 에서 '아이템 ↔ 퀘스트' 관계만 뽑아 addons/QuestKit/QuestData.lua 를 만든다.

사용: python tools/questdb/build_questdb.py <foreverItemDB.lua> <foreverQuestDB.lua>
원본: https://github.com/Questie/QuestieDB (data/Forever) — GPLv3 조건으로 사용, 출처 표기.
Lua 코드를 실행하지 않고 표 리터럴만 직접 파싱한다.
"""
import re, sys, os

def parse_table_block(text, marker):
    i = text.index(marker)
    i = text.index("return {", i) + len("return ")
    val, _ = parse_value(text, i)
    return val

def skip_ws(s, i):
    n = len(s)
    while i < n:
        c = s[i]
        if c in " \t\r\n,;":
            i += 1
        elif s.startswith("--", i):
            j = s.find("\n", i)
            i = n if j < 0 else j + 1
        else:
            break
    return i

NUM = re.compile(r"-?(0x[0-9a-fA-F]+|\d+(\.\d+)?([eE][-+]?\d+)?)")

def parse_value(s, i):
    i = skip_ws(s, i)
    c = s[i]
    if c == "{":
        return parse_tbl(s, i)
    if c in "'\"":
        q = c; i += 1; out = []
        while s[i] != q:
            if s[i] == "\\":
                out.append(s[i + 1]); i += 2
            else:
                out.append(s[i]); i += 1
        return "".join(out), i + 1
    if s.startswith("nil", i): return None, i + 3
    if s.startswith("true", i): return True, i + 4
    if s.startswith("false", i): return False, i + 5
    m = NUM.match(s, i)
    if m:
        t = m.group(0)
        v = int(t, 16) if "x" in t.lower() else (float(t) if ("." in t or "e" in t.lower()) else int(t))
        return v, m.end()
    raise ValueError("unexpected %r at %d" % (s[i:i + 30], i))

def parse_tbl(s, i):
    i += 1
    arr, d, pos = [], {}, 1
    while True:
        i = skip_ws(s, i)
        if s[i] == "}":
            if d:
                for k, v in enumerate(arr, 1): d.setdefault(k, v)
                return d, i + 1
            return arr, i + 1
        if s[i] == "[":
            k, i = parse_value(s, i + 1)
            i = skip_ws(s, i); assert s[i] == "]"; i += 1
            i = skip_ws(s, i); assert s[i] == "="; i += 1
            v, i = parse_value(s, i)
            d[k] = v
        else:
            v, i = parse_value(s, i)
            arr.append(v)

def get(rec, k):
    if isinstance(rec, dict): return rec.get(k)
    return rec[k - 1] if len(rec) >= k else None

def main(item_path, quest_path, out_path):
    items = parse_table_block(open(item_path, encoding="utf-8").read(), "QuestieDB.itemData")
    quests = parse_table_block(open(quest_path, encoding="utf-8").read(), "QuestieDB.questData")
    rel = {}
    def add(item, q):
        if isinstance(item, int) and isinstance(q, int): rel.setdefault(item, set()).add(q)
    for qid, q in quests.items():
        obj = get(q, 10)
        if obj:
            for o in (get(obj, 3) or []):
                if o: add(get(o, 1), qid)
            for o in (get(obj, 6) or []):           # 주문 목표에 쓰는 아이템
                if o and get(o, 3): add(get(o, 3), qid)
        add(get(q, 11), qid)                         # 퀘스트 주는 사람이 준 아이템
        for it in (get(q, 21) or []): add(it, qid)   # 목표는 아니지만 필요한 아이템
        sb = get(q, 2)
        if sb:
            for it in (get(sb, 3) or []): add(it, qid)
    for iid, it in items.items():
        sq = get(it, 5)
        if sq: add(iid, sq)
        for q in (get(it, 15) or []): add(iid, q)
        # 퀘스트 분류(12)인데 관계가 없는 아이템도 "알려진 퀘스트 아이템, 관계 없음" 으로 남긴다
        if get(it, 12) == 12 and iid not in rel: rel[iid] = set()
    used = set(q for s in rel.values() for q in s if q in quests)
    # 쓰이는 퀘스트의 종족/직업 제한, 같이 못 하는 퀘스트(exclusiveTo)
    qinfo = {}
    for qid in sorted(used):
        q = quests[qid]
        races, classes, excl = get(q, 6) or 0, get(q, 7) or 0, [x for x in (get(q, 16) or []) if isinstance(x, int)]
        flags = get(q, 24) or 0
        rep = 1 if (isinstance(flags, int) and flags & 1) else 0
        if races or classes or excl or rep:
            qinfo[qid] = (races, classes, excl, rep)
    L = ["-- 자동 생성: tools/questdb/build_questdb.py  (손으로 고치지 말 것)",
         "-- 출처: QuestieDB data/Forever (https://github.com/Questie/QuestieDB), GPLv3 조건으로 사용. 아이템↔퀘스트 관계만 뽑았다.",
         "local _, ns = ...",
         "-- [아이템 번호] = { 관련 퀘스트 번호, ... }  (빈 표 = 퀘스트 아이템이지만 관련 퀘스트 정보 없음)",
         "ns.QuestItems = {"]
    for iid in sorted(rel):
        qs = sorted(q for q in rel[iid] if q in quests)
        L.append("[%d]={%s}," % (iid, ",".join(map(str, qs))))
    L.append("}")
    L.append("-- [퀘스트 번호] = { 종족 비트, 직업 비트, {같이 못 하는 퀘스트}, 반복(1) }  (제한 없는 퀘스트는 생략)")
    L.append("ns.QuestRules = {")
    for qid in sorted(qinfo):
        r, c, e, rep = qinfo[qid]
        L.append("[%d]={%d,%d,{%s},%d}," % (qid, r, c, ",".join(map(str, e)), rep))
    L.append("}")
    open(out_path, "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")
    print("items", len(rel), "with quests", sum(1 for s in rel.values() if s), "quests used", len(used), "rules", len(qinfo), "bytes", os.path.getsize(out_path))

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "..", "addons", "QuestKit", "QuestData.lua")
    main(sys.argv[1], sys.argv[2], os.path.normpath(out))
