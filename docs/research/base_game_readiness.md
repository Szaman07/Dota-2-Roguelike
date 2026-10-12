# Base game readiness check (research only)

_Date: 2026-10-11, 19:15 UTC. Pulls together the teardown, [rating_and_roles.md](rating_and_roles.md) and [team_synergy.md](team_synergy.md). Every choice is still Sadman's; where I note a "default", it's only a starting point for you to accept or change._

## Verdict

**Yes, the base game is buildable on free data.** Every number it needs has a verified free source and a known SQL shape:
- player-hero games, groups of players with shared games, rosters per league, positions, game-length win rates and 10-minute lane leads were all pulled live from OpenDota;
- the hero data comes from dotaconstants;
- placements can be derived and hand-corrected.

What's left is **design tuning** (weights, thresholds) and **one curated table** (hero traits). There are no feasibility gaps. The biggest risks are listed in §3.

---

## 1. Decided so far

| Area | Decision |
|---|---|
| Stack | PHP + MySQL 8.0+ (your own machines, so the lab version doesn't matter) |
| Data | Free only: OpenDota (no key) + the Valve Steam Web API; hand-entered seed tables where needed |
| Packs | Team packs (an org's players across its history) |
| Player rating | No per-event ratings. Composite of win rate + peak window + consistency + placements, scaled so most cards stay playable and legends aren't sunk by one event |
| Variants | Rolling windows of ≥ 3 years from debut, stretched for long careers; short last window merges; **max 3 cards per player** |
| Roles | Dynamic: a drafted player can be moved to another position |
| Hero mastery | A player's pro games on a hero, counted at any position (no double penalty) |
| Hero-position fit | Rewards real flexes (Gyrocopter pos 4/5 ≈ 18% of games) and penalizes off-meta placements (Shadow Fiend support < 0.4%) |
| Chemistry | Pairs, trios, quads and five-stacks (322-0 style) |
| Hero allocation | Both automatic and manual |
| Team scores at the end | Disables, teamfight, pickoff (pos 4 + pos 5 + mid), scaling vs early/snowball, lane duos (melee/ranged + lane strength), mid lane |
| Parked | Archetype counter cycle and hero matchups, for the teammate's 1v1 module |

---

## 2. Remaining questions (combined, most important first)

> **Update 21:45 UTC:** the gauntlet has since been replaced. Per Sadman (21:43 UTC, gauntlet thread), the run is now a full TI: opening draft, a group stage (a loss gives 2 picks, a win 1), then a double-elimination bracket against tier-1 winners and finalists playing their real final drafts. There's a 5-slot bench, no era factor, and counters and matchups are back in scope. Always read [game_design.md](game_design.md) for the current design.

> **Update 20:25 UTC:** Sadman answered most of the questions below in the gauntlet thread (20:16 UTC). [game_design.md](game_design.md) is now the source of truth; this table is kept for history.
> - **Answered:** 1 (one pick per pack, player or hero), 2 (random heroes), 4 (no accounts, no leaderboard), 5 (player pool = Liquipedia tier-1 events, shortened if too big), 6 (his four-part mix; weights left to us), 9 (placements from Liquipedia).
> - **Left to Claude:** 8 (hero-position formula), 10 (hero traits).
> - **Not yet addressed here:** 7 (off-role penalty), 13 (two variants of one player on a team), 14 (career vs window for mastery and chemistry; chemistry is being reworked as "time together" in game_design.md).

> **Update 20:05 UTC:** Sadman answered questions 3, 11 and 12 in the "Boss gauntlet roguelike audit" thread (19:54 UTC). The run ends in a historic-boss gauntlet instead of a TI sim. Team scores feed a phase-based dice sim. Opponents are TI-winner bosses plus era underlings. The merged design, which supersedes this doc where they differ, is in [game_design.md](game_design.md). It also raises a chemistry-cap problem for boss five-stacks.

I've grouped them so you can answer in one pass. The "default" column is what I'd start from if you just say "go"; each one is easy to change later.

| # | Question | Options | Default |
|---|---|---|---|
| 1 | **Draft loop**: keep 322-0's "one item per pack (player *or* hero), 10 picks"? | keep / player + hero per pack / separate hero phase | keep |
| 2 | **Which heroes a team pack offers** | the org's most-played heroes (in that era) / random from all heroes | org's most-played |
| 3 | ~~**Run end**~~ (answered: gauntlet, see game_design.md): one TI-style sim against an 18-team field, like 322-0? | yes / league season / multiple events | yes |
| 4 | **Accounts and leaderboard**: users log in and runs are saved server-side? (This is what makes the transaction and concurrency lessons real.) | yes / single-user local | yes |
| 5 | **Player pool**: which leagues count, and the minimum games for a card | TI + Majors only / all tier-1 / premium + professional; min 100–300 games | premium + professional, ≥ 200 games |
| 6 | **Rating weights** (win rate / peak / consistency / placements) | your call | 30 / 25 / 15 / 30 to start, then tune |
| 7 | **Off-role penalty** for dynamic roles | flat / experience-scaled / per-position rating | experience-scaled |
| 8 | **Hero-position formula** | threshold / smooth curve / patch-aware | threshold (< 1% penalty, 1–40% flex bonus) |
| 9 | **Placements source** | derived / Liquipedia / hand-entered / mix | derived + hand-fixed TIs and Majors |
| 10 | **Hero traits** | curated / pro-stats / blend | blend: I pre-fill, you correct |
| 11 | ~~**How team scores reach the result**~~ (answered: phase-based dice sim) | OVR bonus / phase-aware sim / both | both, with the OVR part small |
| 12 | ~~**Field teams**~~ (answered: bosses + era underlings) | plain ratings (322-0) / given archetypes | plain ratings for the base game |

Two smaller rules that come up in the edge cases below:

| # | Question | Default |
|---|---|---|
| 13 | Can two variants of the same player be on one team? | no |
| 14 | Do hero mastery and chemistry count the **whole career** or only the variant's window? | mastery: the window; chemistry: whole career (players who played together, played together) |

---

## 3. Edge cases (found or checked) and how each could be handled

| Edge case | Evidence | Handling options |
|---|---|---|
| **One player, several Steam accounts** | `notable_players` lists **Yatoro under 6 account_ids** and Miracle- under 2 (VERIFIED, `samples/od_explorer_alias.json`) | A `player_account` table (player 1–n account_id), so every stat is grouped by player, not by account. A hand-checked alias list for card players |
| **Org rebrands, duplicate team ids, look-alike names** | Two real "Natus Vincere" team_ids (36 and 9828954) plus dozens of look-alikes ("Nasos Vicer", "NatusVincere!") (VERIFIED, `samples/od_explorer_teams_alias.json`) | An `org` table with `org_team` (org 1–n team_id), seeded by hand for the orgs you include. Team packs read from `org`, never from raw names |
| **No lane data before 2016** | `lane_role` is missing at TI 2012–2015 (VERIFIED) | Use GPM rank for old positions (rougher), or hand-set the role for old-era cards, or start the card pool at 2016 |
| **Stand-ins** | A player with 3 games for an org would show up in its pack | A minimum games per (player, org) to appear in a pack |
| **New heroes with few games** | Hero-position shares are unstable at low counts | Below N games, treat position fit as neutral |
| **Patches change roles** | Terrorblade's game-length profile contradicts its reputation; OD isn't a lane dominator in this window (VERIFIED) | Compute hero stats per patch era (question 8 "patch-aware"), or accept a single all-time number |
| **Hero not released in a player's era** | e.g. a 2013 card with Marci | Mastery is naturally 0; optionally hide such heroes from that card's pack |
| **Dynamic role creates two pos 1s** | Slot rule 1-1-1-2 | Check in the same transaction as the role change (CHECK/trigger + `SELECT … FOR UPDATE`) |
| **Same hero twice / same player twice** | — | `UNIQUE(run, hero)`, `UNIQUE(run, player)` (question 13) |
| **Rate limits during the build** | Free OpenDota day quota looked shared per IP in this environment; explorer has a 15 s timeout (one of my joins timed out until I narrowed the date range) | Build summaries in date slices, cache everything in MySQL, never call APIs during gameplay; incremental refresh by `match_id > last_imported` |
| **Anonymous players (Valve API)** | Players who hide match data show as id 4294967295 | Use OpenDota's pro tables for identities; Valve only for raw matches; drop anonymous slots from stats |
| **Reproducible sims** | 322-0 stores seeds | Store the seed on each run so a result can be replayed and audited |
| **Double-click reroll or simulate** | — | Row lock on the run, or a version column; a reroll counter that can't go negative (CHECK) |

---

## 4. Suggested build order (once you say "build")
1. **ETL:** OpenDota explorer → staging tables → MySQL (players, accounts, orgs, matches, match_player with derived position).
2. **Summaries:** player_hero_stats, player groups (2–5), hero_position_stats, hero_phase_stats, hero_lane_stats; ratings and variants.
3. **Seed tables:** hero traits (pre-filled for your correction), placements for TIs and Majors, org aliases.
4. **Game:** draft → scoring → field → sim → results, with runs, rerolls and history in MySQL.
5. **Polish:** leaderboard, tuning pass on weights with you and your teammate.
