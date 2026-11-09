"""DungeonNav 지도 데이터(Data.lua) 생성기.

게임 데이터의 던전 지도 타일(4x3) FileDataID 를 listfile 에서 찾아 Lua 테이블로 만든다.
  python -I gen_dungeon_maps.py <listfile.csv> <출력 Data.lua> [--preview <폴더>]

--preview 를 주면 각 던전 1층을 PNG 로 꺼내서 눈으로 확인할 수 있다.
"""
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import casc  # noqa: E402

# instanceMapID 는 게임의 GetInstanceInfo() 8번째 값 (오리지날 던전/공격대)
# floors: (파일 접두어, 층 이름). 이름이 None 이면 "N층"
DUNGEONS = [
    # id,  이름,                 종류,     폴더,                    층들
    (389, "성난불길 협곡",        "dungeon", "ragefire",              ["ragefire1"]),
    (43,  "통곡의 동굴",          "dungeon", "wailingcaverns",        ["wailingcaverns1"]),
    (36,  "죽음의 폐광",          "dungeon", "thedeadmines",          ["thedeadmines1", "thedeadmines2"]),
    (33,  "그림자송곳니 성채",    "dungeon", "shadowfangkeep",        [f"shadowfangkeep{i}" for i in range(1, 8)]),
    (48,  "검은심연의 나락",      "dungeon", "blackfathomdeeps",      [f"blackfathomdeeps{i}" for i in range(1, 4)]),
    (34,  "스톰윈드 지하감옥",    "dungeon", "thestockade",           ["thestockade1"]),
    (90,  "놈리건",               "dungeon", "gnomeregan",            [f"gnomeregan{i}" for i in range(1, 5)]),
    (47,  "가시덩굴 우리",        "dungeon", "razorfenkraul",         ["razorfenkraul1"]),
    (189, "붉은십자군 수도원",    "dungeon", "scarletmonasteryold",   [("scarletmonastery1", "묘지"), ("scarletmonastery2", "도서관"),
                                                                         ("scarletmonastery3", "무기고"), ("scarletmonastery4", "대성당")]),
    (129, "가시덩굴 구릉",        "dungeon", "razorfendowns",         ["razorfendowns1"]),
    (70,  "울다만",               "dungeon", "uldaman",               ["uldaman1", "uldaman2"]),
    (209, "줄파락",               "dungeon", "zulfarrak",             ["zulfarrak"]),
    (349, "마라우돈",             "dungeon", "maraudon",              ["maraudon1", "maraudon2"]),
    (109, "아탈학카르 신전",      "dungeon", "thetempleofatalhakkar", ["thetempleofatalhakkar1"]),
    (230, "검은바위 나락",        "dungeon", "blackrockdepths",       ["blackrockdepths1", "blackrockdepths2"]),
    (229, "검은바위 첨탑",        "dungeon", "blackrockspire",        [f"blackrockspire{i}" for i in range(1, 8)]),
    (429, "혈투의 전장",          "dungeon", "diremaul",              [f"diremaul{i}" for i in range(1, 7)]),
    (289, "스칼로맨스",           "dungeon", "scholomanceold",        [f"scholomanceold{i}" for i in range(1, 5)]),
    (329, "스트라솔름",           "dungeon", "stratholme",            ["stratholme1", "stratholme2"]),
    (409, "화산 심장부",          "raid",    "moltencore",            ["moltencore1"]),
    (249, "오닉시아의 둥지",      "raid",    "onyxiaslair",           ["onyxiaslair1"]),
    (469, "검은날개 둥지",        "raid",    "blackwinglair",         [f"blackwinglair{i}" for i in range(1, 5)]),
    (309, "줄구룹",               "raid",    "zulgurub",              ["zulgurub"]),
    (509, "안퀴라즈 폐허",        "raid",    "ruinsofahnqiraj",       ["ruinsofahnqiraj"]),
    (531, "안퀴라즈 사원",        "raid",    "ahnqiraj",              [f"ahnqiraj{i}" for i in range(1, 4)]),
    (533, "낙스라마스",           "raid",    "naxxramas",             [f"naxxramas{i}" for i in range(1, 7)]),
]


def load_listfile(path):
    names = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            fd, _, name = line.rstrip("\n").partition(";")
            if name.startswith("interface/worldmap/"):
                names[name] = int(fd)
    return names


def tiles_for(names, folder, prefix):
    """접두어의 12개 타일 FileDataID. 'name_1.blp' 와 'name1.blp' 두 형식을 모두 찾는다."""
    out = []
    for i in range(1, 13):
        fd = names.get(f"interface/worldmap/{folder}/{prefix}_{i}.blp") or \
             names.get(f"interface/worldmap/{folder}/{prefix}{i}.blp")
        if fd is None:
            raise KeyError(f"{folder}/{prefix} 타일 {i} 없음")
        out.append(fd)
    return out


def main(listfile, out_path, preview_dir=None):
    names = load_listfile(listfile)
    root = casc.Casc().root
    lines = [
        "-- 자동 생성 파일: tools/casc/gen_dungeon_maps.py 로 다시 만든다. 손으로 고치지 말 것.",
        "-- [instanceMapID] = { name, kind, floors = { { name, tiles = {12개 FileDataID, 4x3 왼쪽 위부터} } } }",
        "local _, ns = ...",
        "ns.Dungeons = {",
    ]
    for iid, name, kind, folder, floors in DUNGEONS:
        lines.append(f'  [{iid}] = {{ name = "{name}", kind = "{kind}", floors = {{')
        for idx, fl in enumerate(floors, 1):
            prefix, fname = (fl if isinstance(fl, tuple) else (fl, None))
            tiles = tiles_for(names, folder, prefix)
            missing = [t for t in tiles if t not in root]
            if missing:
                raise RuntimeError(f"{folder}/{prefix}: 이 클라이언트 데이터에 없는 타일 {missing}")
            label = fname or (f"{idx}층" if len(floors) > 1 else "")
            lines.append(f'    {{ name = "{label}", tiles = {{ {", ".join(map(str, tiles))} }} }},')
        lines.append("  } },")
    lines.append("}")
    lines.append("-- 목록 표시 순서 (레벨 순)")
    lines.append("ns.DungeonOrder = { " + ", ".join(str(d[0]) for d in DUNGEONS) + " }")
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{out_path}: 던전 {len(DUNGEONS)}곳")

    if preview_dir:
        from PIL import Image
        c = casc.Casc()
        os.makedirs(preview_dir, exist_ok=True)
        for iid, name, kind, folder, floors in DUNGEONS:
            fl = floors[0]
            prefix = fl[0] if isinstance(fl, tuple) else fl
            img = Image.new("RGBA", (1024, 768))
            for i, fd in enumerate(tiles_for(names, folder, prefix)):
                try:
                    t = Image.open(io.BytesIO(c.read_fdid(fd))).convert("RGBA")
                    img.paste(t, ((i % 4) * 256, (i // 4) * 256))
                except Exception:
                    pass  # 로컬에 아직 안 받아진 타일
            img.crop((0, 0, 1002, 668)).resize((501, 334)).save(os.path.join(preview_dir, f"{iid}_{folder}.png"))


if __name__ == "__main__":
    args = sys.argv[1:]
    prev = None
    if "--preview" in args:
        i = args.index("--preview")
        prev = args[i + 1]
        del args[i:i + 2]
    if len(args) != 2:
        sys.exit(__doc__)
    main(*args, preview_dir=prev)
