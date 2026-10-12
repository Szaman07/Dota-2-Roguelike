# DBMS coursework map: CSE311 / CSE311L → this project

_Draft for review, 2026-10-11._

## Source of the syllabus
- **Used:** NSU's official CSE 311 page on the ECE department site ([ece.northsouth.edu/courses/cse-311](https://ece.northsouth.edu/courses/cse-311/)): the course description, its **8 course objectives**, and the note that **CSE 311L** (0 credits, weekly labs) "culminates in building a full database system with a front end", with lab marks carried into the theory grade.
- **Not found publicly:** the CO/PO form, the lab manual and an official grading split (both are downloads I couldn't read). User-uploaded outlines on Coursehero/Studocu report roughly: attendance 10%, labs/assignments 15%, project 10%, quizzes 15%, midterm 20%, final 30%, but they're from mixed semesters and instructors, so treat them as unconfirmed. Sections differ; **check your own section's outline** and adjust §4.
- **Textbook:** Silberschatz, Korth & Sudarshan, *Database System Concepts* (7th ed.) appears in an NSU CSE311 deck (Dr. Latiful Hoque); chapter references below use it. If your section uses Elmasri & Navathe, the topics map the same way.

## 1. The 8 official objectives, mapped

| # | NSU objective (paraphrased from the official page) | Where the project shows it | Evidence for the report |
|---|---|---|---|
| 1 | Advantages of a database over flat files | The data arrives as ~400 CSV files (OpenDota, Wiki, Liquipedia). Show what's painful in files (an alias change touching thousands of rows, no constraint stopping two pos-1 players, no atomic "finish series") and how the DB fixes each | A before/after table in the report; a demo where a constraint rejects a bad insert |
| 2 | Requirement analysis, especially data requirements | [game_outline.md](game_outline.md) §5 lists every screen with what it reads and writes; [data/README.md](../../data/README.md) lists every source field and why it's needed | A requirements chapter: entities, attributes, volumes, update frequency (reference data yearly, game state per click) |
| 3 | Conceptual design with E-R diagrams, mapped to relational schemas | [schema/er_diagram.md](schema/er_diagram.md): 42 entities with 1:1 (hero–hero_trait), 1:N (match–match_player), M:N (ability–mechanic, tournament–league), weak entities (card_position depends on player_card), a recursive relationship (series → next series) | ER diagram + the mapping steps (M:N → bridge table, multi-valued role tags → separate table, recursive → self FK) |
| 4 | Relational algebra as the base of SQL | Write the key queries in algebra first: chemistry = ρ + self-join (⋈ on match_id ∧ same side ∧ slot ≠ slot), counters = join on opposite sides, pack draw = σ on card_org then π | 4–6 queries shown as algebra expressions next to their SQL |
| 5 | Turn the design into a physical one in MySQL | [schema/schema_draft.sql](schema/schema_draft.sql): data types sized to the data (SMALLINT hero ids, BIGINT match ids), InnoDB, utf8mb4 (player names in Cyrillic, Chinese, Korean), indexes for the hot paths | DDL appendix; `EXPLAIN` before/after an index |
| 6 | Redundancy problems shown through functional dependencies | Real anomalies in the raw data: team names repeated on every match row (team_id → name), player names on account rows (two accounts, one Nisha), Postgres arrays in a column | FD list per table, decomposition to 3NF/BCNF, and the one deliberate denormalization (`run_card.player_id`) justified |
| 7 | Full physical database with minimal redundancy and good performance | Layer A/C normalized; layer B is a documented cache of aggregates rebuilt by SQL; indexes on (account_id, match_id), (hero_id, match_id), (league_id, start_time) | Query timings with and without the summary tables and indexes |
| 8 | An independent project emphasizing data requirements | The whole game: 15 years of real pro data feeding a playable front end in PHP | The demo |

## 2. Course topics (official description) → concrete project features

| Topic in the course description | Feature | SQL / DB feature used | Silberschatz 7e |
|---|---|---|---|
| ER model | 42-entity design, recursive bracket | ER, weak entities, cardinalities | ch. 6 |
| Relational model and languages | All queries | joins, subqueries, set operations | ch. 2, 3 |
| Functional dependencies, normal forms | Cleaning OpenDota exports | 1NF (arrays → scalars), 2NF/3NF decomposition, BCNF check | ch. 7 |
| Query language design and implementation | Card ratings, chemistry, counters, standings | **window functions** (PERCENT_RANK, ROW_NUMBER, rolling AVG … ROWS 99 PRECEDING), **CTEs**, **recursive CTE** (bracket path), GROUP BY … HAVING, self-joins, gaps-and-islands | ch. 3, 5 |
| Query optimization | ETL over a few million player rows | `EXPLAIN ANALYZE`, composite indexes, covering indexes, summary tables vs on-demand joins | ch. 15, 16 |
| Security and integrity | Game state can't be corrupted by the front end | PK/FK/UNIQUE/CHECK (MySQL 8.0.16+ enforces CHECK), generated columns, prepared statements (no SQL injection), a least-privilege app user (below) | ch. 4, 9 |
| Concurrency control | Two browser tabs, double clicks | transactions, `SELECT … FOR UPDATE`, optimistic version column, UNIQUE keys as idempotency guards, isolation level discussion (REPEATABLE READ default) | ch. 17, 18 |
| Tree and hash indices, access costs | Lookups by account, hero, time range | B+-tree indexes on composite keys; comparison with a hash index on a MEMORY table for the hero matrix | ch. 14 |
| (Lab) SQL practice | Weekly lab tasks can use this data (see §3) | DDL, DML, joins, aggregates, views, procedures, triggers | — |
| (Lab) Full system with front end | PHP + MySQL game | PDO, sessions, MVC-ish structure | ch. 9 |

### Least-privilege users (security talking point; draft)
```sql
CREATE USER 'ati_app'@'localhost' IDENTIFIED BY '...';
GRANT SELECT ON ati.* TO 'ati_app'@'localhost';                          -- read reference + derived data
GRANT INSERT, UPDATE, DELETE ON ati.run TO 'ati_app'@'localhost';        -- and the other 9 game-state tables
GRANT EXECUTE ON PROCEDURE ati.sp_finish_series TO 'ati_app'@'localhost';
CREATE USER 'ati_etl'@'localhost' IDENTIFIED BY '...';                   -- only the build script writes layers A/B
GRANT ALL ON ati.* TO 'ati_etl'@'localhost';
```

## 3. Lab-sized exercises the data supports (if your instructor wants weekly work tied to the project)

| Lab topic | Exercise on this data |
|---|---|
| DDL, constraints | Create `hero`, `pro_match`, `match_player`; try inserting a player slot 7 and watch CHECK fail |
| Basic SELECT, WHERE, ORDER | Heroes with the most pro games since 2024 |
| Joins | Every game Puppey played for Secret (account → player alias → match → team → org) |
| Aggregates, GROUP BY, HAVING | Players with 300+ games on one hero |
| Subqueries | Heroes whose pro win rate beats the average of their primary attribute |
| Views | `v_card`, `v_group_standings` |
| Window functions | Rolling 100-game win rate; top hero per player with ROW_NUMBER |
| Stored procedures, triggers | `sp_finish_series`; a trigger that refuses a draft pick when `run.status <> 'drafting'` |
| Transactions | Record a game; show what a crash midway would leave without the transaction |
| Indexing | `EXPLAIN` the chemistry query before and after `ix_mp_account` |

## 4. Report and demo outline (adjust to your section's rubric)

1. **Introduction:** what the game is (one paragraph from [proposal.md](proposal.md)).
2. **Requirements:** users (a single player, no accounts), functional requirements (the 12 screens), data requirements (sources, volumes, licenses).
3. **Conceptual design:** ER diagram, entity descriptions, constraints in words.
4. **Logical design:** relational schema, FDs, normalization steps, the denormalization note.
5. **Physical design:** DDL, data types, indexes, users and privileges.
6. **Data acquisition (ETL):** pull scripts, staging tables, cleaning (aliases, orgs, anonymous accounts, missing lane data before 2016), row counts.
7. **Queries:** 10–15 annotated queries (ratings, chemistry, counters, standings, bracket), with relational algebra for a few and `EXPLAIN` for the heavy ones.
8. **Transactions and concurrency:** the run lifecycle, the "no re-roll" rule, double-click and two-tab scenarios.
9. **Front end:** screenshots of draft, team, group table, replay, bracket.
10. **Testing:** constraint tests, ETL checks (totals match OpenDota), sim balance numbers.
11. **Limitations and future work;** **credits and licenses** (OpenDota, Liquipedia CC-BY-SA, Dota 2 Wiki CC-BY-SA, Valve's fan-content terms).

**Demo script (10 minutes):** start a run → draft 10 picks (show the pack query) → team screen (try two pos-1 players; the UNIQUE key refuses) → play a group game (show `game_event` rows) → refresh mid-game (no re-roll) → finish a playoff series (procedure call, bracket advances) → one analytics query (most successful pool rosters across all runs).
