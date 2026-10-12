# Project proposal: A Dice-Based Tournament Roguelike Deck Builder

**Course:** CSE311 / CSE311L Database Management Systems, North South University
**Team:** Sadman (and teammate) · **Stack:** PHP + MySQL · **Date:** October 2026 (draft)

---

## 1. Summary
A web app game where you build a team of real professional Dota 2 players, then take it through a fully simulated tournament. Every run is different: you pick your team one card at a time from random packs, and each match is decided by dice rolls boosted by how well your team was built. All player strengths, hero pairings and match-ups come from real professional match records stored in a MySQL database, so the database isn't a side part of the game; it's what the game runs on.

## 2. Why this project
- We both play Dota 2 at a high level, so we can judge whether the game's rules feel right.
- The idea needs a real data model: thousands of players, heroes and past matches, plus the live state of every game in progress. That makes it a good fit for a database course.

## 3. How the game is played

**Dota 2 in one paragraph.** Two teams of five players fight on one map. Each player controls one *hero* (a character with its own abilities). Each team has a base protected by towers; the first team to destroy the other's base wins.

### 3.1 Build your team (the deck)
1. You open **10 packs**. Each pack is a real pro team: it shows 5 of its players and 5 random heroes.
2. From each pack you keep **one card**, a player or a hero. The draft must end with **exactly 5 players and 5 heroes**: once you have 5 of one kind, later packs only let you take the other kind.
3. Each player has a **rating** (68–99), a **main role** (one of five positions) and usually one or two **alternate roles**: positions that player really played in pro matches. A player can fill an alternate role with no penalty; any other role costs a small penalty. You decide which hero each player uses.
4. Your team gets bonuses for good building: players who have played a lot on their hero, players who have played many matches together, and heroes that work well together (for example, enough heroes that can stun enemies).

### 3.2 The tournament
- **16 teams:** you and 15 real winning or finalist teams from past tournaments, each using the exact heroes it used in its final.
- **Group stage:** 2 groups of 8; you play the 7 teams in your group once each. The top 4 go to the upper bracket, 5th and 6th to the lower bracket, the bottom 2 are out.
- **Playoffs:** double elimination (a loss in the upper bracket drops you to the lower bracket; a loss in the lower bracket ends your run). Matches are best of 3, the final best of 5.
- **Rewards between matches**, so a team keeps improving during the run:

| Result | Reward |
|---|---|
| Group-stage loss | 2 new cards (a catch-up bonus) |
| Group-stage win | 1 new card |
| Upper-bracket series win | Upgrade one of your players to a stronger version of that player |
| The upper-bracket loss that drops you down | 2 new cards |
| Lower-bracket series win | 1 new card |

New cards go to a **bench of 5 slots**. Before any match you can swap bench cards in, and you always see the opponent's heroes first, so you can counter them.

### 3.3 How a match is decided: double dice
Every contest is a roll of **two six-sided dice (2–12) plus bonuses**. Bonuses are small (usually −2 to +2), so a weaker team can still win with a lucky roll.

| Phase | What happens | Who rolls |
|---|---|---|
| **1. Lanes (early game)** | Three one-on-one contests, one per lane (top, middle, bottom). The middle lane counts most. Close totals are a draw | Both teams roll; higher total wins |
| **2. Fights (mid and late game)** | Each round is randomly a **team fight** (all 10 heroes) or an **ambush** (catching one enemy alone). Teams built for fights or ambushes get bonuses in that kind of round | Both teams roll |
| **3. The boss** | From round 4 a neutral boss monster appears; the team that wins the roll for it gets +2 on its next fights | Both teams roll |
| **4. Objectives** | The winner of each fight rolls alone against a target number to destroy the next building: outer tower → inner tower → base tower → barracks → the main base. A very high roll takes two buildings | Fight winner only |

**The first team to destroy the other's main base wins.** A typical match lasts about 13 rounds. Teams that start weak but grow strong get their bonus in late rounds; aggressive teams get theirs early.

**Example roll:** your team fight bonus is +1 (two heroes with big area stuns), the opponent's is 0. You roll 4 + 3 = 7, plus 1 = 8. They roll 5 + 4 = 9. They win the fight and roll alone for your outer tower: 6 + 5 = 11, enough to take it.

