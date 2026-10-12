# Data for The All-Time International

_Pulled 2026-10-11 (UTC) from the project's cloud session. Everything the game needs to be built, short of the Liquipedia pull, which Sadman has to run himself (see "Gaps"). Total on disk: **about 58 MB** (56 MB raw OpenDota, gzipped CSV)._

## Layout
```
data/
  scripts/   pull_opendota.py, pull_wiki.py, pull_liquipedia.py (not run), build_processed.py
  raw/       exactly what the sources returned, as CSV/JSON (never edited by hand)
  processed/ pre-filled seed tables for hand review + sanity tables
```
Scripts are drafts for review. Run them with `python3 -I <script>` (needs `requests` and `pandas`). All are resumable and skip files that already exist.

## Sources and terms
| Source | Used for | Terms / politeness |
|---|---|---|
| **OpenDota API** (api.opendota.com, free tier, no key) | Pro matches, player rows, leagues, teams, notable players, heroes | 60 calls/min, 3,000/day. The pull used **420 calls**, 1.3 s apart, with a daily-quota stop |
| **Dota 2 Wiki** (dota2.fandom.com MediaWiki API) | Which abilities stun, silence, root, hex, etc. | CC-BY-SA; 15 requests, 3 s apart. Current patch only (page revision ids saved) |
| **odota/dotaconstants** (GitHub raw) | Hero attack range, move speed, abilities, patch dates | MIT licence; 3 files |
| **Liquipedia** MediaWiki API | Tier-1 tournaments and placements | **Not pulled.** Its robots.txt disallows Anthropic's agents (ClaudeBot, Claude-Web), so I wrote [pull_liquipedia.py](scripts/pull_liquipedia.py) for you to run with your own email in the User-Agent (about 20 requests, per their API terms). CC-BY-SA 3.0: credit it |
| 322-0.app | Nothing | Studied only; none of its data is copied |
| Valve Steam Web API | Nothing | Not needed (no key created) |

## raw/opendota
"Pro" = OpenDota leagues tiered `premium` or `professional` (`excluded` is skipped). That's wider than tier 1 on purpose: chemistry, hero mastery and positions need every pro game, while tier-1 status (for the pool and placements) is a filter applied later.

| File(s) | Rows | Size | Notes |
|---|---|---|---|
| `matches/m_YYYYMMDD.csv.gz` (180 thirty-day slices, 2012-01-01 → 2026-10-12) | **226,846** matches in 1,973 leagues | 5.1 MB | match_id, league, start time, duration, winner, team ids, series id/type, patch |
| `player_matches/pm_YYYYMMDD.csv.gz` | **2,268,452** player rows, 97,083 accounts | 50 MB | hero, slot (side), lane, lane_role, roaming, GPM/XPM, last hits, K/D/A, **gold/XP/last hits at 10 min** |
| `leagues.csv.gz` | 10,348 | 144 KB | id, name, OpenDota tier |
| `teams.csv.gz` | 21,810 | 292 KB | only teams that appear in the matches. **Names are today's names** (EG's id shows as "Shopify Rebellion", DC's as "123"), so packs must use the org table |
| `notable_players.csv.gz` | 5,657 | 144 KB | OpenDota's pro-player names; many stars are unnamed or mis-named |
| `heroes.csv.gz` | 127 | 4 KB | id, names, attribute, attack type, Valve role tags |

**Coverage by year** (player rows; share of rows with lane_role and gold at 10 min):

| Year | Matches | Lane data | Gold@10 | | Year | Matches | Lane data | Gold@10 |
|---|---|---|---|---|---|---|---|---|
| 2012 | 1,290 | 0% | 0% | | 2020 | 22,384 | 99.8% | 99.6% |
| 2013 | 5,389 | 0% | 0% | | 2021 | 16,807 | 99.0% | 98.8% |
| 2014 | 12,424 | 0.2% | 0.2% | | 2022 | 24,951 | 99.9% | 99.8% |
| 2015 | 12,295 | 30% | 30% | | 2023 | 30,502 | 99.7% | 99.6% |
| 2016 | 10,803 | 96.5% | 96.4% | | 2024 | 26,483 | 99.7% | 99.5% |
| 2017 | 11,067 | 95.1% | 95.0% | | 2025 | 20,244 | 100% | 99.8% |
| 2018 | 9,131 | 98.3% | 98.2% | | 2026 (to Oct) | 5,479 | 99.9% | 99.6% |
| 2019 | 17,597 | 95.8% | 95.6% | | | | | |

