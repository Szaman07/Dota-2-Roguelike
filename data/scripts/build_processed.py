#!/usr/bin/env python3
"""DRAFT: turn data/raw into reviewable seed tables in data/processed.

Everything here is a *pre-fill for human review*, not final data. Each output
has a status/flag column saying how it was derived. The real derivations
(cards, ratings, chemistry, matchups) are SQL in docs/project/schema/etl_draft.sql;
this script only produces the hand-checked seed tables the SQL needs, plus a
few sanity tables to check the SQL against later.

Outputs (CSV):
  tier1_leagues_candidates.csv   OpenDota leagues that look like Liquipedia tier-1 main events
  finals_derived.csv             last series of each candidate league: finalists, winner, games
  pool_rosters_derived.csv       winner/finalist lineups after merging near-duplicates
  placements_derived.csv         placement proxy per league (by date of each team's last game)
  player_alias_candidates.csv    account -> player suggestions for the alias table
  hero_position_share_2024.csv   share of each hero's pro games at each estimated position
  hero_traits_prefill.csv        disables/mobility/lane/early/scaling pre-fill for hand checking

Usage: python3 -I build_processed.py
"""
import glob, json, os, re
import numpy as np
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "..", "raw")
OUT = os.path.join(HERE, "..", "processed")
os.makedirs(OUT, exist_ok=True)

# --------------------------------------------------------------------------
# Tier-1 heuristics. OpenDota's own tier label is unreliable (TI 2017 and the
# Kiev Major are "professional"; DPC Division II leagues are "premium"), so the
# candidate list is built from event-name families that Liquipedia lists as
# tier 1, then flagged for review. Liquipedia's list (pull_liquipedia.py)
# replaces this once Sadman runs it.
TIER1 = [
    (r"^The International 20\d\d$|^The International$", "TI"),
    (r"\bMajor\b", "Major"),
    (r"Dota2 Asia Championships|Dota 2 Asia Championships", "DAC"),
    (r"^ESL One\b", "ESL One"),
    (r"DreamLeague", "DreamLeague"),
    (r"^EPICENTER( XL|: Moscow| Major| 20\d\d)", "EPICENTER"),
    (r"^The Summit\b|^Dota Summit|DOTA Summit", "Summit"),
    (r"i-League Invitational|StarLadder \| i-League|StarSeries", "StarLadder"),
    (r"Perfect World Masters|CHINA DOTA2 SUPER MAJOR|MDL\b", "PW/MDL"),
    (r"WESG|World Electronic Sports Games", "WESG"),
    (r"Riyadh Masters|Esports World Cup|EWC", "Riyadh/EWC"),
    (r"BLAST Slam|PGL Wallachia|BetBoom Dacha|FISSURE|^Elite League|Clavision|Snow-Ruyi", "2024+ circuit"),
    (r"ONE Esports Singapore|ONE Dota 2 Singapore|Bali Major|Lima Major|Berlin Major|Arlington", "Major-like"),
    (r"Dota Pit|DOTA PIT", "Dota Pit"),
    (r"Galaxy Battles|Captains Draft|Kuala Lumpur|Chongqing|Bucharest|Stockholm", "Other tier-1 candidates"),
]
EXCLUDE = re.compile(r"qualif|division|\bdiv\b|closed|open quali|regional|minor|india|\bpro league\b|"
                     r"wild card|lima five|road to|last chance|playoffs? qual|showmatch|all.?star|"
                     r"no contribution|online|region\b|^DPC|torneo|verano|D2AU|DOTA PIT (CHINA|EU|NA|SEA)", re.I)


def read_dir(sub, usecols=None):
    files = sorted(glob.glob(os.path.join(RAW, "opendota", sub, "*.csv.gz")))
    return pd.concat([pd.read_csv(f, usecols=usecols) for f in files], ignore_index=True)


