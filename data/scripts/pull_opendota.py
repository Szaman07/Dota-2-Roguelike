#!/usr/bin/env python3
"""DRAFT data pull: OpenDota (free tier, no key) -> data/raw/opendota/*.csv.gz

Pulls the raw tables the game needs, once, at build time. The game itself never
calls OpenDota. Re-running skips slices that already exist (resumable).

Politeness: free tier is 60 calls/min and 3000 calls/day. This script sleeps
1.3 s between calls (about 46/min) and stops if the daily counter drops below
a safety margin. A full run is roughly 400 calls.

Usage:  python3 -I pull_opendota.py [--out DIR] [--from 2012-01-01] [--to 2026-10-12]
"""
import argparse, csv, datetime as dt, gzip, json, os, sys, time
import requests

API = "https://api.opendota.com/api"
UA = {"User-Agent": "CSE311-dota-roguelike-datapull/0.1 (NSU student course project)"}
SLEEP = 1.3
DAY_MARGIN = 300
CALLS = 0

# Leagues counted as "pro" for chemistry, mastery and positions. 'excluded' is
# OpenDota's bucket for broken or joke leagues and is skipped.
TIERS = "('premium','professional')"


def get(url, params=None, tries=5):
    global CALLS
    for i in range(tries):
        time.sleep(SLEEP)
        try:
            r = requests.get(url, params=params, headers=UA, timeout=90)
            CALLS += 1
            left = r.headers.get("x-rate-limit-remaining-day")
            if left is not None and left.isdigit() and int(left) < DAY_MARGIN:
                sys.exit(f"stopping: only {left} calls left today (resume tomorrow)")
            if r.status_code == 429:
                time.sleep(30 * (i + 1)); continue
            r.raise_for_status()
            d = r.json()
            if isinstance(d, dict) and d.get("err"):
                raise RuntimeError(d["err"])
            return d
        except Exception as e:  # timeouts, 5xx, explorer read timeouts
            print(f"  retry {i+1}: {e}", file=sys.stderr)
            time.sleep(5 * (i + 1))
    raise RuntimeError(f"failed: {url} {params}")


def explorer(sql):
    return get(f"{API}/explorer", {"sql": sql})["rows"]


def write_csv(path, rows, cols):
    tmp = path + ".part"
    with gzip.open(tmp, "wt", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(cols)
        for r in rows:
            w.writerow(["" if r.get(c) is None else r.get(c) for c in cols])
    os.replace(tmp, path)
    return len(rows)


def epoch(d):
    return int(dt.datetime.strptime(d, "%Y-%m-%d").replace(tzinfo=dt.timezone.utc).timestamp())


MATCH_COLS = ["match_id", "leagueid", "start_time", "duration", "radiant_win",
              "radiant_team_id", "dire_team_id", "radiant_team_name", "dire_team_name",
              "radiant_score", "dire_score", "series_id", "series_type", "patch"]
PM_COLS = ["match_id", "account_id", "player_slot", "hero_id", "lane", "lane_role",
           "is_roaming", "gold_per_min", "xp_per_min", "last_hits", "kills", "deaths",
           "assists", "gold_10", "xp_10", "lh_10"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "raw", "opendota"))
    ap.add_argument("--from", dest="start", default="2012-01-01")
    ap.add_argument("--to", dest="end", default="2026-10-12")
    ap.add_argument("--days", type=int, default=30)
    a = ap.parse_args()
    out = os.path.abspath(a.out)
    os.makedirs(os.path.join(out, "matches"), exist_ok=True)
    os.makedirs(os.path.join(out, "player_matches"), exist_ok=True)

    # 1. Small reference tables
    p = os.path.join(out, "leagues.csv.gz")
    if not os.path.exists(p):
        rows = get(f"{API}/leagues")
        print("leagues", write_csv(p, rows, ["leagueid", "name", "tier", "ticket", "banner"]))
    p = os.path.join(out, "notable_players.csv.gz")
    if not os.path.exists(p):
        rows = explorer("select account_id, name, country_code, fantasy_role, team_id, "
                        "team_name, team_tag, is_locked, is_pro, locked_until from notable_players")
        print("notable_players", write_csv(p, rows, ["account_id", "name", "country_code",
              "fantasy_role", "team_id", "team_name", "team_tag", "is_locked", "is_pro", "locked_until"]))
    p = os.path.join(out, "heroes.csv.gz")
    if not os.path.exists(p):
        rows = get(f"{API}/heroes")
        for r in rows:
            r["roles"] = "|".join(r.get("roles") or [])
        print("heroes", write_csv(p, rows, ["id", "name", "localized_name", "primary_attr",
              "attack_type", "roles", "legs"]))

    # 2. Matches and player rows, in time slices (explorer has a 15 s read timeout)
    t, end = epoch(a.start), epoch(a.end)
    step = a.days * 86400
    while t < end:
        t2 = min(t + step, end)
        tag = dt.datetime.fromtimestamp(t, dt.timezone.utc).strftime("%Y%m%d")
        pm_path = os.path.join(out, "matches", f"m_{tag}.csv.gz")
        pp_path = os.path.join(out, "player_matches", f"pm_{tag}.csv.gz")
        where = (f"m.start_time >= {t} and m.start_time < {t2} and m.leagueid in "
                 f"(select leagueid from leagues where tier in {TIERS})")
        if not os.path.exists(pm_path):
            rows = explorer(
                "select m.match_id, m.leagueid, m.start_time, m.duration, m.radiant_win, "
                "m.radiant_team_id, m.dire_team_id, m.radiant_team_name, m.dire_team_name, "
                "m.radiant_score, m.dire_score, m.series_id, m.series_type, mp.patch "
                "from matches m left join match_patch mp using(match_id) where " + where)
            n = write_csv(pm_path, rows, MATCH_COLS)
            print(tag, "matches", n, flush=True)
        if not os.path.exists(pp_path):
            rows = explorer(
                "select pm.match_id, pm.account_id, pm.player_slot, pm.hero_id, pm.lane, "
                "pm.lane_role, pm.is_roaming, pm.gold_per_min, pm.xp_per_min, pm.last_hits, "
                "pm.kills, pm.deaths, pm.assists, pm.gold_t[11] gold_10, pm.xp_t[11] xp_10, "
                "pm.lh_t[11] lh_10 from player_matches pm where pm.match_id in "
                "(select m.match_id from matches m where " + where + ")")
            n = write_csv(pp_path, rows, PM_COLS)
            print(tag, "player_matches", n, flush=True)
        t = t2

    # 3. Teams that appear in those matches (explorer, chunks of 400 ids)
    p = os.path.join(out, "teams.csv.gz")
    if not os.path.exists(p):
        ids = set()
        mdir = os.path.join(out, "matches")
        for fn in os.listdir(mdir):
            with gzip.open(os.path.join(mdir, fn), "rt") as f:
                for r in csv.DictReader(f):
                    for k in ("radiant_team_id", "dire_team_id"):
                        if r[k]:
                            ids.add(int(r[k]))
        ids = sorted(ids)
        rows = []
        for i in range(0, len(ids), 400):
            chunk = ",".join(map(str, ids[i:i + 400]))
            rows += explorer(f"select team_id, name, tag from teams where team_id in ({chunk})")
        print("teams", write_csv(p, rows, ["team_id", "name", "tag"]))
    print("done, API calls this run:", CALLS)


if __name__ == "__main__":
    main()
