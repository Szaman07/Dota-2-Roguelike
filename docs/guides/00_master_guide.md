# Master guide: A Dice-Based Tournament Roguelike Deck Builder (CSE311 project)

_Written 2026-10-11. A plain-language tour of the whole project, from the game idea to the database behind it. Every section links to the detailed doc. The schema is still a **draft**: table names and examples follow [schema_draft.sql](../project/schema/schema_draft.sql) as it stands today, and Sadman makes the final design calls._

**The three guides**
1. **This master guide**: what the game is, where the data comes from, how the database is laid out, and how a run flows through it.
2. [01_theory_guide.md](01_theory_guide.md): the CSE311 theory itself (ER, keys, relational model, normalization, SQL, transactions, concurrency, indexing, triggers and procedures).
3. [02_course_to_project.md](02_course_to_project.md): each course topic shown on this project's real tables and data.

---

## 1. The project in one paragraph

You draft an all-time Dota 2 team from 15 years of pro history, then take it through a full TI. Each pack is an org (Liquid, Secret, Spirit...) offering era cards of its players and five random heroes; you take exactly one card per pack. After 10 picks you must have exactly 5 players and 5 heroes: once you hold 5 players, later packs only offer their heroes, and the other way round. You then play a 16-team International (two groups of 8, then a double-elimination bracket) against real winning and finalist rosters, each playing the actual draft from its final. Games are simulated with 2d6 dice that care about lanes, teamfights, pickoffs, Roshan, counters and chemistry. One life, no accounts, no unlocks. It's built in **PHP + MySQL 8**, and the database does most of the work: ratings, chemistry, mastery, standings and the bracket are all SQL.

Full detail: [game_outline.md](../project/game_outline.md) (the game) and [proposal.md](../project/proposal.md) (the course proposal).

## 2. Where to read what

| If you want... | Read |
|---|---|
| The pitch and course proposal | [proposal.md](../project/proposal.md) |
| Every screen, rule and formula | [game_outline.md](../project/game_outline.md) |
| The settled design and its history | [game_design.md](../research/game_design.md) (rev 6) |
| What's still undecided (27 points, each with a default) | [open_questions.md](../project/open_questions.md) |
| Consistency, data and feasibility checks | [audit.md](../project/audit.md) |
| NSU's 8 CSE311 objectives mapped to features, plus a report outline | [dbms_coursework_map.md](../project/dbms_coursework_map.md) |
| Tables and relationships | [er_diagram.md](../project/schema/er_diagram.md), [schema_draft.sql](../project/schema/schema_draft.sql) |
| Loading the data and building ratings | [etl_draft.sql](../project/schema/etl_draft.sql) |
| The main game and demo queries | [queries_draft.sql](../project/schema/queries_draft.sql) |
| Milestones and a two-person split | [build_plan.md](../project/build_plan.md) |
| A ready-made prompt to start building with Claude Code | [claude_code_build_prompt.md](../project/claude_code_build_prompt.md) |
| What data was pulled and how | [data/README.md](../../data/README.md) |
| Research background | [322-0_teardown.md](../research/322-0_teardown.md), [rating_and_roles.md](../research/rating_and_roles.md), [team_synergy.md](../research/team_synergy.md), [ti_mode_audit.md](../research/ti_mode_audit.md) |

## 3. Folder map (this folder on your computer)

```
311(dota)/
  docs/
    guides/      <- these three learning guides
    project/     proposal, outline, audit, coursework map, open questions, build plan
      schema/    schema_draft.sql, er_diagram.md, etl_draft.sql, queries_draft.sql
    research/    design history and research (game_design.md is the main one)
  data/
    raw/         exactly what the sources returned (never edited by hand)
      opendota/  matches/ and player_matches/ in 30-day slices, plus leagues, teams, heroes...
      wiki/      Dota 2 Wiki mechanic pages (stuns, silences, roots...)
      dotaconstants/  hero stats, abilities, patches
    processed/   pre-filled tables to hand-check (aliases, tier-1 leagues, finals, hero traits)
    scripts/     the Python pull and build scripts
  research/      an early 322-0 breakdown
```

## 4. Where the data comes from (all free)

| Source | What it gives the game |
|---|---|
| **OpenDota API** | 226,846 pro matches and 2,268,452 player rows (2012 to 2026): who played which hero, on which side, lane, GPM, and gold at 10 minutes |
| **Dota 2 Wiki** | Which abilities stun, silence, root or hex (current patch only) |
| **dotaconstants** | Hero attack type, range, speed, patches |
| **Liquipedia** | Tier-1 tournament list and placements. **Not pulled yet**: its robots.txt blocks Claude, so you run [pull_liquipedia.py](../../data/scripts/pull_liquipedia.py) yourself once |

Two things the raw data gets wrong, and why the database needs extra tables to fix them:
- **One person, many accounts.** Arteezy, Nisha, Zai and Yatoro each played on several Steam accounts. The `account → player` link (the alias table) merges them.
- **One org, many team ids, and today's names.** EG's old team id now shows as "Shopify Rebellion". The `org` and `org_team` tables group team ids under the real org.

More: [data/README.md](../../data/README.md), [audit.md §2](../project/audit.md).

## 5. How the database is organised

The draft has **42 tables in three layers**, all in one MySQL database called `ati`:

