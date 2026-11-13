import json, sys, urllib.request, urllib.parse, gzip
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36", "Accept": "application/json,*/*", "Accept-Encoding": "gzip"}
def get(u, raw=False):
    try:
        with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=120) as r:
            d = r.read()
            if r.headers.get("Content-Encoding") == "gzip": d = gzip.decompress(d)
            print("OK", u, len(d), dict(r.headers).get("Content-Length"))
            return d if raw else json.loads(d.decode("utf-8"))
    except Exception as e:
        print("ERR", u, e); return None
b = get("https://api.turath.io/book?id=12293&include=indexes&ver=3")
aid = None
if isinstance(b, dict):
    print("book keys", list(b.keys()))
    m = b.get("meta") or {}
    print("meta", json.dumps({k: (v if not isinstance(v, (dict, list)) else str(v)[:200]) for k, v in m.items()}, ensure_ascii=False)[:1500])
    aid = m.get("author_id")
    idx = b.get("indexes") or {}
    print("indexes keys", list(idx.keys()) if isinstance(idx, dict) else type(idx))
    if isinstance(idx, dict):
        for k, v in idx.items():
            print(" idx", k, str(v)[:300])
print("author id", aid)
if aid:
    a = get(f"https://api.turath.io/author?id={aid}&ver=3")
    if a is not None:
        s = json.dumps(a, ensure_ascii=False)
        print("author json len", len(s)); print(s[:3000])
for u in ["https://files.turath.io/data-v3.json", "https://files.turath.io/data.json", "https://app.turath.io/data-v3.json"]:
    d = get(u)
    if isinstance(d, dict):
        print("catalog keys", list(d.keys()))
        books = d.get("books")
        if isinstance(books, dict): books = list(books.values())
        if isinstance(books, list):
            print("n books", len(books), "sample", json.dumps(books[0], ensure_ascii=False)[:400])
            mine = [x for x in books if isinstance(x, dict) and (x.get("author_id") == aid or "عثيمين" in json.dumps(x, ensure_ascii=False))]
            print("MINE", len(mine))
            for x in mine:
                print("BOOK", json.dumps(x, ensure_ascii=False)[:300])
        break
# search with author filter
q = urllib.parse.quote("النمص")
for extra in [f"&author={aid}", f"&book=12293,9260", ""]:
    r = get(f"https://api.turath.io/search?q={q}&ver=3{extra}")
    if isinstance(r, dict):
        print("search", extra, "keys", list(r.keys()), "count", r.get("count"))
        for it in (r.get("data") or [])[:6]:
            print("  ", json.dumps(it, ensure_ascii=False)[:260])
