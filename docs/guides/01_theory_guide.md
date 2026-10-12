# Theory guide: CSE311 database concepts

_Written 2026-10-11 for the CSE311 (NSU) project. This is the course theory on its own, explained simply, with small MySQL 8 snippets. Examples use Dota-flavoured tables so they're easy to picture; [02_course_to_project.md](02_course_to_project.md) shows the same ideas on the project's real draft schema. Chapter references are to Silberschatz, Korth & Sudarshan, *Database System Concepts*, 7th ed. (the textbook in [dbms_coursework_map.md](../project/dbms_coursework_map.md)); check your own section's outline._

**Contents**
1. [Why a database, not files](#1-why-a-database-not-files)
2. [The ER model](#2-the-er-model)
3. [Keys](#3-keys)
4. [The relational model and integrity constraints](#4-the-relational-model-and-integrity-constraints)
5. [Relational algebra](#5-relational-algebra)
6. [Functional dependencies and normalization (1NF to BCNF)](#6-functional-dependencies-and-normalization)
7. [SQL: defining data (DDL)](#7-sql-defining-data-ddl)
8. [SQL: reading data](#8-sql-reading-data)
9. [Joins](#9-joins)
10. [SQL: writing data](#10-sql-writing-data)
11. [Views](#11-views)
12. [Transactions and ACID](#12-transactions-and-acid)
13. [Concurrency control](#13-concurrency-control)
14. [Indexing and query cost](#14-indexing-and-query-cost)
15. [Stored procedures, functions and triggers](#15-stored-procedures-functions-and-triggers)
16. [Security and integrity](#16-security-and-integrity)
17. [Exam checklist](#17-exam-checklist)

---

## 1. Why a database, not files
_Silberschatz ch. 1_

Keeping data in plain files (CSV, text) causes problems a DBMS solves:

| Problem with files | What a DBMS gives you |
|---|---|
| **Redundancy and inconsistency:** the same fact copied in many files drifts apart | One place for each fact, linked by keys |
| **Hard to query:** every new question needs a new program | A declarative language (SQL) |
| **No integrity rules:** nothing stops a bad value | Constraints: types, `NOT NULL`, `UNIQUE`, `CHECK`, foreign keys |
| **No atomicity:** a crash halfway through leaves half an update | Transactions (all or nothing) |
| **No safe sharing:** two users editing at once overwrite each other | Concurrency control (locks, isolation) |
| **No security:** anyone who can read the file reads everything | Users, roles, `GRANT` |

**Levels of abstraction:** *physical* (how bytes are stored), *logical* (tables and columns), *view* (what one user sees). **Data independence** means you can change a lower level without breaking the one above it, for example adding an index without changing any query.

## 2. The ER model
_Silberschatz ch. 6_

The Entity-Relationship model is how you design before writing tables.

- **Entity:** a thing you store facts about (a hero, a player). An **entity set** is all of them.
- **Attribute:** a property. Kinds:
  - *simple* vs *composite* (name → first, last)
  - *single-valued* vs *multi-valued* (a hero's several role tags)
  - *derived* (a player's win rate, computed from games)
- **Relationship:** an association between entities (a player *plays* a hero in a match). Relationships can have attributes too (the games count in "player played hero").
- **Degree:** binary (two entity sets) is most common; ternary has three.
- **Recursive relationship:** an entity set related to itself (a series feeds into the next series).

**Cardinality** (how many on each side):

| Type | Meaning | Example |
|---|---|---|
| 1:1 | one to one | a hero has one curated trait row |
| 1:N | one to many | a match has many player rows |
| M:N | many to many | an ability applies many mechanics; a mechanic comes from many abilities |

**Participation:** *total* (every entity must take part, double line) or *partial* (single line). Every match must have players: total. Not every player has a placement: partial.

**Weak entity:** can't be identified by its own attributes, only together with its owner (the **identifying relationship**). It has a **partial key** (discriminator). Example: "games at position 3 for card 17" only makes sense with the card.

**Specialization / generalization (ISA):** a superclass split into subclasses (a run card is either a player card or a hero card). Can be disjoint or overlapping, total or partial.

### Mapping ER to tables

| ER element | Becomes |
|---|---|
| Strong entity | A table; its key becomes the primary key |
| Weak entity | A table whose PK = owner's PK + partial key, with an FK to the owner (usually `ON DELETE CASCADE`) |
| 1:N relationship | An FK column on the N side |
| 1:1 relationship | An FK on either side, with `UNIQUE` (or share the PK) |
| M:N relationship | A separate **bridge (junction) table** whose PK is both FKs |
| Multi-valued attribute | A separate table (attribute + owner key) |
| Composite attribute | Its simple parts as columns |
| Derived attribute | Usually not stored; computed by a query (or cached on purpose) |
| ISA | One table per class, one table for all with a type column, or tables for subclasses only |

```sql
-- M:N between ability and mechanic becomes a bridge table
CREATE TABLE ability_mechanic (
    ability_id  INT UNSIGNED NOT NULL,
    mechanic_id TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (ability_id, mechanic_id),
    FOREIGN KEY (ability_id)  REFERENCES ability(ability_id),
    FOREIGN KEY (mechanic_id) REFERENCES mechanic(mechanic_id)
);
```

## 3. Keys
_Silberschatz ch. 2, 6_

| Key | Definition | Example |
|---|---|---|
| **Superkey** | Any set of attributes that uniquely identifies a row | `{hero_id, name}` |
| **Candidate key** | A minimal superkey (remove any attribute and it stops being unique) | `hero_id`, and also `name` |
| **Primary key** | The candidate key you pick; `NOT NULL` and unique | `hero_id` |
| **Alternate key** | A candidate key you didn't pick; enforce it with `UNIQUE` | `name` |
| **Composite key** | A key of 2+ columns | `(match_id, player_slot)` |
| **Foreign key** | Columns that must match a key in another (or the same) table | `match_player.hero_id → hero.hero_id` |
| **Natural key** | A key from the real world | Steam `account_id` |
| **Surrogate key** | An invented id, usually `AUTO_INCREMENT` | `player_id` |

Tips:
- Use a surrogate key when the natural key can change or doesn't exist (a person's display name changes; their `player_id` doesn't).
- Every candidate key you don't use as the PK should still get a `UNIQUE` constraint.
- In MySQL a `UNIQUE` index allows several `NULL`s, because `NULL` is never equal to `NULL`. That's a handy trick (see the course-to-project guide).

## 4. The relational model and integrity constraints
_Silberschatz ch. 2_

- A **relation** is a table; a **tuple** is a row; an **attribute** is a column; a **domain** is the set of allowed values for a column.
- A relation is a *set*: no duplicate rows, no meaningful row order or column order (SQL tables allow duplicates unless you add a key).
- **Schema** = the structure (`hero(hero_id, name, attack_type)`); **instance** = the rows at one moment.
- `NULL` means unknown or not applicable. Any comparison with `NULL` gives *unknown*, so use `IS NULL`, never `= NULL`.

**Integrity constraints:**

| Constraint | Rule | SQL |
|---|---|---|
| Domain | Values have the right type and range | data types, `ENUM`, `CHECK (pos BETWEEN 1 AND 5)` |
| Entity integrity | The PK is never `NULL` | `PRIMARY KEY` |
| Key | No two rows share a key | `PRIMARY KEY`, `UNIQUE` |
| Referential integrity | An FK value exists in the referenced table (or is `NULL`) | `FOREIGN KEY ... REFERENCES` |
| Not null | A value is required | `NOT NULL` |

**Referential actions** decide what happens to children when a parent row is deleted or its key updated: `RESTRICT` / `NO ACTION` (refuse, the default), `CASCADE` (delete or update the children too), `SET NULL`.

> MySQL only enforces `CHECK` from **8.0.16** on. Earlier versions parse and ignore it.

## 5. Relational algebra
_Silberschatz ch. 2_

The math behind SQL. Each operation takes relations and returns a relation.

| Operation | Symbol | Does | SQL equivalent |
|---|---|---|---|
| Selection | σ | keep rows matching a condition | `WHERE` |
| Projection | π | keep some columns (and remove duplicates) | `SELECT DISTINCT cols` |
| Union | ∪ | rows in either (same schema) | `UNION` |
| Set difference | − | rows in the first but not the second | `EXCEPT` (8.0.31+) or `NOT EXISTS` |
| Intersection | ∩ | rows in both | `INTERSECT` (8.0.31+) or `EXISTS` |
| Cartesian product | × | every pair of rows | `CROSS JOIN` |
| Rename | ρ | give a relation or column a new name | `AS` |
| Natural join | ⋈ | product + equality on same-named columns + projection | `NATURAL JOIN` / `JOIN ... USING` |
| Theta join | ⋈θ | product + any condition | `JOIN ... ON` |
| Division | ÷ | "for all" queries | double `NOT EXISTS` |
| Aggregation | γ (G) | grouping and aggregate functions | `GROUP BY` |

Example: names of heroes that are melee.

π<sub>name</sub>(σ<sub>attack_type='Melee'</sub>(hero))

```sql
SELECT DISTINCT name FROM hero WHERE attack_type = 'Melee';
```

Example with rename and a self-join: pairs of accounts that played on the same side of the same match.

π<sub>x.account_id, y.account_id</sub>(σ<sub>x.match_id=y.match_id ∧ x.side=y.side ∧ x.slot&lt;y.slot</sub>(ρ<sub>x</sub>(match_player) × ρ<sub>y</sub>(match_player)))

**Division** answers "which X relate to *every* Y". Players who played every hero in a set S: `player_hero ÷ S`. In SQL: a player for whom no hero in S exists that they didn't play.

## 6. Functional dependencies and normalization
_Silberschatz ch. 7_

### 6.1 Why normalize: anomalies

Picture one wide table:

| match_id | team_id | team_name | account_id | player_name | hero_id | hero_name |
|---|---|---|---|---|---|---|

- **Update anomaly:** a team renames itself, and you must change thousands of rows; miss one and the data contradicts itself.
- **Insertion anomaly:** you can't store a new hero until someone has played it in a match.
- **Deletion anomaly:** delete the only match a team played and you lose the team's name.

Normalization splits tables so that each fact lives in exactly one place.

### 6.2 Functional dependencies (FDs)

`X → Y` ("X determines Y") means: any two rows that agree on X also agree on Y.
Examples: `hero_id → hero_name`, `team_id → team_name`, `(match_id, player_slot) → hero_id`.

- **Trivial FD:** Y ⊆ X (always true, carries no information).
- **Armstrong's axioms:** *reflexivity* (if Y ⊆ X then X → Y), *augmentation* (if X → Y then XZ → YZ), *transitivity* (if X → Y and Y → Z then X → Z). Derived rules: *union*, *decomposition*, *pseudotransitivity*.
- **Closure of attributes X⁺:** everything X determines. Start with X, keep adding the right side of any FD whose left side is already inside. **X is a superkey iff X⁺ contains every attribute.**
- **Canonical (minimal) cover:** an equivalent set of FDs with single attributes on the right, no extra attributes on the left, and no redundant FDs.

Worked closure: R(match_id, slot, account_id, player_id, hero_id, hero_name) with
F = { (match_id, slot) → account_id, hero_id;  account_id → player_id;  hero_id → hero_name }.
{match_id, slot}⁺ = {match_id, slot} → add account_id, hero_id → add player_id, hero_name. That's every attribute, so (match_id, slot) is a key.

### 6.3 The normal forms

| Normal form | Rule | Typical violation | Fix |
|---|---|---|---|
| **1NF** | Every value is atomic: no lists, arrays or repeating groups | A column `role_tags = "Carry,Nuker,Escape"` or `hero1, hero2, hero3` columns | Move the list to its own table, one value per row |
| **2NF** | 1NF, and **no partial dependency**: no non-key attribute depends on only part of a composite key | Key `(match_id, slot)` with a column `duration`: `match_id → duration` depends on half the key | Move the partially dependent column to a table keyed by that part (`pro_match(match_id, duration)`) |
| **3NF** | 2NF, and **no transitive dependency**: no non-key attribute depends on another non-key attribute | `account(account_id, team_id, team_name)`: account_id → team_id → team_name | Move `team_name` to `team(team_id, team_name)` |
| **BCNF** | For **every** non-trivial FD X → Y, X is a superkey | An FD whose left side isn't a key, even if Y is part of a key | Decompose on that FD |

Formal 3NF: for every non-trivial FD X → A, either X is a superkey **or** A is part of some candidate key (a *prime* attribute). BCNF drops that second escape hatch, so BCNF is stricter. Every BCNF schema is in 3NF; not every 3NF schema is in BCNF.

**A classic 3NF-but-not-BCNF case:** R(student, course, teacher), each teacher teaches one course (teacher → course), and a student takes a course from one teacher ((student, course) → teacher). Keys: (student, course) and (student, teacher). `teacher → course` has a non-superkey on the left, so it breaks BCNF, but `course` is prime, so it's fine for 3NF.

### 6.4 Decomposition properties

When you split R into R1 and R2:
- **Lossless join:** joining R1 and R2 gives back exactly R, no extra rows. Test: R1 ∩ R2 → R1, or R1 ∩ R2 → R2 (the shared columns are a key of one side).
- **Dependency preservation:** every FD can still be checked inside one table without joining.

3NF decomposition (synthesis from a canonical cover) always achieves both. BCNF decomposition is always lossless but can lose dependency preservation, which is why designers sometimes stop at 3NF.

**Algorithm (BCNF decomposition):** while some table R has an FD X → Y that breaks BCNF, replace R by (X ∪ Y) and (R − Y + X).

### 6.5 Beyond BCNF (good to know)

**4NF** deals with multi-valued dependencies (X →→ Y): two independent lists stored in one table (a hero's roles and a hero's talents in the same table make every combination). Split them.

### 6.6 Denormalization

Sometimes you deliberately keep a redundant copy or a precomputed summary for speed or to enforce a rule. That's fine if you **document it** and **keep it consistent** (a constraint, a trigger, or a rebuild script).

## 7. SQL: defining data (DDL)
_Silberschatz ch. 3, 4_

```sql
CREATE DATABASE ati CHARACTER SET utf8mb4;      -- utf8mb4 stores Cyrillic, Chinese, Korean names
USE ati;

CREATE TABLE hero (
    hero_id      SMALLINT UNSIGNED PRIMARY KEY,
    name         VARCHAR(64) NOT NULL UNIQUE,
    attack_type  ENUM('Melee','Ranged') NOT NULL,
    move_speed   SMALLINT UNSIGNED CHECK (move_speed BETWEEN 200 AND 550)
) ENGINE=InnoDB;                                -- InnoDB: transactions + foreign keys

ALTER TABLE hero ADD COLUMN primary_attr ENUM('str','agi','int','all') NOT NULL DEFAULT 'all';
ALTER TABLE hero ADD INDEX ix_hero_attr (primary_attr);
DROP TABLE IF EXISTS temp_stuff;
TRUNCATE TABLE stg_match;                       -- empty a table fast (no row-by-row delete)
```

- Pick the smallest type that fits: `TINYINT` (−128..127 or 0..255 unsigned), `SMALLINT`, `INT`, `BIGINT`; `DECIMAL(p,s)` for exact numbers; `VARCHAR(n)`; `DATE`, `DATETIME`, `TIMESTAMP`; `BOOLEAN` is `TINYINT(1)`; `JSON`.
- **Generated columns** compute a value from other columns: `is_radiant BOOLEAN AS (player_slot < 128) STORED`.

## 8. SQL: reading data
_Silberschatz ch. 3, 5_

### 8.1 The shape of a SELECT and its logical order

```sql
SELECT   h.name, COUNT(*) AS games            -- 5. pick columns
FROM     match_player mp                      -- 1. take rows
JOIN     hero h ON h.hero_id = mp.hero_id     --    combine tables
WHERE    mp.lane_role = 2                     -- 2. filter rows
GROUP BY h.name                               -- 3. group
HAVING   COUNT(*) >= 500                      -- 4. filter groups
ORDER BY games DESC                           -- 6. sort
LIMIT    10;                                  -- 7. cut
```

The logical order is **FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT**. That's why `WHERE` can't use an aggregate (groups don't exist yet) and why `HAVING` can.

### 8.2 Building blocks

- Filters: `=, <>, <, BETWEEN, IN (...), LIKE 'Team %', IS NULL`, combined with `AND / OR / NOT`.
- Aggregates: `COUNT(*)`, `COUNT(col)` (skips NULLs), `SUM`, `AVG`, `MIN`, `MAX`, `GROUP_CONCAT`.
- `CASE WHEN ... THEN ... ELSE ... END` for conditional values.
- `DISTINCT` removes duplicate rows.

### 8.3 Subqueries

```sql
-- Scalar subquery: heroes picked more than the average hero
SELECT hero_id, COUNT(*) n FROM match_player GROUP BY hero_id
HAVING n > (SELECT AVG(c) FROM (SELECT COUNT(*) c FROM match_player GROUP BY hero_id) t);

-- IN / EXISTS (semi-join): players who ever played Io
SELECT p.* FROM player p
WHERE EXISTS (SELECT 1 FROM account a JOIN match_player mp USING (account_id)
              WHERE a.player_id = p.player_id AND mp.hero_id = 91);

-- NOT EXISTS (anti-join): heroes never picked
SELECT h.* FROM hero h
WHERE NOT EXISTS (SELECT 1 FROM match_player mp WHERE mp.hero_id = h.hero_id);
```

A **correlated** subquery refers to the outer row and runs once per outer row (conceptually).

### 8.4 Set operations

`UNION` (removes duplicates), `UNION ALL` (keeps them, faster), and from MySQL 8.0.31 `INTERSECT` and `EXCEPT`. Both sides need the same number and type of columns.

### 8.5 CTEs (`WITH`)

A named subquery you can read top to bottom. A **recursive CTE** walks a hierarchy or a chain:

```sql
WITH RECURSIVE path AS (
    SELECT series_id, next_win_series, 1 AS depth FROM series WHERE series_id = 101
    UNION ALL
    SELECT s.series_id, s.next_win_series, p.depth + 1
    FROM series s JOIN path p ON s.series_id = p.next_win_series
)
SELECT * FROM path;              -- every series a winner of 101 would play next
```

### 8.6 Window functions

They compute across related rows **without collapsing them** (unlike `GROUP BY`).

```sql
SELECT player_id, start_time, won,
       ROW_NUMBER()  OVER (PARTITION BY player_id ORDER BY start_time)              AS game_no,
       AVG(won)      OVER (PARTITION BY player_id ORDER BY start_time
                           ROWS BETWEEN 99 PRECEDING AND CURRENT ROW)               AS rolling_100_wr,
       PERCENT_RANK() OVER (ORDER BY won)                                           AS pct
FROM player_game;
```

Common ones: `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `PERCENT_RANK`, `NTILE`, `LAG`, `LEAD`, `SUM/AVG ... OVER`. Typical uses: top-N per group, running totals, rolling averages, rankings.

## 9. Joins
_Silberschatz ch. 3, 4_

| Join | Keeps | Use for |
|---|---|---|
| `INNER JOIN` | only matching pairs | the normal case |
| `LEFT JOIN` | every left row; NULLs where the right side has no match | "all heroes, with games if any" |
| `RIGHT JOIN` | every right row | same as LEFT with the tables swapped |
| `FULL OUTER JOIN` | every row from both | **not in MySQL**: emulate with `LEFT JOIN ... UNION ... RIGHT JOIN` |
| `CROSS JOIN` | every combination | building a grid (5 players × 5 heroes) |
| `NATURAL JOIN` / `USING` | equality on same-named columns | short syntax; `USING` is safer than `NATURAL` |
| **Self-join** | a table joined to itself under two aliases | pairs (teammates, opponents) |
| Semi-join | left rows that have a match (`EXISTS`, `IN`) | filtering |
| Anti-join | left rows with no match (`NOT EXISTS`, `LEFT JOIN ... WHERE right.id IS NULL`) | "never happened" |

```sql
-- LEFT JOIN: every hero, with its pick count (0 if never picked)
SELECT h.name, COUNT(mp.match_id) AS picks
FROM hero h LEFT JOIN match_player mp ON mp.hero_id = h.hero_id
GROUP BY h.hero_id, h.name;
```

Watch out: a condition on the right table in `WHERE` turns a LEFT JOIN back into an INNER JOIN. Put it in `ON` instead.

**How the DBMS runs a join** (ch. 15): *nested loop* (for each left row, look up the right; fast with an index on the right join column), *block nested loop*, *hash join* (MySQL 8.0.18+, for equality joins without a useful index), *sort-merge* (in textbooks; MySQL doesn't use it).

## 10. SQL: writing data
_Silberschatz ch. 3_

```sql
INSERT INTO hero (hero_id, name, attack_type) VALUES (1, 'Anti-Mage', 'Melee');
INSERT INTO hero (hero_id, name, attack_type) VALUES (2, 'Axe', 'Melee'), (5, 'Crystal Maiden', 'Ranged');   -- multi-row

INSERT INTO account (account_id)                        -- INSERT ... SELECT: copy from another table
SELECT DISTINCT account_id FROM stg_player_match WHERE account_id IS NOT NULL;

UPDATE run SET rerolls_left = rerolls_left - 1 WHERE run_id = 42 AND rerolls_left > 0;
DELETE FROM run WHERE status = 'abandoned' AND updated_at < NOW() - INTERVAL 30 DAY;

-- Upsert: insert, or update if the key already exists
INSERT INTO card_hero (card_id, hero_id, games, wins) VALUES (7, 74, 1, 1)
ON DUPLICATE KEY UPDATE games = games + 1, wins = wins + VALUES(wins);

-- Bulk load a CSV (needs local_infile enabled on client and server)
LOAD DATA LOCAL INFILE 'm_20240128.csv' INTO TABLE stg_match
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' IGNORE 1 LINES;
```

- `UPDATE` and `DELETE` without `WHERE` hit every row. MySQL Workbench's safe-updates mode refuses that by default.
- `INSERT IGNORE` skips rows that break a unique key (silently: use it only when that's what you want).
- `REPLACE` deletes and re-inserts, which fires delete cascades; prefer `ON DUPLICATE KEY UPDATE`.

## 11. Views
_Silberschatz ch. 4_

A **view** is a stored query that looks like a table.

```sql
CREATE OR REPLACE VIEW v_card AS
SELECT c.card_id, p.display_name, c.rating
FROM player_card c JOIN player p USING (player_id);

SELECT * FROM v_card WHERE rating >= 95;
```

Why use them: hide join complexity, give an app user a limited window on the data (security), keep old queries working when tables change (logical data independence).

- A view stores no data; it runs its query every time.
- A simple view (one table, no aggregates, no `DISTINCT`, no `GROUP BY`) is **updatable**; `WITH CHECK OPTION` refuses writes the view couldn't see afterwards.
- **Materialized view:** stores the result. MySQL doesn't have them; you emulate one with a summary table rebuilt by a script or kept current by triggers.

## 12. Transactions and ACID
_Silberschatz ch. 17_

A **transaction** is a group of operations that succeed or fail as one.

```sql
START TRANSACTION;
UPDATE series SET winner = 7, status = 'done' WHERE series_id = 101;
UPDATE series SET team_a = 7 WHERE series_id = 105;   -- winner moves on
UPDATE series SET team_a = 9 WHERE series_id = 104;   -- loser drops down
COMMIT;            -- or ROLLBACK; to undo everything since START TRANSACTION
```

| Property | Meaning | How InnoDB provides it |
|---|---|---|
| **Atomicity** | all or nothing | undo log; rollback on error or crash |
| **Consistency** | moves the database from one valid state to another | constraints + correct transaction logic |
| **Isolation** | concurrent transactions don't see each other's half-done work | locks + MVCC |
| **Durability** | once committed, it survives a crash | redo log written before commit |

- MySQL runs in **autocommit** mode by default: every single statement is its own transaction unless you `START TRANSACTION`.
- `SAVEPOINT s1; ... ROLLBACK TO s1;` undoes part of a transaction.
- DDL (`CREATE`, `ALTER`, `DROP`) causes an implicit commit in MySQL; don't mix it into a transaction you might roll back.
- **Transaction states:** active → partially committed → committed, or active → failed → aborted.

## 13. Concurrency control
_Silberschatz ch. 17, 18_

### 13.1 What can go wrong when transactions overlap

| Anomaly | What happens |
|---|---|
| **Lost update** | T1 and T2 both read 2 rerolls, both write 1: one decrement is lost |
| **Dirty read** | T2 reads T1's uncommitted change; T1 rolls back |
| **Non-repeatable read** | T1 reads a row twice and gets different values because T2 committed in between |
| **Phantom read** | T1 runs the same range query twice and new rows appear |

### 13.2 Isolation levels (SQL standard)

| Level | Dirty read | Non-repeatable | Phantom |
|---|---|---|---|
| READ UNCOMMITTED | possible | possible | possible |
| READ COMMITTED | prevented | possible | possible |
| **REPEATABLE READ** (MySQL default) | prevented | prevented | possible in the standard; InnoDB prevents it (snapshot for plain reads, next-key locks for `FOR UPDATE`) |
| SERIALIZABLE | prevented | prevented | prevented |

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

### 13.3 Serializability and schedules

A **schedule** interleaves the operations of several transactions. It's **serializable** if its result equals some serial (one-after-another) order. **Conflict serializability:** build a *precedence graph* (edge Ti → Tj when an operation of Ti conflicts with a later one of Tj on the same item, with at least one a write); the schedule is conflict-serializable **iff the graph has no cycle**. Also know *recoverable* and *cascadeless* schedules.

### 13.4 Locking

- **Shared (S) lock** for reading, **exclusive (X) lock** for writing. S is compatible with S; X with nothing.
- **Two-phase locking (2PL):** a growing phase (only acquire locks) then a shrinking phase (only release). Guarantees conflict serializability. **Strict 2PL** holds X locks until commit (what InnoDB does), which also avoids cascading rollbacks.
- **Deadlock:** T1 waits for T2's lock while T2 waits for T1's. InnoDB detects it, rolls one back (error 1213), and the app should retry.
- **Granularity:** InnoDB locks rows (and gaps between index records), not whole tables.

```sql
START TRANSACTION;
SELECT rerolls_left FROM run WHERE run_id = 42 FOR UPDATE;   -- X-lock the row; a second tab waits here
UPDATE run SET rerolls_left = rerolls_left - 1 WHERE run_id = 42;
COMMIT;
-- FOR SHARE takes an S lock instead (read, but stop others from changing it)
```

### 13.5 MVCC and optimistic control

- **MVCC (multi-version concurrency control):** InnoDB keeps old row versions so plain `SELECT`s read a consistent snapshot without locking; writers don't block readers.
- **Optimistic concurrency:** no lock; keep a `version` column and update only if it hasn't changed. If 0 rows were updated, someone else got there first:

```sql
UPDATE run SET status = 'groups', version = version + 1
WHERE run_id = 42 AND version = 7;     -- 0 rows affected = conflict, reload and retry
```

- **Timestamp ordering** and **validation-based** protocols are the textbook alternatives to locking.

## 14. Indexing and query cost
_Silberschatz ch. 14, 15, 16_

An **index** is a separate structure that finds rows by a column's value without scanning the whole table.

- **B+ tree** (MySQL's default): balanced; all values in the leaves, leaves linked in order. Lookup cost ≈ tree height (3 to 4 page reads for millions of rows). Good for `=`, ranges (`BETWEEN`, `<`), `ORDER BY` and prefix `LIKE 'abc%'`.
- **Hash index:** for `=` only, no ranges or sorting. In MySQL only the MEMORY engine has explicit hash indexes (InnoDB has an internal *adaptive* hash index).
- **Clustered vs secondary:** InnoDB stores the table rows *inside* the primary-key B+ tree (the clustered index). A secondary index stores the indexed columns plus the PK, then looks the row up in the clustered index.
- **Dense vs sparse**, **primary vs secondary**: textbook terms; know the definitions.
- **Composite index** `(a, b, c)` works for `a`, `a,b`, `a,b,c` (the **leftmost-prefix rule**), not for `b` alone.
- **Covering index:** contains every column the query needs, so the table isn't touched (`EXPLAIN` shows "Using index").
- **Cost:** indexes speed up reads but slow down writes (each insert updates every index) and use disk. Index what you filter, join and sort on; don't index everything.

```sql
CREATE INDEX ix_mp_account ON match_player (account_id, match_id);
EXPLAIN SELECT match_id FROM match_player WHERE account_id = 86745912;
EXPLAIN ANALYZE SELECT ...;     -- 8.0.18+: actually runs it and shows real times
```

In `EXPLAIN`, look at `type` (`ALL` = full table scan, bad on big tables; `ref`/`range`/`eq_ref`/`const` = using an index), `key` (which index), `rows` (estimate), and `Extra`.

**Query processing** (ch. 15–16): parse → translate to relational algebra → optimize (rewrite with equivalence rules such as "push selections down", choose join order and access paths by estimated cost) → execute.

## 15. Stored procedures, functions and triggers
_Silberschatz ch. 5_

**Stored procedure:** named SQL code stored in the database, called with `CALL`. Good for multi-step operations that must stay atomic.

```sql
DELIMITER //
CREATE PROCEDURE sp_use_reroll(IN p_run BIGINT)
BEGIN
    DECLARE v_left TINYINT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    START TRANSACTION;
    SELECT rerolls_left INTO v_left FROM run WHERE run_id = p_run FOR UPDATE;
    IF v_left = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'no rerolls left';
    END IF;
    UPDATE run SET rerolls_left = rerolls_left - 1 WHERE run_id = p_run;
    COMMIT;
END //
DELIMITER ;

CALL sp_use_reroll(42);
```

Pieces to know: `IN / OUT / INOUT` parameters, `DECLARE`, `SET`, `IF / CASE / WHILE / LOOP`, cursors, handlers, `SIGNAL` to raise an error.

**Stored function:** returns one value and can be used inside a query.

```sql
CREATE FUNCTION shrink_wr(w INT, g INT) RETURNS DECIMAL(5,4) DETERMINISTIC
RETURN (w + 25) / (g + 50);           -- pull small samples toward 50%
SELECT card_id, shrink_wr(wins, games) FROM player_card;
```

**Trigger:** runs automatically `BEFORE` or `AFTER` an `INSERT`, `UPDATE` or `DELETE`, once per row, with `NEW` (incoming values) and `OLD` (previous values).

```sql
DELIMITER //
CREATE TRIGGER trg_pick_only_while_drafting
BEFORE INSERT ON run_card FOR EACH ROW
BEGIN
    IF (SELECT status FROM run WHERE run_id = NEW.run_id) <> 'drafting'
       AND NEW.location = 'active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'draft is over';
    END IF;
END //
DELIMITER ;
```

Use triggers for: rules a `CHECK` can't express (it needs another table), audit logs, keeping a summary table in sync. Avoid hiding core logic in them; they're invisible to someone reading the PHP.

**Events** (MySQL's scheduler) run SQL on a timer, for example nightly cleanup of abandoned runs.

## 16. Security and integrity
_Silberschatz ch. 4, 9_

- **Users and privileges:** give each program only what it needs (least privilege).

```sql
CREATE USER 'ati_app'@'localhost' IDENTIFIED BY '...';
GRANT SELECT ON ati.* TO 'ati_app'@'localhost';
GRANT INSERT, UPDATE, DELETE ON ati.run TO 'ati_app'@'localhost';
GRANT EXECUTE ON PROCEDURE ati.sp_finish_series TO 'ati_app'@'localhost';
REVOKE DELETE ON ati.run FROM 'ati_app'@'localhost';
```

- **Roles** (MySQL 8): `CREATE ROLE`, grant privileges to the role, grant the role to users.
- **SQL injection:** never paste user input into SQL text. Use **prepared statements** (PDO in PHP):

```php
$stmt = $pdo->prepare('SELECT * FROM run WHERE session_token = :t');
$stmt->execute([':t' => $_COOKIE['run_token']]);
```

- Views can limit which rows and columns a user sees.

## 17. Exam checklist

- [ ] Draw an ER diagram with cardinalities, participation, a weak entity and an M:N; map it to tables.
- [ ] Define superkey, candidate key, primary key, foreign key; give one of each from a schema.
- [ ] Write a query in relational algebra and in SQL; know division.
- [ ] Compute an attribute closure X⁺ and use it to find candidate keys.
- [ ] Find the canonical cover of a set of FDs.
- [ ] Say which normal form a table is in, and decompose it to 3NF and to BCNF; check lossless join and dependency preservation.
- [ ] Write SELECTs with joins (inner, left, self), GROUP BY/HAVING, subqueries (correlated, EXISTS), CTEs, a window function.
- [ ] Write INSERT/UPDATE/DELETE, including INSERT … SELECT and an upsert.
- [ ] Explain ACID with an example; name the four anomalies and the four isolation levels.
- [ ] Draw a precedence graph and decide whether a schedule is conflict-serializable; explain 2PL and deadlock.
- [ ] Explain B+ tree vs hash index, clustered vs secondary, composite and covering indexes; read an `EXPLAIN`.
- [ ] Write a stored procedure with a transaction and an error handler, and a BEFORE trigger.
- [ ] Explain least privilege and SQL injection; write a prepared statement.
