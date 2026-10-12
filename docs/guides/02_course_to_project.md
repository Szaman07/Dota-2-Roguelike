# Course to project: where each CSE311 topic shows up in the game

_Written 2026-10-11. Every example uses the project's real tables and real data. **The schema is a draft:** table and column names follow [schema_draft.sql](../project/schema/schema_draft.sql), [etl_draft.sql](../project/schema/etl_draft.sql) and [queries_draft.sql](../project/schema/queries_draft.sql) as they stand today, none of it has run on MySQL yet, and Sadman makes the final design calls. Theory for each topic: [01_theory_guide.md](01_theory_guide.md). The official NSU objective-by-objective map, lab exercises and report outline are in [dbms_coursework_map.md](../project/dbms_coursework_map.md)._

**Contents**
1. [Quick map: topic → where it lives](#1-quick-map)
2. [ER modeling on our entities](#2-er-modeling-on-our-entities)
3. [Keys in our schema](#3-keys-in-our-schema)
4. [Normalization on our real data (1NF to BCNF)](#4-normalization-on-our-real-data)
5. [Database reads and writes: who reads what, who writes what](#5-database-reads-and-writes)
6. [More than one database: raw import next to the game](#6-more-than-one-database-raw-import-next-to-the-game)
7. [How tables link together (and how sources link)](#7-how-tables-link-together)
8. [Joins, subqueries, CTEs and window functions on our tables](#8-joins-subqueries-ctes-and-window-functions)
9. [Relational algebra for three real queries](#9-relational-algebra-for-three-real-queries)
10. [Views](#10-views)
11. [Transactions and ACID in a run](#11-transactions-and-acid-in-a-run)
12. [Concurrency: double clicks and two tabs](#12-concurrency-double-clicks-and-two-tabs)
13. [Indexing and EXPLAIN on 2.3 million rows](#13-indexing-and-explain)
14. [Stored procedures and triggers](#14-stored-procedures-and-triggers)
15. [Security and integrity](#15-security-and-integrity)
16. [Using this in the report and demo](#16-using-this-in-the-report-and-demo)

---

## 1. Quick map

| Course topic | Where it lives in this project |
|---|---|
| Database vs files | ~440 raw CSV/JSON files → one MySQL database with constraints |
| ER model | 42 entities; [er_diagram.md](../project/schema/er_diagram.md) |
| Keys | natural Steam/OpenDota ids, surrogate ids for our own concepts, composite keys, a composite FK |
| Normalization | multi-valued team lists, OpenDota arrays, team names copied on every row, the card/player BCNF case |
| SQL reads | packs, team screen, standings, bracket, ratings |
| SQL writes | bulk load (layer A), rebuild (layer B), per-click game state (layer C) |
| Joins | the alias chain account → player, chemistry self-join, counters across sides |
| Views | `v_card`, `v_group_standings` |
| Window functions, CTEs | ratings (`PERCENT_RANK`), estimated positions (`ROW_NUMBER`), rolling peak, recursive bracket path |
| Transactions | picking a card, recording a game, finishing a series |
| Concurrency | `SELECT … FOR UPDATE`, UNIQUE keys as guards, `version` column |
| Indexing | `(account_id, match_id)`, `(hero_id, match_id)`, `(league_id, start_time)` |
| Procedures, triggers | `sp_finish_series`; a "draft is over" trigger |
| Security | `ati_app` vs `ati_etl` users; PDO prepared statements |

---

## 2. ER modeling on our entities

The draft has three groups of entities (full diagram: [er_diagram.md](../project/schema/er_diagram.md)):

- **Reference (layer A):** hero, ability, mechanic, patch, league, tournament, team, org, player, account, placement, pro_match, match_player.
- **Derived (layer B):** player_card, card_position, card_hero, card_org, player_pair, hero_position_share, hero_matchup, lane_matchup, pool_roster, pool_roster_player, pool_roster_game.
- **Game state (layer C):** run, run_pack, run_pack_option, run_card, run_team, series, game, game_lineup, game_event, run_upgrade.

Every ER concept from the course has a real example:

| ER concept | Our example | How it became tables |
|---|---|---|
| **1:1** | hero ↔ hero_trait (one curated trait row per hero) | `hero_trait.hero_id` is both PK and FK |
| **1:N** | pro_match → match_player (a match has 10 player rows) | FK `match_player.match_id` |
| **M:N** | ability ↔ mechanic (Lion's Earth Spike stuns; many abilities stun) | bridge table `ability_mechanic(ability_id, mechanic_id)` |
| **M:N with attributes** | tournament ↔ league (an event spans several OpenDota leagues), with `mapped_by` | bridge `tournament_league` carrying `mapped_by` |
| **Multi-valued attribute** | a hero's Valve role tags (Carry, Nuker, Disabler) | separate table `hero_role_tag(hero_id, tag)` |
| **Weak entity** | card_position: "games at pos 3" only exists for a card | PK `(card_id, pos)`, FK to `player_card` |
| **Recursive relationship** | a playoff series sends its winner and loser to other series | self-FKs `series.next_win_series`, `series.next_lose_series` |
| **Specialization (ISA)** | a run card is either a player card or a hero card | one table `run_card` with `kind`, and a `CHECK` that the right columns are filled |
| **Derived attribute** | a card's win rate | not stored; `v_card` computes `wins / games` |
| **Total participation** | every match_player row must belong to a match | `match_id NOT NULL` + FK |
| **Partial participation** | many accounts are not card players | `account.player_id` is nullable |

---

## 3. Keys in our schema

| Key type | Our example | Why |
|---|---|---|
| **Natural key** | `hero.hero_id`, `pro_match.match_id`, `account.account_id`, `league.league_id` | Valve/OpenDota ids are stable and come with the data |
| **Surrogate key** | `player.player_id`, `player_card.card_id`, `org.org_id`, `run.run_id` | No source owns "a person" or "an org", so we invent the id |
| **Composite PK** | `match_player (match_id, player_slot)`, `card_hero (card_id, hero_id)` | The row is identified by the pair |
| **Alternate (candidate) key** | `hero.name UNIQUE`, `player_card UNIQUE (player_id, card_index)` | Second way to identify a row, enforced |
| **Foreign key** | `match_player.hero_id → hero.hero_id` | Referential integrity |
| **Composite foreign key** | `run_card (card_id, player_id) → player_card (card_id, player_id)` | Keeps a copied column honest (§4.5) |
| **Self-referencing FK** | `series.next_win_series → series.series_id` | The bracket |

A trick worth showing in the report: **"exactly one human team per run"** with a UNIQUE key and NULLs.

```sql
-- run_team (draft): player_flag is 1 for the human team and NULL for the 15 AI teams.
player_flag TINYINT AS (CASE WHEN is_player THEN 1 END) STORED,
UNIQUE KEY uq_one_player_team (run_id, player_flag)     -- NULLs never collide, so only one row can hold 1
```

---

## 4. Normalization on our real data

The raw data the project pulled breaks every normal form somewhere. Each case below is real.

### 4.1 1NF: lists inside one value

**Case A: the alias candidates file.** A real row of `data/processed/player_alias_candidates.csv`:

```
account_id,suggested_player,...,main_teams
25907144,Cr1t-,...,Shopify Rebellion (1270); Team Falcons (889); OG (202)
```

`main_teams` holds a list (three teams with game counts) in one value. That breaks 1NF: you can't ask "who played for OG?" with `=`, and you can't put an FK on it.
**Fix in the schema:** the list never becomes a column. The same facts come from rows: each `match_player` row links to a `pro_match` with a team id, and `card_org(card_id, org_id, games)` stores one org per row.

**Case B: OpenDota arrays.** OpenDota stores gold per minute as an array (`gold_t = [0, 180, 410, ...]`). The draft keeps only the value at 10 minutes as a scalar column, `match_player.gold_10`.

**Case C: role tags.** Valve gives a hero's roles as a list (`["Carry","Escape","Nuker"]`). The draft stores one row per tag in `hero_role_tag(hero_id, tag)`.

### 4.2 2NF: a column that depends on half the key

The raw player-row CSV is keyed by `(match_id, player_slot)`. Suppose we had kept the match's start time and league on each player row:

`match_player_wide(match_id, player_slot, account_id, hero_id, start_time, league_id, duration)`

FDs: `(match_id, player_slot) → account_id, hero_id` and **`match_id → start_time, league_id, duration`**. The second is a **partial dependency** (it needs only half the key), so the table is in 1NF but not 2NF. Each match's start time would be stored 10 times.
**Fix:** move the match-level columns to `pro_match(match_id, start_time, league_id, duration_s, ...)`. That's exactly the draft's split.

### 4.3 3NF: one non-key column determining another

A real row of OpenDota's `notable_players.csv.gz`:

```
account_id,name,country_code,fantasy_role,team_id,team_name,team_tag,...
161595677,N1NJA,,2,7626304,SAND KING GÓMEZ,SKG,...
```

FDs: `account_id → team_id` and **`team_id → team_name, team_tag`**. So `account_id → team_name` is **transitive** through a non-key column. If a team renames, every account row must change (update anomaly), and a team with no notable players can't be stored (insertion anomaly).
**Fix:** `team(team_id, name, tag)` holds the name once; the account side keeps only the id.

The same thing happens one level up: OpenDota shows **today's** team names (EG's old id now says "Shopify Rebellion"). Grouping team ids into real orgs is another transitive chain (`team_id → org_id → org name`), so the draft has `org_team(team_id, org_id)` and `org(org_id, name)`, not an org name on every team row.

### 4.4 BCNF: the card/player case (3NF but not BCNF)

This is the best textbook example in the project, and it's a real design choice.

`pool_roster_player(roster_id, pos, player_id, card_id)`: the five players of an AI roster, each shown as one of their era cards.

- Candidate keys: **(roster_id, pos)** (one player per position) and **(roster_id, player_id)** (a player appears once in a roster).
- FD: **`card_id → player_id`** (a card belongs to exactly one player).

`card_id` is not a superkey of this table, so `card_id → player_id` **breaks BCNF**. But `player_id` is part of a candidate key (it's *prime*), so the table **is in 3NF**.

Decomposing to BCNF would mean dropping `player_id` here (it can be found from `player_card`). Then `UNIQUE (roster_id, player_id)` could no longer be checked inside one table: you'd lose **dependency preservation**. The draft keeps `player_id` and protects the copy with a **composite foreign key**:

```sql
FOREIGN KEY (card_id, player_id) REFERENCES player_card (card_id, player_id)
```

The FK refuses any row where the copied `player_id` doesn't match the card's real player, so the redundancy can never go wrong. `run_card` uses the same pattern so `UNIQUE (run_id, player_id)` can stop you from owning two cards of the same player.

### 4.5 FD lists for a few draft tables

| Table | Key | Non-trivial FDs | Normal form |
|---|---|---|---|
| `hero` | hero_id (also name, code_name) | hero_id → everything; name → hero_id | BCNF (every left side is a key) |
| `match_player` | (match_id, player_slot) | key → account_id, hero_id, lane, gpm, ...; player_slot → is_radiant | `player_slot → is_radiant` has a non-key left side. It's a **generated column**, so it can't drift; documented as harmless |
| `account` | account_id | account_id → player_id, od_name, alias_status | BCNF |
| `player_card` | card_id; (player_id, card_index) | either key → everything | BCNF |
| `card_position` | (card_id, pos) | key → games, wins, role_kind | BCNF inside the table, but `role_kind` is computed from `games` and from other cards of the same player, so it's derived data: layer B, rebuilt by the ETL, never edited by the game |
| `placement` | (tournament_id, team_label) | key → place_from, place_to, org_id, source | BCNF |
| `pool_roster_player` | (roster_id, pos); (roster_id, player_id) | card_id → player_id | 3NF, not BCNF (on purpose, §4.4) |

### 4.6 Layer B: redundancy on purpose

`player_card.games`, `card_hero.games`, `player_pair.games` and the matchup tables are all **aggregates of `match_player`**. Storing them is redundant by definition. The draft justifies it the way the course asks you to:
- Computing a player's ratings or chemistry from 2.3 million rows on every click would be slow.
- The game **never edits** layer B. One script ([etl_draft.sql](../project/schema/etl_draft.sql)) rebuilds it from layer A, so it can't drift.
- It works like a **materialized view**, which MySQL doesn't have.

---

## 5. Database reads and writes

The three layers have completely different read/write patterns. That's a good point for the report.

| Layer | Written by | How often | Kind of write | Read by |
|---|---|---|---|---|
| Staging (`stg_*`) | load script | once per data refresh | bulk `LOAD DATA` | ETL |
| A. Reference | ETL step 2 | once per refresh | bulk `INSERT … SELECT` | ETL, browse screen, chemistry query |
| B. Derived | ETL steps 3–5 | once per refresh (after hand tables change) | `TRUNCATE` + `INSERT … SELECT` with joins, window functions | every game screen |
| C. Game state | PHP game | every click | small single-row `INSERT` / `UPDATE` inside transactions | game screens |

Layers A and B are **read-mostly** (analytics, like a data warehouse). Layer C is **OLTP** (many tiny writes that must be correct under concurrency).

### 5.1 Reads and writes per screen (from [game_outline.md §5](../project/game_outline.md))

| Screen | Reads | Writes |
|---|---|---|
| Home | `run` by session token | none |
| Settings | none | `INSERT run` |
| Draft | `card_org`, `player_card`, `hero` | `INSERT run_pack`, `run_pack_option`, `run_card`; `UPDATE run.rerolls_left` |
| Team | `card_hero`, `match_player` + `account` (chemistry), `hero_position_share`, `hero_trait` | `UPDATE run_card` slots |
| Group table | `v_group_standings` | none |
| Pre-game | `pool_roster_game` → `match_player` (the AI draft) | `INSERT game` (seed first) |
| Replay | `game_event` | none (the sim wrote them) |
| Reward / Upgrade | packs as in the draft; other cards of a player | `INSERT run_card` / `UPDATE run_card.card_id`, `INSERT run_upgrade` |
| Bracket | `series` | via `sp_finish_series` |
| Result | `run`, `series`, `game` | `UPDATE run SET status = 'finished'` |

### 5.2 A read: drawing a pack (draft, from queries_draft.sql §1)

```sql
-- 5 random players of one org, each shown as one of their era cards that played 30+ games there
SELECT card_id, player_id FROM (
    SELECT c.card_id, c.player_id,
           ROW_NUMBER() OVER (PARTITION BY c.player_id ORDER BY RAND(:seed_a)) AS pick_card,
           RAND(:seed_b) AS r
    FROM card_org co JOIN player_card c USING (card_id)
    WHERE co.org_id = :org_id AND co.games >= 30
) t WHERE pick_card = 1 ORDER BY r LIMIT 5;
```

The seed comes from `run.seed + pack_no`, so refreshing the page shows the same pack.

### 5.3 A write: taking a card (one transaction)

```sql
START TRANSACTION;
SELECT status, rerolls_left FROM run WHERE run_id = :run FOR UPDATE;     -- lock the run row
UPDATE run_pack SET status = 'picked', picked_option = :opt
 WHERE pack_id = :pack AND status = 'open';                              -- 0 rows = already picked
INSERT INTO run_card (run_id, kind, card_id, player_id, location, slot, from_pack_id)
VALUES (:run, 'player', :card, :player, 'active', :slot, :pack);         -- UNIQUE keys refuse a 2nd pos-1
COMMIT;
```

If any statement fails (a duplicate player, a taken slot), PHP calls `ROLLBACK` and nothing changes.

### 5.4 A bulk write: loading and cleaning in one statement (from etl_draft.sql §2)

```sql
INSERT INTO match_player (match_id, player_slot, account_id, hero_id, ...)
SELECT match_id, player_slot, NULLIF(account_id, 4294967295), hero_id, ...   -- Valve's "anonymous" id → NULL
FROM stg_player_match;
```

---

## 6. More than one database: raw import next to the game

**What the draft does today:** everything lives in **one database, `ati`**, and the staging tables sit inside it with a `stg_` prefix.

**The option to consider:** split it into two databases on the same MySQL server.

| Database | Holds | Lifecycle |
|---|---|---|
| `ati_raw` (import) | `stg_match`, `stg_player_match`, `stg_team`, `stg_notable`, `stg_alias`, ... exactly the CSV columns, no constraints | Dropped and reloaded whenever data is pulled again |
| `ati` (game) | layers A, B, C with all keys and constraints | Long-lived; the PHP game connects here |

Cross-database queries in MySQL are just qualified names, on one connection:

```sql
-- ETL step 2, reading from the import database and writing into the game database
INSERT INTO ati.pro_match (match_id, league_id, start_time, duration_s, radiant_win, ...)
SELECT match_id, leagueid, FROM_UNIXTIME(start_time), duration, radiant_win = 'True', ...
FROM ati_raw.stg_match;

-- Spot-check the load: raw rows vs loaded rows
SELECT (SELECT COUNT(*) FROM ati_raw.stg_player_match) AS raw_rows,
       (SELECT COUNT(*) FROM ati.match_player)        AS loaded_rows;
```

Why the split helps (good report material on "data independence" and "security"):
- **Re-import without risk:** `DROP DATABASE ati_raw` can never touch a game table.
- **Least privilege:** the game user gets no access to `ati_raw` at all; only the ETL user does.
- **Smaller backups:** back up `ati` (the valuable part); raw CSVs are already on disk.
- **Clear boundary:** dirty data (empty strings, Valve's anonymous id, `'True'`/`'False'` text) stays on one side; clean typed data on the other.

Things to know:
- InnoDB **allows foreign keys across databases on the same server**, but don't point game tables at staging tables: staging gets dropped.
- A **transaction can span both databases** on one server (both InnoDB).
- A third database, for example `ati_test` for the balance script's thousands of simulated runs, would keep test runs out of the real `run` table. Not in the draft; just an option.

Whether to split is Sadman's call (it's a small change: two `CREATE DATABASE` lines and qualified names in the ETL). The rest of this guide uses the one-database draft.

---

## 7. How tables link together

### 7.1 The backbone: from a game row to a person, a card and an org

```
match_player ──account_id──► account ──player_id──► player ──► player_card ──► card_org ──► org
     │                                                           │                         ▲
     │                                                           └──► card_hero ──► hero   │
     └──match_id──► pro_match ──league_id──► league ◄── tournament_league ──► tournament   │
                         │                                                      │          │
                         └──radiant_team_id / dire_team_id──► team ──► org_team ┘──────────┘
                                                                         placement ──► org
```

Real question, real join path: **"every game Puppey played for Secret"**:

```sql
SELECT m.match_id, m.start_time, h.name AS hero
FROM player p
JOIN account a       ON a.player_id = p.player_id                 -- all of Puppey's accounts
JOIN match_player mp ON mp.account_id = a.account_id
JOIN pro_match m     ON m.match_id = mp.match_id
JOIN org_team ot     ON ot.team_id = IF(mp.is_radiant, m.radiant_team_id, m.dire_team_id)
JOIN org o           ON o.org_id = ot.org_id
JOIN hero h          ON h.hero_id = mp.hero_id
WHERE p.display_name = 'Puppey' AND o.name = 'Team Secret'
ORDER BY m.start_time;
```

Seven tables, each join following one FK. That's normalization paying off: each fact is stored once, and joins put them back together.

### 7.2 How the four data sources link

Each source has its own ids. The schema links them through bridge tables and our own surrogate keys:

| Link | Problem | Linking table |
|---|---|---|
| OpenDota account ↔ person | one person, several accounts; 2,482 of 3,086 regular accounts unnamed | `account.player_id` (the alias table, hand-checked from `player_alias_candidates.csv`) |
| OpenDota team id ↔ real org | rebrands and duplicates; today's names on old ids | `org_team(team_id, org_id)` |
| OpenDota league ↔ Liquipedia event | one event spans several leagues | `tournament_league(tournament_id, league_id)` |
| Wiki ability ↔ hero | the wiki names abilities by text | `ability.source_name` + `hero_id`, then `ability_mechanic` |
| Liquipedia placement ↔ org | placements name teams as text ("Team Liquid") | `placement.team_label` (as shown) + `placement.org_id` (resolved) |

### 7.3 Links from game state back to reference data

- `run_card.card_id → player_card`, `run_card.hero_id → hero`
- `run_team.roster_id → pool_roster → pool_roster_player → player_card`
- `game.a_roster_game_id → pool_roster_game → pro_match → match_player` (the AI's real draft is **read** from history, never copied)
- `game_lineup (card_id, hero_id)` snapshots who actually played, since the bench can change later

---

## 8. Joins, subqueries, CTEs and window functions

| Technique | Our query | Source |
|---|---|---|
| **Self-join** | Chemistry pairs: `match_player x JOIN match_player y ON same match, same side, different slot` | etl_draft.sql §5 |
| **Self-join, opposite sides** | Counters: `x.is_radiant <> y.is_radiant` | etl_draft.sql §5 |
| **LEFT JOIN** | Mastery matrix: players × heroes with `COALESCE(games, 0)` for heroes never played | queries_draft.sql §3 |
| **CROSS JOIN** | The 5 × 5 player-hero grid for auto allocation | queries_draft.sql §3 |
| **Subquery in IN** | The five drafted players in the chemistry query | queries_draft.sql §2 |
| **GROUP BY … HAVING** | Pairs with 10+ matches together; orgs with 3+ eligible players | etl_draft.sql §5, queries_draft.sql §1 |
| **CTE** | Era windows per player (`career` → `player_window`) | etl_draft.sql §4 |
| **Recursive CTE** | A team's path through the bracket via `next_win_series` | queries_draft.sql §8d |
| **ROW_NUMBER** | Estimated position: rank by GPM within each lane and side | etl_draft.sql §3 |
| **PERCENT_RANK** | Card rating components | etl_draft.sql §4 |
| **Rolling window** | Peak = best 100-game rolling win rate (`ROWS 99 PRECEDING`) | etl_draft.sql §4 |
| **SUM … OVER** | Hero-position share: `n / SUM(n) OVER (PARTITION BY hero_id)` | etl_draft.sql §5 |
| **UPDATE … JOIN with CASE and a correlated EXISTS** | Main / alternate / off role per card position (alt = ≥ 15% of the card's matches, or another card's main role) | etl_draft.sql §4 |
| **RANK** | Group standings | `v_group_standings` |

Main and alternate roles, written as one `UPDATE … JOIN` with a correlated subquery (from etl_draft.sql §4):

```sql
UPDATE card_position cp JOIN player_card c USING (card_id)
SET cp.role_kind = CASE
    WHEN cp.pos = c.primary_pos         THEN 'main'
    WHEN cp.games >= 0.15 * c.games     THEN 'alt'     -- 15%+ of this card's matches
    WHEN EXISTS (SELECT 1 FROM (SELECT player_id, card_id, primary_pos FROM player_card) o
                 WHERE o.player_id = c.player_id AND o.card_id <> c.card_id
                   AND o.primary_pos = cp.pos) THEN 'alt'  -- another card's main role
    ELSE 'off' END;
```

The inner `SELECT … FROM player_card` is wrapped in a derived table because MySQL won't let an `UPDATE` read the table it joins to directly in a subquery.

The chemistry self-join, the heart of the "matches played together" feature:

```sql
INSERT INTO player_pair (player_a, player_b, games)
SELECT a1.player_id, a2.player_id, COUNT(*)
FROM match_player x
JOIN match_player y ON y.match_id = x.match_id
                   AND y.is_radiant = x.is_radiant          -- same team in that game
                   AND y.player_slot <> x.player_slot
JOIN account a1 ON a1.account_id = x.account_id               -- through the alias table,
JOIN account a2 ON a2.account_id = y.account_id               -- so all of Nisha's accounts count
WHERE a1.player_id < a2.player_id                             -- store each pair once (CHECK a < b)
GROUP BY a1.player_id, a2.player_id
HAVING COUNT(*) >= 10;
```

---

## 9. Relational algebra for three real queries

**Melee heroes:** π<sub>name</sub>(σ<sub>attack_type='Melee'</sub>(hero))

**Chemistry pairs** (x, y are renamed copies of match_player):
γ<sub>a1.player_id, a2.player_id; COUNT(*)</sub>( σ<sub>a1.player_id &lt; a2.player_id</sub>( (ρ<sub>x</sub>(match_player) ⋈<sub>x.match_id=y.match_id ∧ x.is_radiant=y.is_radiant ∧ x.slot≠y.slot</sub> ρ<sub>y</sub>(match_player)) ⋈<sub>x.account_id=a1.account_id</sub> ρ<sub>a1</sub>(account) ⋈<sub>y.account_id=a2.account_id</sub> ρ<sub>a2</sub>(account) ) )

**Heroes never picked since 2024** (set difference):
π<sub>hero_id</sub>(hero) − π<sub>hero_id</sub>(σ<sub>start_time ≥ '2024-01-01'</sub>(match_player ⋈ pro_match))

---

## 10. Views

The draft defines two:

```sql
-- v_card: a card with its player's name, a description (era years) and win rate (hides a join and a derived attribute)
CREATE OR REPLACE VIEW v_card AS
SELECT c.card_id, p.player_id, p.display_name,
       CONCAT(YEAR(c.start_date), '–', YEAR(c.end_date)) AS description,   -- years live here, never in the name
       c.rating, c.primary_pos, c.games, ROUND(c.wins / c.games, 3) AS win_rate
FROM player_card c JOIN player p USING (player_id);

-- v_group_standings: wins and losses per team per group, ranked with a window function
```

Both are **read-only views** (they use a join, aggregates or a window function). The group screen reads `v_group_standings` instead of repeating its CTE in PHP.

---

## 11. Transactions and ACID in a run

| Game moment | What must happen together | What breaks without a transaction |
|---|---|---|
| Taking a card | mark the pack picked + insert the card | a crash leaves a picked pack with no card, or a card from an open pack |
| Using a reroll | decrement `rerolls_left` + replace the pack | a free reroll, or a lost one |
| Recording a game | insert `game`, `game_lineup`, `game_event`, update `series.wins_a/b` | a game with no replay, or a series score with no game |
| Finishing a playoff series | mark the winner + move the winner on + drop the loser down | a team advanced but its opponent never placed, so the bracket is stuck |

How each ACID letter shows up:
- **Atomicity:** `sp_finish_series` has `DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;`.
- **Consistency:** CHECKs (dice 2–12, slots 1–5, `rerolls_left >= 0`) and FKs reject an invalid end state, so the transaction fails rather than committing it.
- **Isolation:** the run row is locked with `FOR UPDATE` while a pick or reroll happens.
- **Durability:** once a game is committed, its seed and events survive a crash, so the replay is always the same.

**The "no re-roll" rule** is a nice demo: `game.seed` is inserted **before** the sim runs, and `UNIQUE (series_id, game_no)` means refreshing the page can't create a second attempt at a lost game.

---

## 12. Concurrency: double clicks and two tabs

| Scenario | Risk | Guard in the draft |
|---|---|---|
| Double-click "Pick" | the same card inserted twice | `UNIQUE (run_id, slot_key)`, `UNIQUE (run_id, player_id)`; the second insert fails |
| A pick that would break "exactly 5 players + 5 heroes" | a 6th player, or too few heroes left to finish the draft | the active-slot keys `p1..p5` and `h1..h5` in `UNIQUE (run_id, slot_key)` cap each side at 5; the pack query also offers only the side that still has open slots |
| Two tabs both pick pos 1 | two carries | same UNIQUE keys; the second transaction waits on the `FOR UPDATE` lock, then fails |
| Two tabs both use the last reroll | `rerolls_left` goes to −1 (lost update) | `FOR UPDATE` on the run row + `CHECK (rerolls_left >= 0)` |
| Double-click "Finish series" | a team advanced twice | `sp_finish_series` locks the series row and requires `status <> 'done'` |
| A stale tab acts on old state | overwrites newer progress | optional optimistic check with `run.version`: `UPDATE … WHERE version = :v` |

The default isolation level, **REPEATABLE READ**, is enough here because every critical step uses a locking read (`FOR UPDATE`). A good report exercise: show the lost-update problem on `rerolls_left` with two MySQL sessions side by side, then show `FOR UPDATE` fixing it.

---

## 13. Indexing and EXPLAIN

`match_player` will hold about **2.3 million rows** (146 MB of CSV uncompressed), so indexes matter.

| Index (draft) | Serves |
|---|---|
| PK `match_player (match_id, player_slot)` | clustered: all 10 rows of a match sit together |
| `ix_mp_account (account_id, match_id)` | "all games of these accounts" (chemistry, cards) |
| `ix_mp_hero (hero_id, match_id)` | hero stats, matchups |
| `ix_match_league_time (league_id, start_time)` | "tier-1 games in a date range" (leftmost-prefix rule) |
| `ix_card_org_org (org_id, games)` | drawing a pack for one org; covering for the `games >= 30` filter |

Demo for the report:

```sql
-- Chemistry for 5 players, before and after the account index
EXPLAIN SELECT mp.match_id, mp.is_radiant
FROM match_player mp JOIN account a ON a.account_id = mp.account_id
WHERE a.player_id IN (1, 2, 3, 4, 5);
-- Without ix_mp_account: type = ALL on match_player (2.3M rows scanned)
-- With it:               type = ref, a few thousand rows
```

Partitioning `match_player` by year is a good talking point, but InnoDB partitioned tables can't have foreign keys, so the draft doesn't do it (open question 27).

---

## 14. Stored procedures and triggers

**Procedure in the draft: `sp_finish_series(series_id, winner)`** ([schema_draft.sql](../project/schema/schema_draft.sql), bottom). It:
1. starts a transaction and locks the series row (`FOR UPDATE`),
2. refuses a series that's not ready or a winner who isn't playing in it (`SIGNAL SQLSTATE '45000'`),
3. writes the winner, fills the next series' slots for the winner and the loser (the self-referencing FKs),
4. marks the next series ready once both sides are known,
5. commits, or rolls back on any error.

**Trigger idea** (in the coursework map's lab list, not in the draft schema yet): refuse a draft pick once the run has left the drafting phase.

```sql
CREATE TRIGGER trg_pick_only_while_drafting BEFORE INSERT ON run_card FOR EACH ROW
BEGIN
    IF NEW.location = 'active'
       AND (SELECT status FROM run WHERE run_id = NEW.run_id) <> 'drafting' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'draft is over';
    END IF;
END;
```

Other places a trigger could fit (options, not decisions): an audit log of upgrades, or setting `run.updated_at` on related writes.

---

## 15. Security and integrity

- **Two MySQL users** (from [dbms_coursework_map.md §2](../project/dbms_coursework_map.md)): `ati_app` (the PHP game: read everything, write only the game-state tables, execute the procedure) and `ati_etl` (the build script: full rights). The game can't damage reference data even if the PHP has a bug.
- **Prepared statements** in PHP (PDO) for every query with user input; `:run_id`-style placeholders appear throughout queries_draft.sql.
- **Constraints as the last line of defence:** the front end shouldn't send a hero to pos 6, but if it does, `CHECK (slot BETWEEN 1 AND 5)` refuses it.
- **utf8mb4** so player names in Cyrillic, Chinese and Korean are stored correctly.

---

## 16. Using this in the report and demo

- The report chapter list and the 10-minute demo script are in [dbms_coursework_map.md §4](../project/dbms_coursework_map.md).
- Strongest normalization material: §4.1 (the `main_teams` list), §4.3 (team names on account rows) and §4.4 (the card/player BCNF case with its composite FK).
- Strongest transaction material: §11 (no re-roll) and §12 (two tabs, lost update on rerolls).
- Strongest query material: the chemistry self-join, rating window functions and the recursive bracket path.
- If you split the raw import into its own database (§6), that gives the report a clean "data independence and privileges" section.
