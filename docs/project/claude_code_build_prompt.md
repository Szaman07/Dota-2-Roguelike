# Claude Code build prompt

_2026-10-11, updated 2026-10-12 for the new title, main and alternate roles and the exact 5+5 draft. A shorter context-only version is [claude_code_context_prompt.md](claude_code_context_prompt.md). Paste everything below the line into Claude Code, started at the root of the project folder (`E:\study\Projects\311(dota)` or the `Dota-2-Roguelike` repo checkout). It assumes the current layout (`docs/`, `data/`). It builds in milestones and stops at each checkpoint so you can look before it continues._

---

You are building **"A Dice-Based Tournament Roguelike Deck Builder"** (built on Dota 2 pro data; older docs call it "A Roguelike Deck Builder based on Dota 2"), a CSE311 (Database Systems, North South University) course project, in **PHP 8 + MySQL 8.0+**. The whole design, schema drafts and data are already in this folder. No game code exists yet. Your job is to build as much of the working game as you can, milestone by milestone, keeping the SQL visible because the database is what gets graded.

## 0. Read first (in this order) before writing any code

1. `docs/project/README.md` (index of the project pack)
2. `docs/project/proposal.md` (updated 2026-10-12: the plain-language version of the current rules)
3. `docs/research/game_design.md` (rev 6, the settled design; it wins over older research docs, but the 2026-10-12 changes in the project docs win over it)
4. `docs/project/game_outline.md` (run flow, the 12 screens with their DB reads and writes, every rule and formula)
5. `docs/project/open_questions.md` (28 open points, each with a default)
6. `docs/project/build_plan.md` (milestones, environment, smell tests, testing checklist)
7. `docs/project/schema/schema_draft.sql`, `etl_draft.sql`, `queries_draft.sql`, `er_diagram.md`
8. `docs/project/dbms_coursework_map.md` (what the course needs to see: constraints, transactions, window functions, procedures, views, indexes, least-privilege users)
9. `data/README.md` (what every data file is, row counts, known quirks)
10. `docs/project/audit.md` §2.3 (data quirks) and §3 (where the effort is)

Then create a `CLAUDE.md` at the root summarising the stack, layout, conventions and the rules in §2 below, so later sessions follow them.

## 1. Ground rules (do not break these)

- **Design decisions belong to me (Sadman).** Implement the design as written. Where something is open, use the documented default from `open_questions.md` and don't invent new mechanics. If the docs genuinely conflict or leave a gap you can't fill with a default, pick the simplest option, put it in config, and log it in `docs/project/build_log.md` under "Decisions for Sadman". Never silently change a rule.
- **Every open-question default and every KNOB is a config value**, in one file (`config/game.php`, plus the `@knob` user variables at the top of the ETL SQL), so I can change them without touching code.
- **Changes from 2026-10-12 that override older docs:** (a) every player card has a **main role** plus **alternate roles** from real pro data (a position is alternate if it's ≥ 15% of the card's matches or the main role of another card of the same player); main and alternate roles carry no penalty, any other role gets the experience-scaled off-role penalty. (b) The initial draft must end with **exactly 5 players and 5 heroes**: once you hold 5 of one kind, later packs only offer the other kind. (c) Chemistry is counted by **matches played together** (same match, same side, through the alias table). If you find an older doc that disagrees, follow these and note it in the build log.
- **Card and roster names carry no years.** A card's name is just the player's name ("Ceb"); era years and orgs go in a description field ("2016–2019 · OG"). Same for pool rosters ("Team Liquid", description "TI 2017 champions · Miracle-, MinD_ContRoL, ...").
- **No network calls at play time**, and no new data pulls. Everything comes from `data/`. Do **not** run `data/scripts/pull_liquipedia.py` (Liquipedia's robots.txt disallows Claude's agents; I run it myself). Do not edit anything under `data/raw/`.
- **SQL stays visible.** Plain PDO with prepared statements and named parameters. No ORM, no query builder, no framework. Put non-trivial queries in `.sql` files or clearly named repository functions, so I can show them in the report. Prefer doing work in MySQL (views, window functions, CTEs, procedures, constraints) where the docs say so; PHP does the dice sim, hero-assignment permutations and rendering.
- **The database enforces integrity, not just PHP.** Every rule in the build plan's "Constraints" checklist (two pos-1 players, two cards of one player, a bench of 6, a pack option with both a card and a hero, a dice roll of 13) must be rejected by MySQL itself.
- **Determinism.** Every random choice (pack contents, AI draft game, dice) comes from a seeded RNG derived from `run.seed` plus a stable key (pack number, game id...), so a reload never rerolls anything and the same seed replays the same game.
- **Licences and credits:** credit OpenDota, Liquipedia (CC-BY-SA), Dota 2 Wiki (CC-BY-SA), odota/dotaconstants (MIT) and Valve's fan-content notice on a Credits screen. No Valve artwork; text and CSS only (hero names, no portraits, unless I add assets later).
- **Keep a build log.** `docs/project/build_log.md`: per milestone, what was built, schema changes you made to the drafts and why, test results, row counts, and open items for me.
- **Git:** commit at the end of each milestone with a clear message. Don't push and don't rewrite history unless I ask.

