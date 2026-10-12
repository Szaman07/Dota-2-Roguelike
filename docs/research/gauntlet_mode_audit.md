# Gauntlet mode audit: a Balatro / Gambonanza-style run against historic TI bosses (research only)

_**Superseded in part (20:20 UTC):** Sadman chose roguelike with no unlocks, no shop or items, L1 bosses, no multi-phase bosses and a phase-based dice sim. The current design is in [game_design.md](game_design.md); this file is kept for the options and fact checks._

_Date: 2026-10-11, 19:45 UTC. Responds to Sadman's idea in the "Gauntlet" thread. Builds on [322-0_teardown.md](322-0_teardown.md), [rating_and_roles.md](rating_and_roles.md), [team_synergy.md](team_synergy.md) and [base_game_readiness.md](base_game_readiness.md). Tags: VERIFIED = checked live (OpenDota explorer, this session), INFERRED = follows from evidence, OPINION = my honest take. All decisions are Sadman's._

---

## 0. Honest take (OPINION)

**It's a good idea, and it fixes 322-0's weakest part.** In 322-0 the whole draft leads to one random TI sim, which you watch and can't affect. A gauntlet gives the draft a reason to keep mattering: you face known opponents in order, you adapt between fights, and each boss tests a different part of your team (lanes, teamfight, pickoff, scaling). That's exactly the composition scores you already designed, so they finally get used as gameplay rather than just a number at the end.

**It merges cleanly with the base game.** Almost nothing in the base game is thrown away (§2). The draft, ratings, chemistry, hero synergy and team scores are the engine; the gauntlet replaces only the "simulate TI" ending.

**The real risk is scope, not feasibility.** A shop, items, boss modifiers and balancing are a second game on top of the first. It's very doable if the content is kept small at first (§8).

**Two facts in the list need fixing** before anything else (§4): TI1 (2011) has **no match data** in OpenDota, and the list has **7 teams**, not 5.

---

## 1. Roguelike or roguelite?