def main():
    leagues = pd.read_csv(os.path.join(RAW, "opendota", "leagues.csv.gz"))
    heroes = pd.read_csv(os.path.join(RAW, "opendota", "heroes.csv.gz"))
    notable = pd.read_csv(os.path.join(RAW, "opendota", "notable_players.csv.gz"))
    teams = pd.read_csv(os.path.join(RAW, "opendota", "teams.csv.gz")).set_index("team_id")["name"]
    m = read_dir("matches")
    pm = read_dir("player_matches")
    m["date"] = pd.to_datetime(m.start_time, unit="s", utc=True)
    m["radiant_win"] = m.radiant_win.astype(str).str.lower().eq("true")
    pm["is_radiant"] = pm.player_slot < 128
    pm = pm.merge(m[["match_id", "leagueid", "date", "radiant_win", "duration"]], on="match_id")
    pm["won"] = pm.is_radiant == pm.radiant_win
    print(f"matches {len(m):,}  player rows {len(pm):,}")

    # ---- 1. tier-1 league candidates ------------------------------------
    cnt = m.groupby("leagueid").agg(matches=("match_id", "size"), first=("date", "min"), last=("date", "max"))
    lg = leagues.join(cnt, on="leagueid", how="inner")
    fam = []
    for name in lg.name.fillna(""):
        f = next((tag for pat, tag in TIER1 if re.search(pat, name, re.I)), "")
        if f and EXCLUDE.search(name) and f != "TI":
            f = ""
        fam.append(f)
    lg["family"] = fam
    t1 = lg[(lg.family != "") & (lg.matches >= 20)].copy()
    t1["review"] = np.where(t1.family.isin(["TI", "Major", "DAC", "ESL One", "EPICENTER", "Riyadh/EWC", "2024+ circuit"]),
                            "likely tier 1", "check on Liquipedia")
    t1 = t1.sort_values("first")
    t1[["leagueid", "name", "tier", "family", "matches", "first", "last", "review"]].to_csv(
        os.path.join(OUT, "tier1_leagues_candidates.csv"), index=False)
    print("tier-1 candidates", len(t1))

    # ---- 2. finals and placements per candidate league --------------------
    pm_ok = pm[pm.account_id.notna()]
    lineup = (pm_ok.groupby(["match_id", "is_radiant"]).account_id
              .apply(lambda s: tuple(sorted(int(x) for x in s))).rename("lineup").reset_index())
    hs = pm.sort_values("player_slot").copy()
    hs["ph"] = hs.account_id.fillna(0).astype("int64").astype(str) + ":" + hs.hero_id.astype(str)
    heroes_side = hs.groupby(["match_id", "is_radiant"]).ph.agg("|".join).rename("players_heroes").reset_index()
    finals, places = [], []
    for _, L in t1.iterrows():
        mm = m[m.leagueid == L.leagueid].sort_values("start_time")
        if mm.empty:
            continue
        last = mm.iloc[-1]
        # final series = same series_id as the last game, else the same two lineups on the last day
        if pd.notna(last.series_id) and last.series_id > 0:
            fs = mm[mm.series_id == last.series_id]
        else:
            fs = mm[mm.date >= last.date - pd.Timedelta(hours=12)]
        lu = lineup[lineup.match_id.isin(fs.match_id)]
        lr = lu[lu.match_id == last.match_id]
        if len(lr) != 2:
            continue
        win_lineup = lr[lr.is_radiant == bool(last.radiant_win)].lineup.iloc[0]
        lose_lineup = lr[lr.is_radiant != bool(last.radiant_win)].lineup.iloc[0]
        for place, lu5, tid, tname in (
                (1, win_lineup, last.radiant_team_id if last.radiant_win else last.dire_team_id,
                 last.radiant_team_name if last.radiant_win else last.dire_team_name),
                (2, lose_lineup, last.dire_team_id if last.radiant_win else last.radiant_team_id,
                 last.dire_team_name if last.radiant_win else last.radiant_team_name)):
            # games of the final where >= 4 of these players were on one side
            games = []
            other5 = lose_lineup if place == 1 else win_lineup
            opp = {(r_.match_id, r_.is_radiant): r_.lineup for r_ in lu.itertuples()}
            for _, g in lu.iterrows():
                o = opp.get((g.match_id, not g.is_radiant), ())
                if len(set(g.lineup) & set(lu5)) >= 4 and len(set(o) & set(other5)) >= 4:
                    hs = heroes_side[(heroes_side.match_id == g.match_id) & (heroes_side.is_radiant == g.is_radiant)]
                    games.append(f"{g.match_id}:{'R' if g.is_radiant else 'D'}:{hs.players_heroes.iloc[0] if len(hs) else ''}")
            finals.append({"leagueid": L.leagueid, "league": L["name"], "family": L.family, "final_date": last.date.date(),
                           "place": place, "team_id": tid,
                           "team_name": tname if isinstance(tname, str) else teams.get(tid, ""),
                           "accounts": "|".join(map(str, lu5)), "n_games": len(games), "games": " ".join(games)})
        # placement proxy: teams (by lineup) ranked by the date of their last game in the league
        lt = pm_ok[pm_ok.leagueid == L.leagueid].copy()
        lt["team_id"] = np.where(lt.is_radiant, lt.match_id.map(mm.set_index("match_id").radiant_team_id),
                                 lt.match_id.map(mm.set_index("match_id").dire_team_id))
        tl = lt.groupby("team_id").date.max().sort_values(ascending=False)
        rank = tl.rank(method="min", ascending=False)
        for tid_, r in rank.items():
            places.append({"leagueid": L.leagueid, "league": L["name"], "team_id": tid_, "proxy_place": int(r),
                           "source": "derived: date of last game (TI 2024 matched official top 8)"})
    fin = pd.DataFrame(finals)
    fin.to_csv(os.path.join(OUT, "finals_derived.csv"), index=False)
    pd.DataFrame(places).to_csv(os.path.join(OUT, "placements_derived.csv"), index=False)
    print("finals rows", len(fin))

    # ---- 3. pool rosters: merge lineups sharing 4+ players within 2 years --
    fin = fin.sort_values(["final_date", "place"])
    roster_id, rid = [], {}
    kept = []
    for i, r in fin.iterrows():
        s = set(r.accounts.split("|"))
        match = None
        for k in kept:
            if len(s & k["set"]) >= 4 and abs((pd.Timestamp(r.final_date) - pd.Timestamp(k["date"])).days) <= 730:
                match = k; break
        if match is None:
            match = {"id": len(kept) + 1, "set": s, "date": r.final_date}
            kept.append(match)
        else:
            match["date"] = r.final_date
        roster_id.append(match["id"])
    fin["roster_group"] = roster_id
    fin["titles_in_group"] = fin.groupby("roster_group").place.transform(lambda p: (p == 1).sum())
    # one representative per group: its latest title, else its latest final
    fin["is_rep"] = False
    for g, d in fin.groupby("roster_group"):
        rep = d[d.place == 1].tail(1) if (d.place == 1).any() else d.tail(1)
        fin.loc[rep.index, "is_rep"] = True
    fin.to_csv(os.path.join(OUT, "pool_rosters_derived.csv"), index=False)
    print("distinct rosters", fin.roster_group.nunique(), "with a title", (fin[fin.is_rep].place == 1).sum())

    # ---- 4. alias candidates ---------------------------------------------
    games = pm_ok.groupby("account_id").agg(games=("match_id", "size"), first=("date", "min"), last=("date", "max"))
    t1_games = pm_ok[pm_ok.leagueid.isin(t1.leagueid)].groupby("account_id").size().rename("tier1_games")
    acc = games.join(t1_games).fillna({"tier1_games": 0}).reset_index()
    acc = acc.merge(notable[["account_id", "name", "team_name", "country_code"]], on="account_id", how="left")
    acc["name_key"] = acc.name.fillna("").str.lower().str.replace(r"[^a-z0-9]", "", regex=True)
    # most common team per account (by team name on the match row)
    side_team = pm_ok.merge(m[["match_id", "radiant_team_id", "dire_team_id"]], on="match_id")
    side_team["team"] = np.where(side_team.is_radiant, side_team.radiant_team_id, side_team.dire_team_id)
    side_team["team"] = side_team.team.map(teams).fillna("no team")
    tt = (side_team.groupby(["account_id", "team"]).size().rename("n").reset_index()
          .sort_values("n", ascending=False).groupby("account_id").head(3))
    tt["label"] = tt.team.astype(str) + " (" + tt.n.astype(str) + ")"
    top_team = tt.groupby("account_id").label.agg("; ".join).rename("main_teams")
    acc = acc.join(top_team, on="account_id")
    acc = acc[acc.games >= 100].copy()
    acc["account_id"] = acc.account_id.astype("int64")
    # known aliases verified in earlier research threads
    known = {86745912: "Arteezy", 73562326: "Zai", 121769650: "Nisha", 201358612: "Nisha"}
    acc["suggested_player"] = acc.account_id.map(known).fillna(acc.name)
    dup = acc[acc.name_key != ""].groupby("name_key").account_id.transform("size")
    acc["status"] = np.select(
        [acc.account_id.isin(known), acc.name.isna(), dup.reindex(acc.index).fillna(1) > 1],
        ["verified in research", "UNNAMED: identify by roster slot", "same name on several accounts: check teams/dates"],
        "auto (single named account)")
    acc = acc.sort_values("tier1_games", ascending=False)
    acc[["account_id", "suggested_player", "status", "name", "games", "tier1_games", "first", "last",
         "main_teams", "country_code"]].to_csv(os.path.join(OUT, "player_alias_candidates.csv"), index=False)
    print("alias candidate accounts", len(acc))

    # ---- 5. hero position shares since 2024 -------------------------------
    r = pm[pm.date >= "2024-01-01"].copy()
    r["rk_lane"] = r.groupby(["match_id", "is_radiant", "lane_role"]).gold_per_min.rank(ascending=False, method="first")
    r["rk_team"] = r.groupby(["match_id", "is_radiant"]).gold_per_min.rank(ascending=False, method="first")
    r["pos"] = np.select([r.lane_role == 2, (r.lane_role == 1) & (r.rk_lane == 1), r.lane_role == 1,
                          (r.lane_role == 3) & (r.rk_lane == 1), r.lane_role == 3],
                         [2, 1, 5, 3, 4], r.rk_team).astype(int)
    hp = r.groupby(["hero_id", "pos"]).size().rename("games").reset_index()
    hp["share"] = hp.games / hp.groupby("hero_id").games.transform("sum")
    hp = hp.merge(heroes[["id", "localized_name"]], left_on="hero_id", right_on="id").drop(columns="id")
    hp.to_csv(os.path.join(OUT, "hero_position_share_2024.csv"), index=False)

    # ---- 6. hero traits pre-fill -----------------------------------------
    mech = pd.read_csv(os.path.join(RAW, "wiki", "mechanic_sources.csv"))
    names = set(heroes.localized_name)
    mech = mech[mech.source.isin(names)]
    hard = mech[mech.mechanic.isin(["Stun", "Root", "Hex", "Sleep", "Cyclone", "Fear", "Taunt", "Leash"])]
    dis = hard.groupby("source").ability.nunique().rename("hard_disables")
    sil = mech[mech.mechanic == "Silence"].groupby("source").ability.nunique().rename("silences")
    inv = mech[mech.mechanic == "Invisibility"].groupby("source").ability.nunique().rename("invis_abilities")
    mech = mech.assign(label=mech.ability + " (" + mech.mechanic + ")")
    lst = mech.groupby("source").label.agg(lambda x: "; ".join(sorted(x))).rename("wiki_abilities")
    consts = json.load(open(os.path.join(RAW, "dotaconstants", "heroes.json")))
    cdf = pd.DataFrame([{"id": int(v["id"]), "attack_range": v.get("attack_range"), "move_speed": v.get("move_speed")}
                        for v in consts.values()])
    tr = heroes.merge(cdf, on="id", how="left").set_index("localized_name")
    tr = tr.join(dis).join(sil).join(inv).join(lst).fillna({"hard_disables": 0, "silences": 0, "invis_abilities": 0})
    # lane strength: mid gold diff at 10 vs the enemy mid, and side-lane core vs enemy core, since 2024
    mids = r[(r.lane_role == 2) & (r.rk_lane == 1)][["match_id", "is_radiant", "hero_id", "gold_10"]]  # the real mid, not a rotating support
    mm2 = mids.merge(mids, on="match_id", suffixes=("", "_o"))
    mm2 = mm2[mm2.is_radiant != mm2.is_radiant_o]
    mid_ls = (mm2.gold_10 - mm2.gold_10_o).groupby(mm2.hero_id).agg(["mean", "size"])
    # early vs late: win rate in games < 30 min minus win rate in games >= 45 min
    r["bucket"] = pd.cut(r.duration, [0, 1800, 2700, 99999], labels=["lt30", "30to45", "ge45"], right=False)
    ph = r.groupby(["hero_id", "bucket"], observed=False).won.mean().unstack().reindex(columns=["lt30", "30to45", "ge45"])
    tr = tr.reset_index().set_index("id")
    tr["mid_gold10_diff"] = mid_ls["mean"].round(0)
    tr["mid_games"] = mid_ls["size"]
    tr["wr_lt30"] = ph["lt30"].round(3)
    tr["wr_ge45"] = ph["ge45"].round(3)
    tr["games_2024"] = r.groupby("hero_id").size()
    # pre-fill rules (all to be corrected by hand)
    tr["disables_prefill"] = np.minimum(5, tr.hard_disables + 0.5 * tr.silences).round().astype(int)
    roles = tr.roles.fillna("")
    tr["mobility_prefill"] = np.where(roles.str.contains("Escape") & (tr.invis_abilities > 0), 3,
                              np.where(roles.str.contains("Escape"), 2, np.where(tr.move_speed >= 305, 1, 0)))
    tr["summons_push_prefill"] = roles.str.contains("Pusher")
    diff = (tr.wr_lt30 - tr.wr_ge45)
    tr["early_prefill"] = np.select([diff > 0.08, diff > 0.03, diff < -0.08, diff < -0.03], [2, 1, -2, -1], 0)
    tr["scaling_prefill"] = -tr.early_prefill
    tr["lane_prefill"] = np.select([tr.mid_gold10_diff > 300, tr.mid_gold10_diff > 100,
                                    tr.mid_gold10_diff < -300, tr.mid_gold10_diff < -100], [2, 1, -2, -1], 0)
    tr.loc[tr.mid_games.fillna(0) < 50, "lane_prefill"] = 0   # too few mid games: neutral, check by hand
    tr["teamfight_ult_prefill"] = ""                           # no data source: fill by hand
    tr["save_prefill"] = ""
    tr["status"] = "prefill"
    cols = ["localized_name", "attack_type", "attack_range", "move_speed", "roles", "disables_prefill",
            "teamfight_ult_prefill", "mobility_prefill", "lane_prefill", "early_prefill", "scaling_prefill",
            "summons_push_prefill", "save_prefill", "hard_disables", "silences", "invis_abilities",
            "mid_gold10_diff", "mid_games", "wr_lt30", "wr_ge45", "games_2024", "wiki_abilities", "status"]
    tr.reset_index().rename(columns={"id": "hero_id"})[["hero_id"] + cols].to_csv(
        os.path.join(OUT, "hero_traits_prefill.csv"), index=False)
    print("hero traits rows", len(tr))


if __name__ == "__main__":
    main()