| Layer | What it holds | Who writes it | Examples |
|---|---|---|---|
| **A. Reference** | Facts imported from the sources | The load script, once | `hero`, `pro_match`, `match_player`, `player`, `account`, `team`, `org`, `tournament`, `placement` |
| **B. Derived** | Summaries computed by SQL from layer A | The ETL script, rebuilt whenever data changes | `player_card` (era cards and ratings), `card_hero` (mastery), `player_pair` (chemistry), `hero_matchup` (counters), `pool_roster` (the AI field) |
| **C. Game state** | Everything a run creates while you play | The PHP game, per click | `run`, `run_pack`, `run_card`, `run_team`, `series`, `game`, `game_lineup`, `game_event` |

Before layer A, raw CSVs land in **staging tables** (`stg_match`, `stg_player_match`, ...) that mirror the CSV columns exactly. The draft keeps them inside `ati`; keeping them in a separate raw database instead is an option discussed in [02_course_to_project.md §6](02_course_to_project.md#6-more-than-one-database-raw-import-next-to-the-game).

```
CSV files ──LOAD DATA──► staging (stg_*) ──INSERT…SELECT──► A. reference ──ETL SQL──► B. derived
                                                                     ▲                     │
                                                                     └──── read by ────────┤
                                                                                           ▼
                                                    PHP game ──reads A+B, writes──► C. game state
```

The key chain that links almost everything:

```
match_player ─► account ─► player ─► player_card ─► card_hero / card_position / card_org ─► org
     │                                                     ▲
     └─► pro_match ─► league ─► tournament_league ─► tournament ─► placement
```

Diagram with every table: [er_diagram.md](../project/schema/er_diagram.md).

## 6. A run, step by step, and what the database does

| Step | What you see | What MySQL does |
|---|---|---|
| Start a run | Pick difficulty and hero allocation | `INSERT` one `run` row with a random seed |
| Draft (10 packs) | An org's 5 player cards and 5 heroes | Read `card_org` + `player_card` for a random org; `INSERT` the pack into `run_pack` / `run_pack_option`; on a pick, `INSERT` into `run_card`, all inside one transaction |
| Team screen | Roles, heroes, mastery, chemistry, team scores | Read `card_hero` (mastery), `match_player` (games together), `hero_position_share` (fit), `hero_trait` |
| Group stage | Standings, your next opponent | Read the `v_group_standings` view |
| Play a game | Dice replay | `INSERT` the `game` row with its seed **before** simulating, then `game_lineup` and `game_event` rows; `UNIQUE (series_id, game_no)` stops a refresh from re-rolling |
| Rewards | Picks onto a 5-slot bench, or an upgrade to another era card | `INSERT`/`UPDATE run_card`; upgrades logged in `run_upgrade` |
| Playoffs | Double-elimination bracket | Each `series` row points to the series its winner and loser go to next; `sp_finish_series` moves both teams in one transaction |
| Result | Final place, roster, record | `UPDATE run SET status = 'finished'` |

## 7. The key game ideas, in brief

- **Era cards.** Each player gets one card per era (a window of 3 years or a third of their career, whichever is longer; at most 3 cards). Prime Ceb and late Ceb are different cards.
- **Rating** (68 to 99) mixes win rate, peak, consistency (including longevity) and placements, weighted 30 / 25 / 15 / 30 by default, computed with SQL window functions.
- **Hero mastery** counts games a player's card played on a hero. **Hero-position fit** rewards real flexes (Gyrocopter support) and penalises off-meta picks (Shadow Fiend support).
- **Roles.** Each card has a **main role** plus **alternate roles** from real pro data: a position counts as alternate if it's at least 15% of that card's matches, or the main role of another of the same player's cards. Main and alternate roles carry no penalty; any other role gets an experience-scaled off-role penalty.
- **Chemistry** applies to your team only and is counted by matches your players played together (same match, same side), through the alias table.
- **The field** is real tier-1 winners and finalists, each playing the draft from its final.
- **The sim** is 2d6 dice: three lanes, then teamfights, pickoffs and Roshan, with fight winners rolling for buildings.

All rules and formulas: [game_outline.md §4–6](../project/game_outline.md).

## 8. Where the project stands

- **Done:** design, data pull (everything except Liquipedia), draft schema, ETL and queries, audit, coursework map, proposal, build plan.
- **Not started:** game code. The SQL hasn't been run on a real MySQL server yet; that's the first build step (M1 in [build_plan.md](../project/build_plan.md)).
- **Waiting on you:** the 27 open questions (each has a default), running the Liquipedia script, and hand-checking the alias, org and hero-trait tables.

## 9. Glossary

| Term | Meaning here |
|---|---|
| Era card | One card per player per time window, with its own rating, roles and heroes. The name is just the player's name; era years and orgs go in a description line |
| Main / alternate role | A card's most-played position / positions with ≥ 15% of its matches or another card's main role (stored in `card_position.role_kind`) |
| Pack | One org's offer during the draft: up to 5 player cards and 5 random heroes |
| Pool roster | A real tier-1 winner or finalist lineup that can appear as an AI opponent |
| Alias table | The `account.player_id` link that merges a person's several Steam accounts |
| Org | A real organisation grouping several OpenDota team ids across rebrands |
| Staging table | A `stg_*` table that holds raw CSV rows before cleaning |
| Layer A / B / C | Reference data / derived summaries / game state |
| ETL | Extract, transform, load: the SQL that turns raw rows into cards, ratings and chemistry |
| Seed | The stored random number that makes each game replay identically |
