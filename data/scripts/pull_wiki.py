#!/usr/bin/env python3
"""DRAFT data pull: hero mechanics for the hero-trait table.

Sources (all free):
  * Dota 2 Wiki (dota2.fandom.com) MediaWiki API, CC-BY-SA: mechanic pages that
    list every ability applying that effect (Stun, Silence, Root, ...).
    Current patch only. One request per page, 3 s apart.
  * odota/dotaconstants (MIT) on GitHub: heroes.json (attack range, move
    speed, base stats) and hero_abilities.json (which abilities each hero has),
    patch.json (patch names and release dates).

Output: data/raw/wiki/<Page>.wikitext.json, data/raw/wiki/mechanic_sources.csv,
        data/raw/dotaconstants/{heroes,hero_abilities}.json

Usage: python3 -I pull_wiki.py [--out DIR]
"""
import argparse, csv, json, os, re, time
import requests

WIKI = "https://dota2.fandom.com/api.php"
UA = {"User-Agent": "CSE311-dota-roguelike-datapull/0.1 (NSU student course project)"}
PAGES = ["Stun", "Silence", "Root", "Hex", "Disarm", "Fear", "Taunt", "Sleep",
         "Cyclone", "Leash", "Break", "Banish", "Invisibility", "Slow", "Mute"]
CONSTANTS = "https://raw.githubusercontent.com/odota/dotaconstants/master/build/"

SKILL = re.compile(r"\{\{SkillListLite(.*?)\}\}", re.S)
FIELD = re.compile(r"\|\s*(source|name)\s*=\s*([^\n|]+)")
ATPL = re.compile(r"\{\{A\|([^|}]+)\|([^|}]+)")


def parse(wikitext):
    out = set()
    for block in SKILL.findall(wikitext):
        f = dict((k, v.strip()) for k, v in FIELD.findall(block))
        if "source" in f and "name" in f:
            out.add((f["source"], f["name"]))
    for ability, source in ATPL.findall(wikitext):
        out.add((source.strip(), ability.strip()))
    return sorted(out)


def main():
    ap = argparse.ArgumentParser()
    base = os.path.join(os.path.dirname(__file__), "..", "raw")
    ap.add_argument("--out", default=base)
    a = ap.parse_args()
    wdir = os.path.join(os.path.abspath(a.out), "wiki")
    cdir = os.path.join(os.path.abspath(a.out), "dotaconstants")
    os.makedirs(wdir, exist_ok=True); os.makedirs(cdir, exist_ok=True)

    for fn in ("heroes.json", "hero_abilities.json", "patch.json"):
        p = os.path.join(cdir, fn)
        if not os.path.exists(p):
            r = requests.get(CONSTANTS + fn, headers=UA, timeout=60); r.raise_for_status()
            open(p, "w").write(r.text)
            time.sleep(1)

    rows = []
    for page in PAGES:
        p = os.path.join(wdir, f"{page}.wikitext.json")
        if not os.path.exists(p):
            time.sleep(3)
            r = requests.get(WIKI, params={"action": "parse", "page": page, "prop": "wikitext|revid",
                             "format": "json", "formatversion": 2}, headers=UA, timeout=60)
            d = r.json()
            if "parse" not in d:
                print(page, "missing:", d.get("error", {}).get("info")); continue
            json.dump(d["parse"], open(p, "w"))
        d = json.load(open(p))
        found = parse(d["wikitext"])
        print(f"{page}: {len(found)} source/ability pairs (revid {d.get('revid')})")
        rows += [(page, s, n, d.get("revid")) for s, n in found]

    with open(os.path.join(wdir, "mechanic_sources.csv"), "w", newline="") as f:
        w = csv.writer(f); w.writerow(["mechanic", "source", "ability", "wiki_revid"]); w.writerows(rows)
    print("mechanic_sources.csv rows:", len(rows))


if __name__ == "__main__":
    main()
