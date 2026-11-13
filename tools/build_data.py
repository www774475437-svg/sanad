#!/usr/bin/env python3
"""Builds light search data for the Sanad site from turath book files.

For every book:
  n<id>.txt        one normalized line per page (for fast searching)
  p<id>_<k>.json   chunks of CHUNK pages: [[vol, page, raw_html], ...]
"""
import json
import os
import re
import sys
import urllib.request

BOOKS = [12293, 9260, 7339, 11166, 11224, 31341]
CHUNK = 20
OUT = sys.argv[1] if len(sys.argv) > 1 else "web/data"

TAG = re.compile(r"<[^>]*>")
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


def fetch(book_id: int):
    url = f"https://files.turath.io/books-v3/{book_id}.json"
    req = urllib.request.Request(url, headers={"Accept-Encoding": "gzip", "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36", "Accept": "application/json,*/*"})
    with urllib.request.urlopen(req, timeout=300) as r:
        data = r.read()
        if r.headers.get("Content-Encoding") == "gzip":
            import gzip
            data = gzip.decompress(data)
    return json.loads(data.decode("utf-8"))


def main():
    os.makedirs(OUT, exist_ok=True)
    total_pages = 0
    for bid in BOOKS:
        d = fetch(bid)
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
                lines.append(norm(raw))
            with open(os.path.join(OUT, f"p{bid}_{i // CHUNK}.json"), "w", encoding="utf-8") as f:
                json.dump(chunk, f, ensure_ascii=False, separators=(",", ":"))
        with open(os.path.join(OUT, f"n{bid}.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        total_pages += len(pages)
        print(f"book {bid}: {len(pages)} pages")
    print("total pages", total_pages)
    size = sum(os.path.getsize(os.path.join(OUT, n)) for n in os.listdir(OUT))
    print("data size MB", round(size / 1e6, 1), "files", len(os.listdir(OUT)))


if __name__ == "__main__":
    main()
