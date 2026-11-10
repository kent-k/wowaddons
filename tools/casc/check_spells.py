"""매크로 공방(MacroKit) 템플릿의 주문 번호를 게임 데이터(SpellName.db2, 한국어)와 대조한다.

  python -I tools/casc/check_spells.py            # 결과를 docs/MacroKit-spells.txt 에 쓰고 요약 출력

- 템플릿 파일(addons/MacroKit/Templates/*.lua)에서 S(번호) 를 모두 찾는다.
- 이 PC 에 깔린 게임 데이터에서 각 번호의 한글 이름을 찾아 옆에 적는다.
- 게임 데이터에 없는 번호(암호화된 미공개 구역이거나 잘못된 번호)는 '없음' 으로 표시하고 종료 코드 1.
  게임 파일이 필요하므로 GitHub Actions 가 아니라 로컬에서만 실행한다.
  게임 안에서도 /매공 검사 로 실제 클라이언트가 이름을 주는지 다시 확인한다.
"""
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import casc  # noqa: E402

SPELLNAME_FDID = 1990283   # DBFilesClient/SpellName.db2
KOKR = 0x4                 # 로캘 플래그: 한국어


def read_wdc5_strings(data):
    """문자열 필드 하나짜리 WDC5 표(SpellName 등)를 {ID: 문자열} 로 읽는다. 암호화된 구역은 건너뛴다."""
    assert data[:4] == b"WDC5", data[:4]
    p = 8 + 128
    rc, fc, rs, _sts, _th, _lh, _minid, _maxid, _loc = struct.unpack_from("<9I", data, p)
    p += 36 + 4
    _tfc, _bpo, _lcc, _fsis, _cds, _pds, sc = struct.unpack_from("<7I", data, p)
    p += 28
    sections = [struct.unpack_from("<QIIIIIIII", data, p + 40 * i) for i in range(sc)]
    assert fc == 1 and rs == 4, "문자열 하나짜리 표만 지원"

    names = {}
    record_base = 0      # 모든 구역의 레코드를 이어 붙였을 때의 위치 (문자열 위치 계산용)
    string_base = 0      # 모든 구역의 문자열 표를 이어 붙였을 때의 위치
    total_records = rc * rs
    for key, off, n, sts, _end, idl, _rel, _omc, cpc in sections:
        strs = off + n * rs
        ids = strs + sts
        if key == 0:     # 암호화 안 된 구역만
            idlist = struct.unpack_from("<%dI" % n, data, ids)
            for i in range(n):
                v = struct.unpack_from("<I", data, off + i * rs)[0]
                # 문자열 위치 = (이어 붙인 레코드 기준 위치 + 값) - 전체 레코드 크기 → 이어 붙인 문자열 표 안의 위치
                rel = record_base + i * rs + v - total_records - string_base
                a = strs + rel
                e = data.index(b"\0", a)
                names[idlist[i]] = data[a:e].decode("utf-8", "replace")
            cpos = ids + idl
            for j in range(cpc):
                new, old = struct.unpack_from("<II", data, cpos + 8 * j)
                if old in names:
                    names[new] = names[old]
        record_base += n * rs
        string_base += sts
    return names


def load_spell_names():
    c = casc.Casc()
    for loc, _content, ckey in c.root[SPELLNAME_FDID]:
        if loc & KOKR:
            return read_wdc5_strings(c.read_ekey(c.encoding[ckey], allow_encrypted=True))
    raise SystemExit("한국어 SpellName.db2 를 찾지 못했습니다")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    tdir = os.path.join(ROOT, "addons", "MacroKit", "Templates")
    names = load_spell_names()
    lines, missing, total = [], 0, 0
    for fn in sorted(os.listdir(tdir)):
        if not fn.endswith(".lua"):
            continue
        ids = []
        for m in re.finditer(r"\bS\((\d+)\)", open(os.path.join(tdir, fn), encoding="utf-8").read()):
            i = int(m.group(1))
            if i not in ids:
                ids.append(i)
        lines.append("== %s (%d)" % (fn, len(ids)))
        for i in ids:
            n = names.get(i)
            total += 1
            if not n:
                missing += 1
            lines.append("  %-8d %s" % (i, n or "없음 (게임 데이터에 없음 → 번호 확인)"))
    out = os.path.join(ROOT, "docs", "MacroKit-spells.txt")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("# check_spells.py 가 만든 파일. 템플릿 주문 번호 → 게임 데이터의 한글 이름\n")
        f.write("\n".join(lines) + "\n")
    print("\n".join(l for l in lines if l.startswith("==") or "없음" in l))
    print("주문 %d개 중 없음 %d개 → %s" % (total, missing, out))
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