| | Roguelike | Roguelite |
|---|---|---|
| Meaning | Each run starts from zero; nothing carries over except knowledge (and usually unlocks). | Some power carries over between runs (permanent upgrades, currency, stronger starts). |
| Balatro | **Roguelike** with unlocks: new jokers, decks and stakes unlock, but no run starts stronger. | |
| Gambonanza | A chess roguelike: start with 3 pieces, lost pieces stay lost for the run, 5 stages of growing boards and bosses, up to 5 "Gambits" (its jokers) equipped, a reserve bench for spare pieces. ([Pocket Gamer](https://www.pocketgamer.com/gambonanza/review/), [GamingOnLinux](https://gamingonlinux.com/2026/05/gambonanza-masterfully-combines-balatro-and-chess-and-its-out-now)) | |
| Fit here | Clean and easy to balance; each run is fair. | More "sticky" but needs persistent accounts and power tuning. |

**Options:**
- **R1. Pure roguelike.** Nothing persists except run history and the leaderboard.
- **R2. Roguelike with unlocks (Balatro's model).** Beating bosses unlocks new team packs, items, boss difficulty "stakes", and the secret boss. No run starts stronger.
- **R3. Roguelite.** Permanent upgrades (e.g. +1 starting reroll, a starting relic) bought with a meta currency.

R2 gives the most database value for the least balancing: unlocks are a per-user table with real queries ("which packs can this user draw?"), and nothing breaks the balance.

---

## 2. How it merges with the base game

| Base game piece | Role in the gauntlet |
|---|---|
| Team packs (`roster_entry`: one team at one event) | Your booster packs in the shop, **and** your opponents. An underling is just a pack; a boss is a TI-winning pack with a modifier. Same table. |
| Composite player rating, era cards (max 3) | Card strength. Era cards matter more: Yatoro's 2021, 2023 and 2026 cards could all appear as Spirit boss phases. |
| Hero mastery, hero-position fit | Same scoring. |
| Chemistry (2–5 groups) | Same scoring, and a reason to buy packs from one org. |
| Team scores (stuns, pickoff, scaling, early, teamfight, lanes) | **Become the gameplay**: each boss modifier tests one of them (§5). |
| Rerolls (0/1/2) | Become a shop action costing gold. |
| TI sim | Replaced by series against each opponent. Classic (draft + TI sim) can stay as a quick mode on the same code. |
| Parked rock-paper-scissors layer | Fits naturally later: bosses could be given archetypes. Not needed now. |

**Merge options:**
- **M1. Draft, then gauntlet.** Do the 322-0 style 10-pick draft as the run's opening, then fight. The shop between fights lets you swap players, add heroes and buy items. Most code reuse.
- **M2. Small start, build through the shop (Gambonanza style).** Start with a weak random roster of 5 and a few heroes; every improvement comes from shop packs. Most Balatro-like, but more balancing.
- **M3. Two separate modes** (Classic and Gauntlet) sharing data and scoring, with no shared run flow.

---

## 3. Core loop and economy (Balatro → Dota mapping)

### Run structure
Balatro has 8 antes × 3 blinds (small, big, boss) = 24 fights. The idea maps almost exactly: **6 acts (5 bosses + final) × (3 underlings + 1 boss) = 24 series**, plus the secret boss. That's a natural run length (INFERRED from Balatro runs: roughly 30–60 minutes).

| Balatro | Gauntlet |
|---|---|
| Ante | Act (an era, led by its boss) |
| Small / big blind | Underling series (e.g. Bo1, Bo3, Bo3); can be skipped for a reward like Balatro's tags |
| Boss blind | Boss series (Bo3, final Bo5) with a modifier |
| Hand (chips × mult) | One game: your team rating plus composition scores vs the opponent's |
| Deck | Your roster plus hero pool |
| Jokers | **Relics** (max 5 slots, like Gambonanza's Gambits): permanent effects for the run |
| Tarot / planet cards | **Consumables** (runes, one-shot) and **patch notes** (permanently level up one team score) |
| Vouchers | **Battle pass upgrades**: permanent for the run (extra shop slot, cheaper rerolls, +1 relic slot) |
| Money + interest | **Gold**: earned per win, bonus for sweeps; interest of 1 per 5 held, capped |
| Lose a blind = run over | Lose a series = run over (an Aegis relic could give one extra life) |

### Hero pool as a "deck" (a strong Dota fit)
Instead of exactly 5 heroes, you own a **hero pool** (e.g. 7–10). Each game, your 5 heroes are drafted from the pool, and the opponent **bans** some. That's very Dota and very Balatro (deck → hand). Ban data exists: VERIFIED, OpenDota has pick/ban data for TI 2013, 2015, 2016 and 2026 (3,240 / 8,139 / 7,940 / 3,528 pick-ban rows), but **none for TI 2012**. So a boss could ban the heroes it really banned most at its TI.

### Shop between fights
- **Packs:** a team pack (pick 1 player or hero), priced by era or rarity.
- **Sell:** players, heroes and relics for gold.
- **Reroll shop:** gold cost that rises each use (Balatro: $5, +$1 each).
- **Bench (Gambonanza's reserve):** 1–2 spare players, swappable between fights.

### Relic ideas (Dota items as jokers; OPINION, for tuning)
| Relic | Effect |
|---|---|
| Hand of Midas | +1 gold interest cap |
| Aghanim's Scepter | Doubles your highest team score's effect |
| Black King Bar | Ignores the next boss modifier for one game |
| Aegis | One extra life (consumed on a series loss) |
| Divine Rapier | Big rating boost; lost if you drop a game |
| Refresher Orb | Replay one lost game per act |
| Gem of True Sight | See the boss modifier and bans before the shop |
| Smoke of Deceit (consumable) | The opponent bans nothing next game |

Balatro works because jokers **multiply** each other. Some relics need to be multiplicative (×1.2 to a score) rather than flat (+2), or late acts feel flat.

### Win model options
- **W1. Deterministic threshold (Balatro):** your game score must beat the opponent's target. Fair, no luck once the team is built.
- **W2. Probabilistic (322-0):** win chance from the rating gap (322-0 uses 1/(1+10^(−Δ/22))). Feels like Dota, but a run-ending loss to bad luck feels unfair in a 24-series run.
- **W3. Hybrid:** deterministic score plus a small random swing, with the win chance shown before the series.

---

## 4. The boss list: cleaned up and fact-checked

### As written, in chronological order
| Slot (as you wrote it) | Team | TI | Year | Check |
|---|---|---|---|---|
| Boss 1 | Natus Vincere | TI1 | 2011 | ✅ correct winner, ⚠️ **no data** (see below) |
| Boss 2 | Alliance | TI3 | 2013 | ✅ VERIFIED: final vs Na'Vi, 12 Aug 2013 |
| Boss 3 | Evil Geniuses | TI5 | 2015 | ✅ VERIFIED: final 9 Aug 2015 (SumaiL, Aui_2000 among the winners) |
| Boss 4 | Wings Gaming | TI6 | 2016 | ✅ VERIFIED: final 14 Aug 2016 |
| Boss 5 | Team Liquid | TI7 | 2017 | ✅ VERIFIED: final vs Newbee, 13 Aug 2017 (Miracle-, MinD_ContRoL, KuroKy, GH, MATUMBAMAN) |
| Secret | OG | TI9 | 2019 | ✅ VERIFIED: final vs Liquid, 25 Aug 2019 |
| Final | Team Spirit | TI15 | 2026 | ✅ VERIFIED: TI 2026 grand final 23 Aug 2026, Spirit 3–2 TEAM VISION. Winning lineup in OpenDota: Yatoro, Larl, Collapse, rue, not_me. This is after my training data, so it rests on OpenDota alone. |

### Problems
1. **TI1 (2011) has no data.** VERIFIED: OpenDota's earliest match is 28 May 2012, and there's no TI 2011 league. Options: (a) hand-enter Na'Vi 2011 (Dendi, Puppey, XBOCT, ArtStyle, LighTofHeaveN) with hand-set ratings and no hero stats; (b) use **Na'Vi at TI 2012** (runner-up, same core, data exists: VERIFIED, 154 matches, final vs iG on 3 Sep 2012); (c) use **iG, the TI2 (2012) winner**.
2. **It's 7 teams, not 5:** 5 bosses + final + secret. Fine, but it means 6 acts (24 series) plus a secret fight.
3. **A big gap:** bosses 1–5 are all 2011–2017, then the final jumps to 2026. TI8–TI14 (OG, Spirit TI10, Tundra, Spirit TI12, Liquid TI13, Falcons TI14) only appear as the secret boss or not at all. Missing earlier winners: **iG (TI2 2012)** and **Newbee (TI4 2014)**.
4. **Spirit won three TIs** (2021, 2023, 2026; VERIFIED from the finals). The final boss could be a **three-phase Spirit** (TI10 → TI12 → TI15), with Yatoro and Collapse on all three. OG won **two** (2018 and 2019, VERIFIED), so the secret boss could be OG TI8 then OG TI9.
5. **Underling eras:** "Gaimin 2022" probably means **Gaimin 2023** (their peak; they reached the TI 2023 and TI 2024 finals, VERIFIED). Gaimin's 2022 roster was newly formed (INFERRED, please confirm). Secret 2020 and VP 2017 fit their eras.
6. **Old-era names and teams are messy in the data (VERIFIED):** today's team names overwrite history, so EG's TI5 final shows as "Shopify Rebellion", CDEC as "GGGGGGGG", Digital Chaos as "123" and Wings as "the wings gaming". Most TI 2012–2015 players have no name in `notable_players` (only account ids), and even OG's TI9 roster is mostly unnamed. This confirms the `org` and `player_account` alias tables from the readiness doc, hand-filled for every boss.
7. **No lane data before 2016**, so positions for Na'Vi, Alliance and EG need hand-setting.

### Layout options
- **L1. Your list, chronological** (above). Underlings come from each boss's era window (e.g. ±2 years). The 2018–2025 teams only appear in the final act.
- **L2. Even eras.** Six acts that each cover ~2.5 years so every era gets a boss: e.g. Na'Vi 2012, Alliance 2013, EG 2015, Liquid 2017, OG 2019 (no longer secret), Spirit 2021→2026 as the final. A different secret boss (e.g. Wings, the famous one-and-done winners).
- **L3. Random gauntlet (Balatro-style).** Each act's boss is drawn from a pool for that "tier", so runs vary. The fixed list becomes one "classic" gauntlet, and a daily seed can share runs between users.

**Difficulty is a separate dial from chronology.** If ratings are global, 2012 teams may be weaker or have thin data. Act difficulty should come from an **act scaling bonus** on the opponent (like Balatro's rising targets), not from which year the boss is from.

---

## 5. Boss modifiers ("boss blinds")

Each boss tests one of your team scores or a part of your draft. These are suggestions to show the shape; the flavor needs your Dota judgment.

| Boss | Modifier idea | What it tests |
|---|---|---|
| Na'Vi TI1 | **"Old school":** only heroes released by 2012 can be picked by either side | Hero pool depth |
| Alliance TI3 | **"Rat Dota":** low pickoff teams lose extra rating (split-push pressure) | Pickoff score |
| EG TI5 | **"Echo Slam":** your teamfight score counts against you unless you have dispersal (Black Hole, RP etc. punished) or the boss's teamfight is doubled | Teamfight / lane balance |
| Wings TI6 | **"Hero pool":** the boss bans your 3 highest-mastery heroes | Hero pool width |
| Liquid TI7 | **"KuroKy's five":** the boss's 5-stack chemistry is maxed; yours must beat a threshold | Chemistry |
| OG TI9 (secret) | **"Off-meta":** OG takes no hero-position penalty; yours is doubled | Hero-position fit |
| Spirit (final) | **Three phases** (TI10 → TI12 → TI15), each its own game in a Bo5, a different modifier each | Everything |

**Secret boss unlock options:** beat the final boss without losing a game; or win while holding a specific relic; or a hidden condition such as all 5 players from one era.

---

## 6. Can the data build these rosters?

| Need | Source | Status |
|---|---|---|
| Boss lineups (TI 2012–2026) | OpenDota: winning side of the TI finals | VERIFIED (this session) |
| TI1 2011 lineup | none | ❌ hand-entered only |
| Boss heroes and bans | OpenDota `picks_bans` | VERIFIED for 2013, 2015, 2016, 2026; missing for 2012 |
| Underling rosters | the base game's `roster_entry` (an event's teams) | Same pipeline as packs |
| Player names (old eras) | `notable_players` often blank | Hand alias table |
| Positions before 2016 | no lane data | Hand-set |

---

## 7. Database implications

### New entities (plain English, not a schema)
- **gauntlet**: a named layout (classic, even eras, daily seed).
- **act**: belongs to a gauntlet; order, boss `roster_entry`, boss modifier, series length, scaling bonus.
- **act_underling**: the 3 underling `roster_entry` rows per act (or a rule to draw them by era).
- **modifier**: catalog of boss modifiers (code + parameters).
- **relic / consumable / upgrade**: item catalogs with price, rarity, effect code and parameters.
- **run_item**: what a run owns (relics, consumables, bench players), with slot limits.
- **run_stage**: a run's progress (act, fight, result).
- **series / series_game**: each fight and each game, with the seed, both teams' scores and bans.
- **shop_offer**: what the shop showed at each stop (seeded, so runs can be replayed and audited).
- **gold_ledger**: every gold change (win, interest, purchase, sale).
- **user_unlock**: per-user unlocks (option R2).

### Good SQL and DBMS lessons it creates
| Lesson | Where it shows up |
|---|---|
| **Transactions (ACID)** | Buying in the shop: check gold, debit it, add the item, mark the offer sold, all or nothing. `SELECT … FOR UPDATE` on the run row stops double-click double-buys. This is the best transaction demo in the project. |
| **Constraints** | `CHECK (gold >= 0)`, at most 5 relics (trigger or count check), `UNIQUE(run, offer)` so an offer sells once. |
| **Derived vs stored data** | Gold as `SUM(ledger)` vs a cached balance column kept in sync by a trigger: a classic consistency discussion. |
| **Stored procedures** | `buy_item`, `advance_stage`, `end_run`, so game rules live in the DB. |
| **Triggers** | A series loss ends the run (or consumes the Aegis). |
| **JSON vs normalized** | Modifier and relic parameters: MySQL 8 JSON columns vs separate parameter tables. A good normalization trade-off for the report. |
| **Window functions** | Leaderboards (`RANK()` by acts cleared, gold, games lost), per-act win rates. |
| **Reproducibility** | Seeds on shops and series let a run be replayed exactly. |

---

## 8. Risks

| Risk | Notes and options |
|---|---|
| **Scope** (largest) | A course project is graded on the database, not game balance. One option: build the base game and a small gauntlet first (e.g. 3 acts, ~10 relics, ~5 modifiers), then grow content. Every new relic or modifier is a row plus a small effect function, so content scales well once the engine exists. |
| **Balance** | Needs multiplicative relics or late acts feel flat; needs act scaling so old-era bosses aren't pushovers. A simulation script that plays thousands of auto-runs would show which relics dominate. |
| **Luck** | With 24 series, a probabilistic sim (W2) will end runs on bad luck. W1/W3 or an Aegis-style safety net reduces this. |
| **Data gaps** | TI1 has no data; old names and positions are manual; team names in OpenDota are overwritten by rebrands. All solvable with hand-filled alias and seed tables. |
| **Effect code in PHP** | Relic and modifier effects are code, not just data. Keeping each one small (a function per effect code) avoids a giant if/else. |
| **Your teammate's RPS layer** | Fits well later (bosses with archetypes), but keep it out of the first version as already decided. |

---

## 9. Questions for you

1. **Roguelike or roguelite?** R1 pure / R2 roguelike with unlocks (Balatro) / R3 permanent upgrades.
2. **How should it merge?** M1 draft then gauntlet / M2 small start, build from the shop / M3 separate modes.
3. **TI1 Na'Vi:** hand-entered 2011 / Na'Vi 2012 instead / swap in iG TI2.
4. **Boss layout:** L1 your list / L2 even eras / L3 random per act with a fixed "classic" option.
5. **Spirit and OG as multi-phase bosses** (TI10→TI12→TI15, TI8→TI9)? yes / no.
6. **Win model:** W1 deterministic / W2 probabilistic / W3 hybrid.
7. **Hero pool as a deck with boss bans?** yes / no (keep 5 fixed heroes).
8. **Underlings:** fixed per act, or drawn from the boss's era each run? And did you mean Gaimin 2023?
9. **First version size:** full 6 acts, or a small slice first?