## 2. Stack and layout

- **PHP 8.1+** with `pdo_mysql`, `zlib` and `mbstring`. No Composer dependencies are required; if you want PHPUnit, ask first. Run with PHP's built-in server for development: `php -S localhost:8000 -t public`.
- **MySQL 8.0.16+** (CHECK constraints enforced, window functions, CTEs). Before anything else, run `mysql --version` (or `SELECT VERSION()`). **If it reports MariaDB** (XAMPP ships MariaDB), stop and tell me: the schema relies on MySQL 8 behaviour, and I'll install MySQL 8 Community Server or switch my local stack.
- **Front end:** server-rendered PHP templates, one CSS file, small vanilla JS only where it helps (replay playback, drag/drop or click-to-swap on the team screen). No build step, no npm.
- **This is Windows.** The folder path contains parentheses (`311(dota)`), so quote paths in PowerShell. Use forward slashes in `LOAD DATA LOCAL INFILE` paths.
- **Database names and users** from the drafts: database `ati`; app user `ati_app` (SELECT on everything, write only on game-state tables, EXECUTE on procedures) and ETL user `ati_etl` (all on `ati`), as in `dbms_coursework_map.md`. Read credentials from `config/db.local.php` (git-ignored) with a committed `config/db.example.php`.

Suggested layout (adjust if you have a good reason, and log it):

```
config/          game.php (knobs + defaults), db.example.php, db.local.php (ignored)
sql/             00_schema.sql, 10_staging.sql, 20_load_reference.sql, 30_derive.sql,
                 40_views_procs_triggers.sql, 50_users.sql, queries/*.sql, tests/*.sql
bin/             setup_db.php, load_data.php, build_derived.php, balance.php, smell_test.php, run_tests.php
src/             Db.php, Rng.php, Draft/, Team/, Sim/, Tournament/, Rewards/, Repo/ (query wrappers)
public/          index.php (front controller), assets/app.css, assets/app.js
templates/       one file per screen + layout
tests/           plain PHP test scripts with assert-style checks, run by bin/run_tests.php
docs/project/    build_log.md (new); existing docs stay where they are
```

## 3. Milestones (stop at each CHECKPOINT and summarise)