## 4. Objectives
1. Design a normalized MySQL database for players, heroes, past matches and live game state.
2. Import public match data once, clean it, and compute every game number (ratings, bonuses, match-ups) with SQL.
3. Build the web app in PHP: drafting, team management, group table, bracket, match replay and results.
4. Keep game state correct when a page is refreshed, a button is double-clicked or the game is open in two tabs.

## 5. Database sneak peek
The database has three parts. Most tables are small; one table of past match records is large.

| Part | What it stores | Example tables | Who writes it |
|---|---|---|---|
| **Reference data** | Heroes, players, teams, tournaments, past pro matches | `hero`, `player`, `team`, `pro_match`, `match_player` | Import script, once |
| **Computed data** | Player ratings, games played on each hero, games two players played together, hero vs hero results | `player_card`, `card_hero`, `player_pair`, `hero_matchup` | SQL run after import |
| **Game state** | Your run, the packs you saw, your cards, the 16 teams, every match and every dice roll | `run`, `run_pack`, `run_card`, `run_team`, `series`, `game`, `game_event` | The web app, while you play |

**Example tables (simplified):**
```
player      (player_id PK, name, country)
hero        (hero_id PK, name, attack_type)
player_card (card_id PK, player_id FK, rating, main_role)
card_role   (card_id FK, role, matches, kind)               -- kind = main or alternate
card_hero   (card_id FK, hero_id FK, games, wins)          -- PK (card_id, hero_id)
run         (run_id PK, seed, status, rerolls_left)
run_card    (run_id FK, card_id FK or hero_id FK, slot)    -- one card per slot
series      (series_id PK, run_id FK, team_a FK, team_b FK, winner FK,
             next_series_if_win FK, next_series_if_loss FK)  -- the bracket points to itself
game_event  (game_id FK, step, phase, roll_a, roll_b, result)
```

**What the app reads and writes:**

| Player action | Reads | Writes |
|---|---|---|
| Opens a pack | Team's players and ratings, random heroes | `run_pack` (what was shown) |
| Picks a card | The pack | `run_card` |
| Looks at the team screen | Hero experience, pairs who played together, hero match-ups | Nothing |
| Plays a match | Both line-ups and their bonuses | `game` (seed saved first), `game_event` (every roll) |
| Wins a series | Bracket | `series` (winner moves on, loser drops down) |

**Database ideas the project uses:**
- **Keys and constraints:** a slot can hold one card; a player can't be on your team twice; a dice total must be 2–12. The database rejects bad data even if the app has a bug.
- **Joins and grouping:** "games two players played together" is one table joined with itself on the same match and same side, then counted.
- **Window functions:** ratings come from ranking players against each other, and the group table ranks teams by wins.
- **Transactions:** finishing a series updates the winner, moves both teams to their next match and saves the reward together, or not at all. The random seed is stored before a match is played, so refreshing can't re-roll a loss.
- **Normalization:** the imported data repeats team names on every match and splits some players across several accounts; we split these into proper tables.

## 6. Scope
**In:** the draft, the bench, the 16-team tournament, dice matches with replays, rewards, a result screen.
**Out:** user accounts, leaderboards, payments, in-game items, a mobile app.

## 7. Data
Public professional match records from 2012 to 2026 (about 227,000 matches) and public hero information, downloaded once and stored in MySQL. The game never contacts outside services while you play. Sources are credited in the app and the report.

## 8. Timeline (dates follow the semester calendar)

| Phase | Work | Output |
|---|---|---|
| 1 | Final rules, ER diagram, normalization | Approved schema |
| 2 | Import and clean the data | Filled reference tables |
| 3 | Ratings, bonuses and the draft screen | Playable draft |
| 4 | Tournament, dice matches, rewards | Full run playable |
| 5 | Balance and testing | Test log |
| 6 | Report and demo | Final submission |

## 9. Risks

| Risk | Plan |
|---|---|
| One player has several accounts, or a team changed its name | Small hand-checked tables that link them |
| One strategy wins too often | Play thousands of automatic runs and adjust the bonuses |
| Too much work | First milestone is one group and a short bracket |

## 10. Deliverables
The working web app, SQL scripts (tables, data import, queries), ER diagram, report and demo.

## 11. Credits
Match data from OpenDota; tournament results from Liquipedia (CC-BY-SA); hero information from the Dota 2 Wiki (CC-BY-SA). Inspired by 82-0.com and 322-0.app. Dota 2 is a trademark of Valve Corporation; this is a non-commercial student project.
