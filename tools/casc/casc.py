"""Minimal read-only local CASC reader (build config -> encoding -> root -> idx -> data.XXX -> BLTE)."""
import os, struct, zlib, glob, pickle

WOW = r"C:\Program Files (x86)\World of Warcraft"
DATA = os.path.join(WOW, "Data")
BUILD_KEY = "5ada954223f7c409ea172361f5c9e565"  # wowf 1.60.1.70862
CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cache")


def cfg_path(h):
    return os.path.join(DATA, "config", h[0:2], h[2:4], h)


def read_build_config():
    cfg = {}
    for line in open(cfg_path(BUILD_KEY), encoding="utf-8"):
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            cfg[k.strip()] = v.split()
    return cfg


def load_indices():
    idx = {}
    for bucket in range(16):
        files = sorted(glob.glob(os.path.join(DATA, "data", "%02x*.idx" % bucket)))
        if not files:
            continue
        with open(files[-1], "rb") as f:
            buf = f.read()
        hdr_size = struct.unpack_from("<I", buf, 0)[0]
        pos = 8 + hdr_size
        pos = (pos + 15) & ~15
        entries_size = struct.unpack_from("<I", buf, pos)[0]
        pos += 8
        for i in range(entries_size // 18):
            e = buf[pos + i * 18: pos + i * 18 + 18]
            key = e[:9]
            hi = e[9]
            lo = struct.unpack(">I", e[10:14])[0]
            archive = (hi << 2) | (lo >> 30)
            offset = lo & 0x3FFFFFFF
            size = struct.unpack("<I", e[14:18])[0]
            idx.setdefault(key, (archive, offset, size))
    return idx


def blte_decode(b, allow_encrypted=False):
    """allow_encrypted: 암호화된 조각(아직 공개 안 된 데이터)은 0 으로 채운다 (DB2 처럼 일부만 암호화된 파일용)"""
    assert b[:4] == b"BLTE", b[:4]
    hsize = struct.unpack(">I", b[4:8])[0]
    out = bytearray()
    if hsize == 0:
        chunks = [(len(b) - 8, None)]
        pos = 8
    else:
        count = int.from_bytes(b[9:12], "big")
        chunks = []
        p = 12
        for _ in range(count):
            cs, ds = struct.unpack(">II", b[p:p + 8])
            chunks.append((cs, ds))
            p += 24
        pos = hsize
    for cs, ds in chunks:
        c = b[pos:pos + cs]
        pos += cs
        mode = c[:1]
        if mode == b"N":
            out += c[1:]
        elif mode == b"Z":
            out += zlib.decompress(c[1:])
        elif mode == b"F":
            out += blte_decode(c[1:], allow_encrypted)
        elif mode == b"E":
            if not allow_encrypted or ds is None:
                raise ValueError("encrypted chunk")
            out += bytes(ds)
        else:
            raise ValueError("unsupported BLTE mode %r" % mode)
    return bytes(out)


class Casc:
    def __init__(self):
        self.cfg = read_build_config()
        self.idx = load_indices()
        self._enc = None
        self._root = None

    def read_ekey(self, ekey_hex_or_bytes, allow_encrypted=False):
        ek = bytes.fromhex(ekey_hex_or_bytes) if isinstance(ekey_hex_or_bytes, str) else ekey_hex_or_bytes
        ent = self.idx.get(ek[:9])
        if not ent:
            raise KeyError("ekey not local: " + ek.hex())
        archive, offset, size = ent
        with open(os.path.join(DATA, "data", "data.%03d" % archive), "rb") as f:
            f.seek(offset)
            raw = f.read(size)
        return blte_decode(raw[30:], allow_encrypted)

    @property
    def encoding(self):
        if self._enc is None:
            os.makedirs(CACHE, exist_ok=True)
            cp = os.path.join(CACHE, "enc.pkl")
            if os.path.exists(cp):
                self._enc = pickle.load(open(cp, "rb"))
            else:
                b = self.read_ekey(self.cfg["encoding"][1])
                assert b[:2] == b"EN"
                ck, ek = b[3], b[4]
                ce_page_kb = struct.unpack(">H", b[5:7])[0]
                ce_pages = struct.unpack(">I", b[9:13])[0]
                espec = struct.unpack(">I", b[18:22])[0]
                pos = 22 + espec + ce_pages * (ck + 16)
                m = {}
                for p in range(ce_pages):
                    page = b[pos: pos + ce_page_kb * 1024]
                    pos += ce_page_kb * 1024
                    q = 0
                    while q + 6 + ck <= len(page):
                        n = page[q]
                        if n == 0:
                            break
                        ckey = page[q + 6: q + 6 + ck]
                        m[ckey] = page[q + 6 + ck: q + 6 + ck + ek]
                        q += 6 + ck + n * ek
                self._enc = m
                pickle.dump(m, open(cp, "wb"))
        return self._enc

    def read_ckey(self, ckey):
        ck = bytes.fromhex(ckey) if isinstance(ckey, str) else ckey
        return self.read_ekey(self.encoding[ck])

    @property
    def root(self):
        """fdid -> list of (localeFlags, contentFlags, ckey)"""
        if self._root is None:
            b = self.read_ckey(self.cfg["root"][0])
            pos = 0
            magic = b[:4]
            version = 1
            mfst = magic == b"TSFM"
            if mfst:
                f4, f8 = struct.unpack_from("<II", b, 4)
                if f8 in (1, 2):
                    version = f8
                    pos = f4
                else:
                    pos = 12
            r = {}
            while pos < len(b):
                count = struct.unpack_from("<I", b, pos)[0]
                if version == 2:
                    loc, u1, u2 = struct.unpack_from("<III", b, pos + 4)
                    u3 = b[pos + 16]
                    content = u1 | u2 | (u3 << 17)
                    pos += 17
                else:
                    content, loc = struct.unpack_from("<II", b, pos + 4)
                    pos += 12
                deltas = struct.unpack_from("<%di" % count, b, pos)
                pos += 4 * count
                fdids = []
                cur = -1
                for d in deltas:
                    cur = cur + 1 + d
                    fdids.append(cur)
                if mfst:
                    ckeys = [b[pos + i * 16: pos + i * 16 + 16] for i in range(count)]
                    pos += 16 * count
                    if not (content & 0x10000000):
                        pos += 8 * count
                else:
                    ckeys = [b[pos + i * 24: pos + i * 24 + 16] for i in range(count)]
                    pos += 24 * count
                for fd, ckk in zip(fdids, ckeys):
                    r.setdefault(fd, []).append((loc, content, ckk))
            self._root = r
        return self._root

    def read_fdid(self, fdid):
        return self.read_ckey(self.root[fdid][0][2])