The 2026 count is low compared with 2023–2025 (OpenDota seems to have fewer 2026 pro games so far), though every TI 2026 final game is there.

## raw/wiki and raw/dotaconstants
- `wiki/<Page>.wikitext.json`: raw wikitext of 15 mechanic pages. `wiki/mechanic_sources.csv`: **443** (mechanic, source, ability) rows: Stun 127, Invisibility 94, Silence 69, Break 47, Root 39, Disarm 27, Fear 11, Hex 7, Cyclone 6, Leash 6, Taunt 6, Sleep 4. "Slow", "Banish" and "Mute" are redirects or use another layout, so they returned nothing.
- `dotaconstants/heroes.json`, `hero_abilities.json`, `patch.json` (61 patches, 6.70 → 7.41).

## processed/ (pre-fills for hand review, from build_processed.py)
| File | Rows | What it is | Review needed |
|---|---|---|---|
| `tier1_leagues_candidates.csv` | 159 leagues (98 "likely tier 1", 61 "check") | OpenDota leagues whose names match tier-1 event families (TI, Majors, DAC, ESL One, DreamLeague, EPICENTER, Riyadh/EWC, PGL Wallachia, BLAST Slam, FISSURE, BetBoom Dacha...), qualifiers and regional events removed | Replace with Liquipedia's list once pulled |
| `finals_derived.csv` | 318 (159 finals × 2) | The last series of each candidate league: winner and runner-up lineups (by account, not team id), and for each final game `match:side:account:hero` × 5 | All 14 TI finals 2012–2026 come out right (e.g. TI7 Liquid over Newbee in 3 games, TI8 OG over LGD in 5) |
| `pool_rosters_derived.csv` | 142 distinct rosters (80 with a title) | Finals merged when lineups share 4+ players within 2 years; `is_rep` marks the version kept | Thin for 2020–2023 (DPC era) until Liquipedia's list is used |
| `placements_derived.csv` | 5,665 | Placement proxy per league: teams ranked by the date of their last game (matched TI 2024's official top 8 in research) | Fallback only |
| `player_alias_candidates.csv` | 3,086 accounts with 100+ pro games | Suggested player per account, with tier-1 games, dates and top 3 teams. Status: 4 verified in research (Arteezy, Zai, Nisha ×2), 588 single named accounts, 12 names on several accounts, **2,482 unnamed** | Hand-check the top ~150 by tier-1 games |
| `hero_position_share_2024.csv` | 633 | Share of each hero's pro games at each estimated position since 2024 | Matches research (Gyrocopter 22% at pos 4/5; Shadow Fiend 0.4%) |
| `hero_traits_prefill.csv` | 127 | Disables, mobility, lane strength, early/scaling pre-fills with the evidence beside them (wiki abilities, mid gold@10, win rate under 30 vs over 45 min) | Every row; `teamfight_ult` and `save` are blank (no data source) |

## Gaps (also in docs/project/audit.md)
1. **Liquipedia** not pulled (robots.txt): run `python3 -I scripts/pull_liquipedia.py --contact you@example.com` once.
2. **TI 2011** isn't in OpenDota.
3. **Positions before 2016** can only be guessed from GPM rank (no lane data).
4. **Hero mechanics are current-patch only.**
5. The derived layer (cards, ratings, chemistry, matchups) is computed in MySQL by `docs/project/schema/etl_draft.sql`, not stored here, so it reflects whatever the alias and org tables say after review.

## Loading into MySQL (estimate)
Uncompressed the player rows are about 146 MB of CSV; in InnoDB with the draft's indexes expect roughly 400–600 MB. `LOAD DATA LOCAL INFILE` per slice takes minutes on a laptop.
