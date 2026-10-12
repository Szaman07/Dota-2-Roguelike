# Game outline: A Dice-Based Tournament Roguelike Deck Builder

_Draft for review, 2026-10-11. Built from the settled design in [game_design.md](../research/game_design.md) (revision 5) and project memory. Nothing here changes a decision Sadman made. Where a rule wasn't decided, it's marked **DEFAULT** (my starting value, easy to change) and listed in [open_questions.md](open_questions.md). Numbers marked **KNOB** are tuning values to be set by the balance script once real data is loaded._

---

## 1. One-paragraph pitch

Draft an all-time Dota 2 team from 15 years of pro history, then take it through a full TI. Each pack is an org (Liquid, Secret, Spirit...) offering five era cards of its players and five random heroes, and you take exactly one. Ten picks later you have five players and five heroes. You enter a 16-team International against real winning and finalist rosters of tier-1 events, each playing the actual draft from its final. Every game is simulated with fight-based 2d6 dice that care about lanes, teamfights, pickoffs, Roshan, scaling, counters and chemistry. Losing group games gives you more picks to rebuild; winning upper-bracket series lets you upgrade a player to their prime. One life, no unlocks, no accounts. Win the grand final and you've won TI.

## 2. Pillars

1. **Dota knowledge beats arithmetic.** Lanes, counters, disables and hero-position fit matter, so an Immortal player drafts better than someone reading ratings.
2. **Real history.** Every number comes from real pro games (OpenDota) and real placements (Liquipedia). Nothing is invented except the hero-trait table, which two Immortal players hand-check.
3. **Upsets stay possible.** Dice, Bo1 groups and double elimination: a strong team usually wins, a weak team sometimes does.
4. **Short runs.** A run is 10 draft picks plus 7 to 15 games; the sim is instant and replays are skippable.
5. **The database does the work.** Ratings, chemistry, mastery, standings and the bracket are SQL (see [dbms_coursework_map.md](dbms_coursework_map.md)).

## 3. Run structure at a glance

```
Home ─► Settings (difficulty, hero allocation) ─► Draft: 10 packs (5 players + 5 heroes)
   ─► Team screen (roles, heroes, scores)
   ─► Group stage: 7 Bo1 games (2 groups of 8)      after each game: loss = 2 picks, win = 1 pick
   ─► Playoffs: double elimination (UB Bo3, LB Bo1 then Bo3, GF Bo5)
          UB series win = 1 variant upgrade · the UB loss that drops you = 2 picks · LB series win = 1 pick
   ─► Result screen (place, roster, record, PNG card)
```

## 4. Content

### 4.1 Player cards (era cards)
- **Who gets cards:** players with games in Liquipedia tier-1 events (the pool), joined to OpenDota games through the alias table. **DEFAULT:** at least 150 tier-1 + professional games in the window to get a card.
- **Eras (decided):** `window = GREATEST(3 years, career_length / 3)` from each player's debut; a short last window merges into the previous one; **max 3 cards** per player. A 4-year career is 1 card.
- **Each card shows:** the player's name only (no years in the name, so two cards of one player are both just "Ceb"), a description line with the era years and orgs ("2016–2019 · OG"), rating (68–99), main role and **alternate roles** (see §6.3) (from estimated positions in that window), top heroes with games, orgs played for in that window.
- **Rating (decided ingredients, weights DEFAULT):** percentile mix of win rate (pulled toward 50% for small samples, k = 50), peak (best rolling 100-game win rate in the window), consistency **including longevity** (half steadiness: 1 − spread of per-event win rate; half longevity: how many tier-1 events the player attended and finished top 4 at, so a one-off winner who then missed the next tier-1 events or retired ranks below someone who kept finishing 3rd; Sadman, 22:07) and placements (points per finish × event weight, summed over the best 5 events, so five 3rd places outscore one title), weighted 30 / 25 / 15 / 30, then mapped to 68–99 by a curve (`68 + 31 × percentile^γ`, γ ≈ 1.3 puts the median near 80) so most cards are draftable. Prototype values: Ceb 95 then 83, Puppey 98 then 84 (from game_design.md §6). The curve is the main KNOB.
- **Era factor:** removed (decided). Every card plays at its own level.

