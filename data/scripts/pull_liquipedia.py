#!/usr/bin/env python3
"""DRAFT data pull for Sadman to run on his own machine: Liquipedia tier-1
tournaments and placements -> data/raw/liquipedia/

NOT RUN BY CLAUDE. Liquipedia's robots.txt disallows Anthropic's agents
(ClaudeBot, Claude-Web), so this script was written but never executed from the
cloud session. It follows Liquipedia's API terms of use
(https://liquipedia.net/api-terms-of-use):
  * a descriptive User-Agent with contact info (pass --contact you@example.com)
  * gzip encoding (requests does this by default)
  * at most 1 request per 2 s for action=query (this script waits 3 s)
  * never action=parse in a loop (this script uses only action=query)
  * content is CC-BY-SA 3.0: credit Liquipedia in the app and the report.

What it does (about 15-25 requests total):
  1. Lists Category:Tier_1_Tournaments (namespace 0, 500 per request).
  2. Drops DotA 1 events (before 2011) and qualifier subpages by title.
  3. Fetches wikitext for the rest, 50 titles per request (prop=revisions).
  4. Parses the infobox (dates, tier, type, prize pool) and the prize-pool
     slots (place -> team) into CSV. Old and new prize-pool templates are both
     handled; anything it can't parse is listed in unparsed.txt for hand entry.

Usage: python3 -I pull_liquipedia.py --contact you@example.com
"""
import argparse, csv, json, os, re, sys, time
import requests

API = "https://liquipedia.net/dota2/api.php"
QUAL = re.compile(r"qualifier|/open|/closed|/regional|division|/play-?in|/last chance", re.I)
YEAR = re.compile(r"(19|20)\d\d")


def session(contact):
    s = requests.Session()
    s.headers.update({"User-Agent": f"CSE311-dota-roguelike/0.1 (NSU course project; {contact})",
                      "Accept-Encoding": "gzip"})
    return s


def call(s, params):
    params = {**params, "format": "json", "formatversion": 2}
    for i in range(5):
        time.sleep(3)
        r = s.get(API, params=params, timeout=60)
        if r.status_code == 429:
            print("429, backing off", file=sys.stderr); time.sleep(60 * (i + 1)); continue
        r.raise_for_status()
        return r.json()
    raise RuntimeError("gave up after repeated 429s")


def infobox(text):
    m = re.search(r"\{\{\s*Infobox league(.*?)\n\}\}", text, re.S | re.I)
    box = m.group(1) if m else ""
    get = lambda k: (re.search(r"\|\s*" + k + r"\s*=\s*([^\n|]*)", box) or [None, ""])[1].strip()
    return {"name": get("name"), "series": get("series"), "organizer": get("organizer"),
            "type": get("type"), "tier": get("liquipediatier"), "sdate": get("sdate"),
            "edate": get("edate") or get("date"), "prizepool_usd": get("prizepoolusd") or get("prizepool"),
            "team_number": get("team_number")}


# New format:  {{Slot|place=1|usdprize=...|{{Opponent|Team Spirit|...}}}}
# Old format:  {{prize pool slot|place=1|usdprize=...|Team Liquid|...}} or |team=...
SLOT = re.compile(r"\{\{\s*(?:Slot|prize pool slot)\s*\|(.*?)\n?\}\}\s*(?=\{\{\s*(?:Slot|prize pool slot)|\{\{\s*Prize pool end|\{\{\s*PrizePoolEnd|$)", re.S | re.I)
OPP = re.compile(r"\{\{\s*(?:Opponent|TeamOpponent)\s*\|\s*([^|}]+)", re.I)


def placements(text):
    out = []
    for body in SLOT.findall(text):
        place = (re.search(r"place\s*=\s*([0-9\-]+)", body) or [None, ""])[1]
        teams = [t.strip() for t in OPP.findall(body)]
        if not teams:
            teams = [t.strip() for t in re.findall(r"\|\s*(?:team\d*\s*=\s*)?([A-Z][^|=\n}]{1,40})(?=\||\n|$)", body)
                     if not re.match(r"(usdprize|localprize|points|place|seed)", t, re.I)]
        for t in teams:
            out.append((place, t))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--contact", required=True, help="your email, sent in the User-Agent as Liquipedia requires")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "raw", "liquipedia"))
    a = ap.parse_args()
    out = os.path.abspath(a.out); os.makedirs(out, exist_ok=True)
    s = session(a.contact)

    titles, cont = [], {}
    while True:
        d = call(s, {"action": "query", "list": "categorymembers", "cmtitle": "Category:Tier 1 Tournaments",
                     "cmnamespace": 0, "cmlimit": 500, **cont})
        titles += [m["title"] for m in d["query"]["categorymembers"]]
        if "continue" not in d: break
        cont = {"cmcontinue": d["continue"]["cmcontinue"]}
    keep = []
    for t in titles:
        y = YEAR.search(t)
        if QUAL.search(t): continue
        if y and int(y.group(0)) < 2011: continue
        keep.append(t)
    json.dump({"all": titles, "kept": keep}, open(os.path.join(out, "tier1_titles.json"), "w"), indent=1)
    print(f"category: {len(titles)} pages, kept {len(keep)}")

    trows, prows, unparsed = [], [], []
    for i in range(0, len(keep), 50):
        d = call(s, {"action": "query", "prop": "revisions", "rvprop": "content|ids", "rvslots": "main",
                     "titles": "|".join(keep[i:i + 50])})
        for pg in d["query"]["pages"]:
            if "revisions" not in pg: continue
            rev = pg["revisions"][0]
            text = rev["slots"]["main"]["content"]
            open(os.path.join(out, re.sub(r"[^A-Za-z0-9]+", "_", pg["title"]) + ".wiki"), "w").write(text)
            ib = infobox(text)
            trows.append({"page": pg["title"], "revid": rev["revid"], **ib})
            pl = placements(text)
            if not pl: unparsed.append(pg["title"])
            prows += [{"page": pg["title"], "place": p, "team": t} for p, t in pl]
        print(f"fetched {min(i + 50, len(keep))}/{len(keep)}")

    with open(os.path.join(out, "tournaments.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(trows[0].keys())); w.writeheader(); w.writerows(trows)
    with open(os.path.join(out, "placements.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["page", "place", "team"]); w.writeheader(); w.writerows(prows)
    open(os.path.join(out, "unparsed.txt"), "w").write("\n".join(unparsed))
    print(f"tournaments {len(trows)}, placement rows {len(prows)}, unparsed {len(unparsed)}")


if __name__ == "__main__":
    main()
