#!/usr/bin/env python3
"""Builds the Sanad site data from turath book files.

For every book in tools/books.json:
  p<id>_<k>.json   chunks of CHUNK pages: [[vol, page, raw_html], ...]
  t<id>.json       table of contents: [[level, page_id, title], ...]
For the core (full-text) books also:
  n<id>.txt        one normalized line per page (for fast searching)
And once:
  h.txt            all headings of all books: id<TAB>page_id<TAB>title
"""
import gzip
import json
import os
import re
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
BOOKS = [b["id"] for b in json.load(open(os.path.join(HERE, "books.json"), encoding="utf-8"))]
CORE = {12293, 9924, 11377, 96334, 14242, 21576, 9260, 7339, 11166, 11224, 31341, 7470, 21528}
CHUNK = 20
OUT = sys.argv[1] if len(sys.argv) > 1 else "web/data"
MARK = "done-v3"

UA = {
    "Accept-Encoding": "gzip",
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36",
    "Accept": "application/json,*/*",
}

TAG = re.compile(r"<[^>]*>")
WS = re.compile(r"\s+")
TABLE = {}
for c in list(range(0x064B, 0x0660)) + [0x0670, 0x0640]:
    TABLE[c] = None
for c in (0x0623, 0x0625, 0x0622, 0x0671):
    TABLE[c] = 0x0627
TABLE[0x0649] = 0x064A
TABLE[0x0629] = 0x0647
for c in (10, 13, 9, 0xA0):
    TABLE[c] = 32


def norm(raw: str) -> str:
    return TAG.sub("", raw).translate(TABLE)


def get(url: str):
    last = None
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=300) as r:
                data = r.read()
                if r.headers.get("Content-Encoding") == "gzip":
                    data = gzip.decompress(data)
            return json.loads(data.decode("utf-8"))
        except Exception as e:  # noqa
            last = e
            time.sleep(3 + attempt * 5)
    raise last


def headings_of(d, bid):
    idx = d.get("indexes") if isinstance(d, dict) else None
    hs = idx.get("headings") if isinstance(idx, dict) else None
    if not isinstance(hs, list):
        try:
            b = get(f"https://api.turath.io/book?id={bid}&include=indexes&ver=3")
            hs = (b.get("indexes") or {}).get("headings") or []
            time.sleep(0.3)
        except Exception as e:  # noqa
            print("no headings for", bid, e)
            hs = []
    out = []
    for h in hs:
        if not isinstance(h, dict):
            continue
        title = WS.sub(" ", str(h.get("title") or "")).strip()
        page = h.get("page")
        if not title or not isinstance(page, int):
            continue
        out.append([int(h.get("level") or 1), page, title])
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    if os.path.exists(os.path.join(OUT, MARK)):
        print("data already built (cache)")
        return
    total_pages = 0
    hlines = []
    first = True
    for bid in BOOKS:
        d = get(f"https://files.turath.io/books-v3/{bid}.json")
        if first:
            print("book json keys:", list(d.keys()))
            first = False
        pages = d["pages"]
        lines = []
        for i in range(0, len(pages), CHUNK):
            chunk = []
            for p in pages[i:i + CHUNK]:
                raw = p.get("text") or ""
                vol = p.get("vol")
                page = p.get("page")
                chunk.append([
                    "" if vol is None else str(vol),
                    "" if page is None else str(page),
                    raw,
                ])
                if bid in CORE:
                    lines.append(norm(raw))
            with open(os.path.join(OUT, f"p{bid}_{i // CHUNK}.json"), "w", encoding="utf-8") as f:
                json.dump(chunk, f, ensure_ascii=False, separators=(",", ":"))
        if bid in CORE:
            with open(os.path.join(OUT, f"n{bid}.txt"), "w", encoding="utf-8") as f:
                f.write("\n".join(lines) + "\n")
        toc = headings_of(d, bid)
        with open(os.path.join(OUT, f"t{bid}.json"), "w", encoding="utf-8") as f:
            json.dump(toc, f, ensure_ascii=False, separators=(",", ":"))
        for _, page, title in toc:
            hlines.append(f"{bid}\t{page}\t{title}")
        total_pages += len(pages)
        print(f"book {bid}: {len(pages)} pages, {len(toc)} headings")
    with open(os.path.join(OUT, "h.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(hlines) + "\n")
    print("total pages", total_pages, "headings", len(hlines))
    size = sum(os.path.getsize(os.path.join(OUT, n)) for n in os.listdir(OUT))
    print("data size MB", round(size / 1e6, 1), "files", len(os.listdir(OUT)))
    open(os.path.join(OUT, MARK), "w").write("1")


if __name__ == "__main__":
    main()
