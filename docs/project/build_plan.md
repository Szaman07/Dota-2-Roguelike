# Build plan (for when you decide to build)

_Draft, 2026-10-11. A suggested order and split for two people. Nothing here is started; who does what is your call._

## Milestones

| # | Milestone | Done when | Depends on |
|---|---|---|---|
| M0 | **Decisions** | [open_questions.md](open_questions.md) answered (or "defaults") | — |
| M1 | **Database up** | `schema_draft.sql` reviewed, edited and runs clean on MySQL 8 on both laptops | M0 |
| M2 | **Data loaded** | Raw CSVs in staging; layer A filled; row counts match [data/README.md](../../data/README.md) | M1 |
| M3 | **Seed tables checked** | Alias table (top ~150 players), org table, tier-1 list + placements (Liquipedia), hero traits all hand-checked | M2 |
| M4 | **Derived layer** | `etl_draft.sql` runs; cards and ratings pass the smell test (named spot checks below) | M3 |
| M5 | **Draft playable** | Home → settings → 10 picks → team screen, with live ratings, mastery, chemistry, scores | M4 |
| M6 | **One group + short bracket** (first slice, from game_design.md) | A run you can finish end to end | M5 |
| M7 | **Full TI** | 2×8 groups, full double elimination, rewards (picks, 2-pick UB drop, upgrades), replays, result card | M6 |
| M8 | **Balance** | Batch script plays thousands of auto-drafted runs; knobs set so odds match the targets | M7 |
| M9 | **Report + demo** | Report chapters per [dbms_coursework_map.md](dbms_coursework_map.md) §4, demo rehearsed | M7 |

## Suggested split
Both of you are Immortal players, so either can own the Dota-heavy parts. One natural split, following the "teammate owns matchups" idea from earlier:

| Person A (database + platform) | Person B (Dota model + sim) |
|---|---|
| M1 schema, M2 load, ETL SQL, indexes, `EXPLAIN` work | Hero traits check (M3), lane/counter overrides |
| Alias + org tables (M3) | Dice sim in PHP: laning, fights, Roshan, buildings |
| Run lifecycle: transactions, locking, bracket procedure | Team scores (teamfight, pickoff, early/late) |
| Draft, team and bracket screens | Pre-game and replay screens |
| Report chapters 2–8 | Balance script (M8), report chapters 9–10 |

## Rating smell test (M4)
Before trusting the ratings, check named cases against what you both know:
- Your 22:07 rule: a one-off tier-1 winner who then missed the next tier-1 events or retired must rate **below** a player who kept finishing 3rd (your example: Arteezy).
- Prototype anchors from the research: Ceb 2016–19 ≈ 95 and 2020–23 ≈ 83; Puppey prime ≈ 98, late ≈ 84; Miracle- 2016–18 ≈ 99.
- No legend below ~85 on their prime card; a median card near 80.
If those fail, adjust the curve first, then the longevity half of consistency, then weights.

## Testing checklist
- **Constraints:** two pos-1 players, two cards of one player, a bench of 6, a pack option with both a card and a hero, a dice roll of 13: each must be rejected by MySQL, not just PHP.
- **Concurrency:** two tabs pick at once; double-click "Play"; refresh mid-game. Only one result may exist.
- **ETL totals:** player rows per year and games per hero match the raw CSV counts.
- **Sim:** same seed → same game; badly built team wins rarely; even teams ~50%.

## Environment
- PHP 8.x with PDO MySQL, MySQL 8.0.16+ (CHECK constraints enforced), `local_infile` enabled for the CSV load.
- Python 3 + `requests` + `pandas` only for re-running the data scripts (not needed to play).
- Data size on disk: see [data/README.md](../../data/README.md).