Follow `build_plan.md`. M0 is done: **use every default in `open_questions.md`** (including #11b: alternate-role threshold 15%; #23: rock-paper-scissors edges removed; #15–16: Bo1 groups, 16 teams in 2 groups of 8, TI winners as top seeds).

### M1. Database up
- Turn `schema_draft.sql` into `sql/00_schema.sql`. It has only been syntax-checked, never run on a real MySQL, so expect fixes. Run it on a fresh `ati` database, fix every error, and keep fixes minimal (log each one).
- Add the views, `sp_finish_series`, and the triggers the docs mention (for example: refuse a draft pick when `run.status <> 'drafting'`). Create the two users.
- `bin/setup_db.php --fresh` drops and recreates everything idempotently.
- Write `sql/tests/constraints.sql` (or a PHP test) that tries each bad insert from the build plan checklist and confirms MySQL rejects it.
- **CHECKPOINT:** schema runs clean, table count, constraint tests pass.

### M2. Data loaded
- `bin/load_data.php`: for each `.csv.gz` under `data/raw/opendota/` (180 match slices, 180 player-match slices, leagues, teams, notable players, heroes), decompress to a temp folder and `LOAD DATA LOCAL INFILE` into staging tables (needs `PDO::MYSQL_ATTR_LOCAL_INFILE => true` and `local_infile=1` on the server; if that can't be enabled, fall back to batched multi-row INSERTs and say so). Check the real CSV headers with a quick peek before writing column lists; the ETL draft's column lists are guesses.
- Load `data/raw/dotaconstants/*.json`, `data/raw/wiki/mechanic_sources.csv` and every file in `data/processed/` into their staging or seed tables.
- Fill layer A from staging with `sql/20_load_reference.sql` (follow `etl_draft.sql` steps 1–2). Keep only referenced leagues (#26).
- **Tier-1 list and placements:** `data/raw/liquipedia/` is empty right now. Use the fallback (`tier1_leagues_candidates.csv`, `placements_derived.csv`, `finals_derived.csv`, `pool_rosters_derived.csv`), and write the loader so that when I drop Liquipedia's CSVs into `data/raw/liquipedia/` later, re-running the build uses them instead. Document the switch in the build log.
- **CHECKPOINT:** row counts per table versus `data/README.md` (226,846 matches; 2,268,452 player rows; 127 heroes; and so on), load time.

### M3. Seed tables (first pass, marked for my review)
These are hand tables in the design. Build a usable first pass so the game runs, and mark every row you didn't take straight from data as `unverified` (add a status/source column where the draft lacks one):
- **Alias table:** from `player_alias_candidates.csv`. Use OpenDota names where present; for the top ~150 accounts by tier-1 games, group multiple accounts of one player (Arteezy, Nisha, Zai, Yatoro are known cases) and fill obvious unnamed stars from their teams and dates where you're confident. Anything you're unsure of stays unnamed and out of the card pool. Write the top 150 to `data/review/alias_review.csv` for me to check.
- **Org table:** group OpenDota team ids into orgs across rebrands (remember team names are *today's* names: EG's id shows as "Shopify Rebellion"). Cover every org that has a pool roster or would get a pack. Write `data/review/org_review.csv`.
- **Hero traits:** load `hero_traits_prefill.csv`. `teamfight_ult` and `save` have no data source; fill a first pass from game knowledge, marked `unverified`, and write `data/review/hero_traits_review.csv`.
- **CHECKPOINT:** list what's unverified and how many rows, so my teammate and I can split the review.

### M4. Derived layer
- Port `etl_draft.sql` steps 3–5 into `sql/30_derive.sql`: estimated positions (window functions; pre-2016 by GPM rank, marked estimated), main and alternate roles per card (`card_position.role_kind`: main / alt / off, alt = ≥ 15% of the card's matches or another card's main role), era cards (window = max(3 years, career/3), max 3 cards, short tail merges), card stats, rating (win rate shrunk with k = 50, peak rolling-100 win rate, consistency = half steadiness + half longevity, best-5 placement points; weights 30/25/15/30; curve `68 + 31 × percentile^1.3`), minimum 150 games per card, card_hero mastery, card_position, card_org, chemistry pairs, hero position shares, counters and lane matchups since 2024 shrunk toward neutral, hero phase stats, pool rosters with their real final games.
- Use `EXPLAIN ANALYZE` on the heavy statements (chemistry self-join, counters) and add or adjust composite indexes. Record before/after timings in the build log: it's report material.
- `bin/smell_test.php` prints the build plan's rating smell tests: the "one-off winner ranks below a steady 3rd-place finisher" rule, prototype anchors (Ceb ≈ 95 then 83, Puppey ≈ 98 then 84, Miracle- prime ≈ 99), no legend below ~85 on their prime card, median card near 80, plus the distribution of ratings and cards per player. Don't tune weights to force a pass: report what fails and which knob would move it.
- **CHECKPOINT:** card count, rating distribution, smell test output, top 20 cards with descriptions.

### M5. Draft playable
Screens 1–4 from `game_outline.md` §5: Home, Settings (difficulty = rerolls 0/1/2, hero allocation auto/manual, seed), Draft (org packs: 5 players with ≥ 30 games for the org as the era card covering that time + 5 random heroes; one pick per pack; 10 picks ending with exactly 5 players and 5 heroes, so once one kind is full only the other kind can be taken; rerolls; disabled options per the rules; a drafted player goes to their main role if open, then an open alternate role, then any open slot), Team (roles with main/alternate tags, heroes, mastery, hero-position fit tags, chemistry groups from matches played together, team scores, off-role penalty only outside main and alternate roles, bench).
- Every write happens in a transaction with the run row locked (`SELECT … FOR UPDATE`); UNIQUE keys make double clicks and two tabs harmless.
- Runs are tied to a browser session token; no accounts.
- Automatic hero allocation tries all 120 assignments and keeps the best total modifier.
- **CHECKPOINT:** I can draft a full team in the browser.

### M6. First slice: one group + short bracket
- `src/Sim/`: the fight-based 2d6 sim exactly as in `game_design.md` §4 and `game_outline.md` §6.4–6.5 (three lane head-to-heads with draw zones and 50/25/25 weights; later rounds are Roshan / teamfight ~57% / pickoff ~43%; solo building rolls T1 → T2 → T3 → Barracks → Ancient; Aegis; comeback bonus; early scores rounds 1–5, scaling from round 10). All modifiers and probabilities come from `config/game.php`. The sim writes `game_event` rows; the replay screen only reads them.
- Insert the `game` row with its seed **before** simulating; a refresh mid-game must show the same result, never a reroll.
- Screens 5–8: group table (`v_group_standings`), pre-game (opponent roster and the real final draft it will play, shown before the game), replay (skippable), reward pick (loss = 2 picks, win = 1; 5-slot bench; a passed pick is gone).
- Build the field: 15 pool rosters, no two sharing 3+ players, TI winners as top seeds split across groups, you snake-seeded by team rating. Simulate the other teams' group games too.
- **CHECKPOINT:** a run you can finish end to end (one group plus a short bracket is enough here).

### M7. Full TI
- 2 × 8 Bo1 groups, tiebreakers (wins → head-to-head → seeded coin flip), places 1–4 to the upper bracket, 5–6 to the lower bracket, 7–8 out.
- Full double elimination from `game_outline.md` §6.6 (18 series; UB Bo3, LB R1 Bo1 then Bo3, GF Bo5, no bracket reset). `series` rows point to where winner and loser go; `sp_finish_series` advances the bracket inside a transaction.
- Rewards: UB series win = 1 variant upgrade (screen 9; becomes 1 pick if no owned player has another card), the one UB series loss = 2 picks (wherever it happens, including the UB final), LB series win = 1 pick.
- Screens 10–12: bracket (your path highlighted; a recursive CTE for the path is good report material), result (final place, record, roster, badges, run seed, PNG download via canvas), Browse (cards, orgs, pool rosters, hero stats; read-only queries).
- **CHECKPOINT:** a full TI run in the browser.

### M8. Balance script
- `bin/balance.php`: auto-draft and play thousands of runs headless with fixed seeds; report game length, laning-winner win rate, rating-gap win rates, badly built team win rate, style matchups, run win rate for an average team, and the reward/tanking question the audit flags (does throwing UB round 1 for 2 picks pay off?).
- Compare against the prototype targets in `game_design.md` §4 (median ~13 fights, laning winner ~66%, +5 rating ~62%, badly built team ~13%, no style above ~53%). Report the numbers and suggested knob changes; **don't change knobs without telling me**.

### M9. Report material (not the report itself)
- Make sure `docs/project/build_log.md` has: final DDL table list, FDs and normalization notes where you changed the schema, the 10–15 key queries with file locations, `EXPLAIN` before/after, transaction and concurrency tests with results, ETL row-count checks, balance numbers. I'll write the report from it, following `dbms_coursework_map.md` §4.

## 4. Testing (run `php bin/run_tests.php` before every commit)

- Constraint tests (MySQL rejects each bad insert from the build plan).
- Concurrency: two simultaneous picks on one run, double "Play", refresh mid-game; exactly one result each time.
- ETL totals: player rows per year and games per hero match the raw CSV counts.
- Sim: same seed → identical event log; even teams ≈ 50% over many games; badly built team wins rarely.
- Draft: every pack and AI draft is reproducible from the seed.

## 5. When you finish (or get stuck)

Stop and summarise for me: what works (with how to run it), what's stubbed, test results, every place you used a default or made a call that's mine to confirm, the review files under `data/review/`, and the next steps. If something blocks you (MySQL version, `local_infile`, a doc contradiction), say exactly what and keep building the parts that don't depend on it.