### 4.2 Heroes
- All current heroes (127 in OpenDota's list today). Hero facts come from dotaconstants (attack type, range, roles) and the Dota 2 Wiki (stuns, silences, roots, hexes...), which describes the **current patch** only.
- **Hero traits table (curated):** disables, teamfight ult, mobility, lane strength, early power, scaling, summons/push, save. Pre-filled from data (see `data/processed/hero_traits_prefill.csv`), corrected by hand.
- **Hero-position fit (chosen):** share of the hero's pro games at the slot: ≥ 25% normal, 8–25% flex bonus, 2–8% neutral, < 2% penalty, < 50 games neutral.

### 4.3 Packs
- **A pack is an org** (an `org` groups OpenDota team_ids across rebrands). **DEFAULT:** the pack offers 5 random distinct players who played ≥ 30 games for that org (each shown as the era card covering their time there; if two of their cards overlap that time, one is picked at random) plus **5 random heroes** from the whole pool (decided: random).
- Packs are **not era-limited** (decided).
- **Rerolls:** 0 / 1 / 2 per run by difficulty (Hard / Normal / Easy). A reroll redraws the current pack.
- **DEFAULT:** an org with fewer than 5 eligible players shows what it has; orgs with fewer than 3 are not drawn.

### 4.4 The field (opponents)
- **Pool (decided):** winners and finalists of Liquipedia tier-1 events. A roster = the 5 players who played the final (identified by players, not team_id, because team ids are sometimes mislabeled).
- **Deduplication:** lineups sharing 4+ players within 2 years count as one roster (the latest or the title-winning version is kept). Today's pull gives 142 distinct rosters from 159 candidate events (80 with a title) before Liquipedia's list is used; see [audit.md](audit.md) §2.
- **Each pool roster plays its real final draft:** for every game it played in that final, the 5 heroes on the 5 players. Each time it plays you, one of those games is chosen at random (seeded).
- **Ratings for AI players:** the era card covering the final's date.
- **Chemistry:** none for AI teams (decided). **Hero mastery:** counted for AI players too (they really played those heroes). DEFAULT.
- **Field size (DEFAULT):** you + 15 rosters, 16 teams in 2 groups of 8. **Seeding (DEFAULT):** TI-winning rosters are top seeds, spread across both groups; you're placed by team rating among the rest, snake-seeded.
- **Field rules (DEFAULT):** no two rosters in one field share 3+ players; a player may appear in one AI roster and on your team at the same time (it's an all-time event).

## 5. Screens

Each screen lists what it shows, what the player can do, and what it reads and writes in MySQL. "Run" = the row in `run`.

| # | Screen | Shows | Actions | DB |
|---|---|---|---|---|
| 1 | **Home** | Title, "New run", "Continue run" (if one is in progress in this browser), How to play, Credits (OpenDota, Liquipedia CC-BY-SA, Dota 2 Wiki CC-BY-SA, Valve fan-content notice) | Start / continue | Reads `run` by session token |
| 2 | **Settings** | Difficulty (rerolls 0/1/2), hero allocation (auto / manual), seed (shown, optional "enter a seed" for replaying a run) | Start run | INSERT `run` (seed, settings, status = drafting) in one transaction |
| 3 | **Draft** | Current pack: org name and logo-free badge, 5 player cards, 5 heroes; your 5 slots and 5 hero slots; live team preview (rating, mastery, chemistry, team scores); rerolls left; pick count n/10 | Take a player or hero; reroll | INSERT `run_pack`, `run_pack_option`; INSERT `run_card` on pick; UPDATE `run.rerolls_left` with a CHECK ≥ 0, all inside a transaction with the run row locked |
| 4 | **Team** | Roles (pos 1–5), hero per player, per-player mastery (games on hero), hero-position fit tags, chemistry groups, team scores (lanes, teamfight, pickoff, early, late, disables), bench | Swap heroes between players (manual mode), move a player to another role (off-role penalty shown), swap a bench card in | UPDATE `run_card` slots; the slot rule (one card per slot) is a UNIQUE key so two tabs can't create two pos 1s |
| 5 | **Group table** | Both groups with standings (W–L, games left), your next opponent | Play next game, view schedule | Reads the `v_group_standings` view |
| 6 | **Pre-game** | Opponent's roster, ratings and the draft they'll play (decided: shown before each game), predicted lane matchups and counter edges, your lineup | Rearrange (as on screen 4), Play | Reads `pool_roster_game` for the chosen draft; INSERT `run_game` with its seed **before** simulating |
| 7 | **Game replay** | Laning results per lane (with draw zones), each fight (teamfight / pickoff / Roshan) with both dice and modifiers, buildings falling, Aegis; skip button | Skip, speed | Reads `run_game_event` rows written by the sim |
| 8 | **Reward pick** (after group games, the upper-bracket loss and LB series wins) | One pack per pick; bench (5 slots) | Take a card onto the bench (replacing one if full), or pass (the pick is gone) | INSERT `run_pack`, `run_card` (location = bench) |
| 9 | **Upgrade** (after UB series wins) | Your players who have another era card, side by side with that card | Swap one player to another of their era cards (up or down) or, if none qualify, take 1 pick instead (DEFAULT) | UPDATE `run_card.card_id` within the same player, logged in `run_upgrade` |
| 10 | **Bracket** | Double-elimination bracket with your path highlighted | Play next series | Reads `bracket_match` (each match points to where its winner and loser go) |
| 11 | **Result** | Final place, run record (games W–L), roster with heroes, champion if not you, "flawless group" / "undefeated" badges, run seed | Download PNG, new run (same settings), new run | UPDATE `run.status = finished`, `final_place` |
| 12 | **Browse (optional)** | Player cards, orgs, pool rosters, hero stats | Search | Read-only queries; good demo material for the course |

## 6. Rules in detail

### 6.1 Draft
- 10 picks, one per pack, and the draft **must end with exactly 5 players + 5 heroes** (Sadman, 2026-10-12): once you hold 5 players, later packs only offer their heroes, and vice versa. A player already on your team (any era card) is disabled (DEFAULT: no two cards of the same player on one team). When all 5 player slots are full, players in later packs are disabled, and likewise for heroes.
- A drafted player goes into their main role if it's open, then an open alternate role, otherwise any open slot with the off-role penalty shown (DEFAULT).
- **Hero allocation:** automatic = try all 120 hero-to-player assignments and keep the one with the best total team modifier (not raw games, which 322-0 uses and which misses the best synergy 36% of the time); manual = start from the automatic assignment and let the player swap.

### 6.2 Bench and rewards
- **Bench:** 5 slots, players or heroes. Before each game (group) or each series (playoffs), any bench card can swap with an active card of the same kind. When the bench is full, a new card must replace a bench card or be passed. A passed pick is gone.
- **Group stage:** after each game, a **loss gives 2 picks, a win gives 1** (decided). 7 games → 7 to 14 picks.
- **Playoffs:** an **upper-bracket series win gives 1 variant upgrade/swap**; the **upper-bracket series loss** (the only one, since it drops you to the lower bracket) **gives 2 picks** (Sadman, 22:07); a **lower-bracket series win gives 1 pick** (decided). A team that drops to the lower bracket switches to picks. Teams that enter the playoffs in the lower bracket never get the 2-pick drop reward.
- **Upgrade rules:** replace any owned player card (active or bench) with a different era card of the same player, up or down. DEFAULT: if no owned player has another card, the upgrade becomes 1 pick.

### 6.3 Roles
- Dynamic roles (decided): any player can be moved to any slot.
- **Alternate roles (Sadman, 2026-10-12):** each card has a main role plus alternate roles taken from real pro data: a position counts as alternate if it's **≥ 15% of that card's matches** (DEFAULT threshold) **or the main role of another of the same player's cards**. Main and alternate roles carry no penalty.
- **Off-role penalty (any role that isn't main or alternate; DEFAULT, experience-scaled):** `penalty = max_pen × (1 − min(1, games_at_pos / 100))` using the player's estimated games at that position in the card's window. `max_pen` is a KNOB (start at −1 on that player's lane and fight contributions).

### 6.4 Team modifiers (what feeds the dice)
All modifiers are small because they compound across about 13 fights (+1 per fight turned a slight edge into 85%+ in the prototype).

| Modifier | Source | Applies to |
|---|---|---|
| **Rating** | Average card rating difference between the two teams × `k_rating` (KNOB; prototype: +5 rating ≈ 62% per game) | every head-to-head |
| **Hero mastery** | Per player `min(1, games_on_hero_in_window / 25)` (322-0's curve), summed, × `k_mastery` | every head-to-head |
| **Chemistry** (your team only) | 322-0 groups rule: pairs, trios, quads, five-stack with weights 1 / 1.6 / 2.2 / 3 × `min(4, games_together / 230)`, capped, × `k_chem`. Games together counted over whole careers via the alias table | every head-to-head |
| **Hero-position fit** | §4.2 thresholds per player | lane check for that player's lane, and fights |
| **Lane** | Lane matchup data (gold at 10 min for those exact heroes since 2024, pulled toward neutral for small samples), falling back to hero lane strength and the melee/ranged duo rule | laning checks |
| **Teamfight score** | Count of teamfight ults through a curve: 0 → penalty, 1–2 → bonus, 3+ → no extra | teamfight checks |
| **Pickoff score** | Disables of pos 4 + pos 5 + mid, adjusted by mid mobility (Sadman's rule: no-disable support duo with an immobile mid is "cooked") | pickoff checks |
| **Early / late** | Sum of early-power and scaling traits (or win rate by game length) | early score in rounds 1–5, scaling ramps in from round 10 |
| **Counters** | Sum of hero-vs-hero numbers over the 25 cross pairings (pro games since 2024, shrunk toward neutral), turned into a small ± | teamfight and pickoff checks |
| **Off-role** | §6.3 | that player's lane and fights |
| **Aegis** | +2 on the next fights after a Roshan kill | fights |
| **Comeback** | Small bonus to the team behind in buildings | fights |
| Rock-paper-scissors archetype edges | **Removed** (current default; see open questions, since memory and the design doc disagree on its status) | — |

### 6.5 Match sim (fight-based 2d6, settled in revision 4)
1. **Laning:** three head-to-heads (your safe lane vs their off lane, mid vs mid, your off lane vs their safe lane). Both teams roll 2d6 + modifiers. If the totals are within the lane's **draw zone**, the lane is a draw. DEFAULT: the zone is wider when both sides are passive laners and narrower with a lane bully. Mid counts 50%, each side lane 25%. The team ahead overall gets a bonus on its first push and first few fights; even laning carries nothing.
2. **Rounds:** each later round is one head-to-head fight: **Roshan** when he's up (from round 4, and 2 rounds after each kill), otherwise a **teamfight (~57%)** or a **pickoff (~43%)**. Teamfight-heavy drafts get their bonus in teamfights, pickoff-heavy drafts in pickoffs.
3. **Buildings:** the fight winner makes a **solo** 2d6 roll against a target for the next enemy building (T1 → T2 → T3 → Barracks → Ancient); a very high roll takes two.
4. **End:** the first Ancient to fall loses. Prototype: median 13 fights, laning winner wins 66%, badly built team (−2 everywhere) wins 13%.
5. **Determinism:** every game has a stored seed; the same seed and the same lineups always replay the same game. The event log is stored so the replay screen just reads it.

### 6.6 Tournament format (DEFAULTS where marked)
- **Groups:** 2 × 8, Bo1 round robin, 7 games per team (DEFAULT Bo1). The other 14 teams' group games are simulated too (56 games in total).
- **Tiebreakers (DEFAULT):** wins → head-to-head result → seeded coin flip. No tiebreaker games.
- **Bracket:** places 1–4 of each group to the upper bracket (8 teams), 5–6 to the lower bracket (4 teams), 7–8 out.

| Round | Series | Format |
|---|---|---|
| UB quarterfinals | 4 (A1–B4, B2–A3, B1–A4, A2–B3) | Bo3 |
| LB round 1 | 4 (LB seeds vs UB quarterfinal losers) | **Bo1** |
| UB semifinals | 2 | Bo3 |
| LB round 2 | 2 | Bo3 |
| LB round 3 | 2 (LB R2 winners vs UB semifinal losers) | Bo3 |
| UB final | 1 | Bo3 |
| LB round 4 | 1 | Bo3 |
| LB final | 1 (vs UB final loser) | Bo3 |
| Grand final | 1 | Bo5 |

18 series in total. Your longest possible run: 7 group games + 6 lower-bracket series + the grand final. Prototype odds (2 groups of 8, from ti_mode_audit.md): an even team wins about 12% of runs, ~26% if picks make it stronger.

### 6.7 Winning, losing, records
- Place is computed from where you were eliminated (1st, 2nd, 3rd, 4th, 5–6th, 7–8th, 9–12th, 13–16th).
- Badges: **Flawless group** (7–0), **Undefeated champion** (no game lost anywhere).
- No accounts or leaderboard (decided). Runs are kept per browser session token; the result card downloads as a PNG.

## 7. Data the game needs (summary; full detail in [data/README.md](../../data/README.md))

| Game feature | Built from |
|---|---|
| Era cards, ratings, positions | OpenDota tier-1 + professional player rows (2012–2026), Liquipedia placements, alias table |
| Hero mastery | Same player rows, per card window |
| Chemistry | Same player rows, same match and same side, grouped through the alias table |
| Hero-position shares, lane matchups, counters | Pro player rows since 2024 (lane role, gold at 10 min) |
| Hero traits | dotaconstants + Dota 2 Wiki mechanic lists + hand checks |
| Pool rosters and their final drafts | Liquipedia tier-1 placements (1st/2nd) + OpenDota final matches |
| Orgs and packs | OpenDota teams + a hand-checked org table |

## 8. Out of scope (decided)
Accounts, leaderboards, coins, shops, items, gold, unlocks, meta-progression, live API calls during play, Valve art beyond what the fan-content policy allows.

## 9. Possible stretch goals (not decided; listed only)
- A daily seed everyone shares.
- An "Esports history" browser (cards, orgs, rosters) as a second front end for the course demo.
- A 1v1 mode for the teammate's matchup module.
