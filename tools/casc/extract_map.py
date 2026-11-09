"""게임 데이터(CASC)에서 던전 지도 타일(4x3, 256px)을 꺼내 PNG 한 장으로 이어 붙인다.

사용법:
  python -I extract_map.py <listfile.csv> <worldmap 폴더> <파일 접두어> <출력.png>
  예) python -I extract_map.py community-listfile.csv thedeadmines thedeadmines1 deadmines_f1.png

listfile: https://github.com/wowdev/wow-listfile/releases (community-listfile.csv)
로컬에 내려받아지지 않은 타일은 검게 남는다(게임이 필요할 때 스트리밍).
"""
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import casc  # noqa: E402
from PIL import Image  # noqa: E402

TILE, COLS, ROWS = 256, 4, 3
VISIBLE_W, VISIBLE_H = 1002, 668  # 월드맵 텍스처 중 실제로 보이는 영역


def load_listfile(path, prefix):
    names = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            fd, _, name = line.rstrip("\n").partition(";")
            if name.startswith(prefix):
                names[name] = int(fd)
    return names


def main(listfile, folder, base, out):
    prefix = f"interface/worldmap/{folder}/"
    names = load_listfile(listfile, prefix)
    c = casc.Casc()
    img = Image.new("RGBA", (TILE * COLS, TILE * ROWS))
    missing = []
    for i in range(COLS * ROWS):
        name = f"{prefix}{base}_{i + 1}.blp"
        fdid = names.get(name)
        try:
            tile = Image.open(io.BytesIO(c.read_fdid(fdid))).convert("RGBA")
        except Exception as e:  # 타일 하나가 없어도 나머지는 붙인다
            missing.append(f"{name} ({e})")
            continue
        img.paste(tile, ((i % COLS) * TILE, (i // COLS) * TILE))
    img.crop((0, 0, VISIBLE_W, VISIBLE_H)).save(out)
    print(f"saved {out}, missing {len(missing)}")
    for m in missing:
        print("  -", m)


if __name__ == "__main__":
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    main(*sys.argv[1:])
