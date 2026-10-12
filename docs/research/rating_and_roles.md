# Rating, player variants, dynamic roles and hero-position synergy (research only)

_Date: 2026-10-11, 18:25 UTC. Follows Sadman's design direction from the thread on the same day. These are findings and options; every choice stays with Sadman._

**Tags.** VERIFIED means I saw it in a live response, a source file or 322-0's data. INFERRED means it follows from evidence. GUESS means a plausible model with weak evidence.

**What Sadman asked for:**
- One rating that combines win rate, peak window, consistency and tournament placements.
- Ratings tuned so most players aren't irrelevant and legends aren't sunk by one bad event.
- Multiple variants for long-career or role-swapping players.
- Dynamic roles: you can change a drafted player's role.
- Hero-position synergy: flexing a hero that really is played in a position (Gyrocopter as a support) is rewarded, and off-meta placements (Shadow Fiend as a support) are discouraged.

---

## 1. The problem in 322-0's numbers (VERIFIED from its data files)

- Ratings across 3,516 roster entries, by decile: 64 / 67 / 69 / 72 / 74 / 76 / 79 / 81 / 84. **Only 10% of entries are 85 or higher, and 1.7% are 90 or higher.** Since Base is the average of 5 players and "Great" starts at 88, most cards are dead picks.
- Legends at their worst events: **Puppey 64** (Manila 2016), **Yatoro 69** (BLAST Slam VI), **KuroKy 64** (TI 2011), **Ceb 63** (Wallachia S3), **Dendi 67** (TI 2015). Their best are 86 / 93 / 85 / 88 / 85.
- **125 of 586 players** appear in more than one role across packs. N0tail appears as safelane ×6, support ×5, offlane and mid.

---

## 2. Can the free data support positions? (VERIFIED, OpenDota explorer)

- `player_matches.lane_role` (1 safe, 2 mid, 3 off, 4 jungle) is **missing before TI 2016** (TI 2015: 20 of 4,090 rows) and **near-complete from TI 2016 on**. `gold_per_min` exists for every TI back to 2012. (`samples/od_explorer_lane_cov_ti.json`)
- **Position estimate** used below: mid lane = pos 2. In the safe lane, the higher-GPM player is pos 1 and the other is pos 5. In the off lane, the higher-GPM player is pos 3 and the other is pos 4. This is INFERRED and imperfect: it misreads trilanes, roaming supports and lane swaps. Before 2016 the only option is GPM rank within the team (rank 1–5 ≈ pos 1–5), which is noticeably rougher. GUESS
- **Hero spread since 2024** (pro matches; `samples/od_explorer_hero_pos.json`):

| Hero | pos 1 | pos 2 | pos 3 | pos 4 | pos 5 | games |
|---|---|---|---|---|---|---|
| Gyrocopter | 79.3% | 1.0% | 1.2% | **10.9%** | **7.5%** | 8,791 |
| Shadow Fiend | 45.3% | 53.7% | 0.5% | **0.16%** | **0.17%** | 13,680 |

This matches your intuition: Gyrocopter is a real support flex (about 18% of its games at pos 4/5), while Shadow Fiend is core-only (under 0.4% at pos 4/5).

The Valve API has no lane field either, so the same estimate from GPM and lane would apply. INFERRED

---

## 3. Composite rating options

Each component is turned into a **percentile within the same position** (so supports aren't judged against carries' farm), then mixed by weights you choose.

| Component | Option(s) | SQL shape |
|---|---|---|
| **Win rate** | Bayesian-adjusted: `(wins + k·0.5)/(games + k)`, with k ≈ 50 | `GROUP BY player, pos` |
| **Peak window** | Best rolling N-game win rate (N = 100) or best 12-month span | `AVG(won) OVER (PARTITION BY player ORDER BY start_time ROWS 99 PRECEDING)`, then `MAX` |
| **Consistency** | (a) 1 − stdev of per-event win rate; (b) share of events where the player beat their team's expected result; (c) share of events finishing top 8 | per-event `GROUP BY`, then `STDDEV_SAMP` over events |
| **Placements** | Points per finish (e.g. 1st = 100, 2nd = 70, 3–4 = 50, 5–8 = 30…), weighted by event tier (TI > Major > tier-1) | join `event_placement` → `roster`, `SUM(points × tier_weight)` |

**Stopping one bad event from sinking a legend (pick any mix):**
1. **No per-event rating at all.** A card's rating covers a career or a variant (§4), so one event is one input among dozens. This alone fixes "Puppey 64".
2. **Best-N-of-M:** count only a player's best 5 events for placements and consistency.
3. **Shrink toward career:** `variant_rating = w·variant + (1−w)·career`, with w growing with games played. A short or bad stint is pulled toward the career level.
4. **Floor:** a variant can't fall more than X points below the player's career rating.

**Fixing the "90% irrelevant" spread (scaling choices):**
- **Percentile → rating curve.** Map the composite percentile onto, say, 70–99 with a concave curve, so the median player is about 80 and the top 5% are 93+. Unlike 322-0's 64–84 middle, roughly every card is draftable, and greatness still shows.
- **Role-relative.** Percentiles within each position mean the best pos-5 is as valuable as the best pos-1.
- **Minimum-games gate.** Only players with ≥ X pro games (e.g. 200) get cards, which removes low-sample noise at the bottom.

A natural MySQL lesson here: compute the components in a staging table, `PERCENT_RANK() OVER (PARTITION BY pos ORDER BY score)`, then store the final rating. Window functions do the whole job.

---

## 4. Player variants (for long careers and role swaps)

> **Decided by Sadman (18:30 UTC): one card per player per era (a set of years, option B).** Team stints were rejected because journeymen would get too many cards. **Era boundaries decided (18:32 UTC): rolling windows of about 3 years from each player's debut (option 3).** **Decided (18:34 UTC): a short last window merges into the previous one, and no player gets more than 3 cards.** Long careers get longer windows. One rule that does both: `window = GREATEST(3 years, career_length / 3)`. Puppey (about 15 years) gets 3 five-year cards, and someone with a 4-year career gets 1 card (the 1-year remainder merges in). In SQL that's a per-player CTE for career start/end, then `FLOOR((match_date − debut) / window)` capped at 2 as the card index. Options considered: (1) **fixed global eras** shared by everyone, e.g. by game era or TI cycles (one `patch_era` table, so every player's cards line up); (2) **per-player eras** that split a career where the player's role or level clearly changed (gaps-and-islands or change-point logic, more SQL); (3) **fixed-length windows** of about 3 years from each player's debut.

| Option | Split rule | Example | DB lesson |
|---|---|---|---|
| **A. By role** | One card per position where the player has ≥ N games (e.g. 300) | N0tail: carry card and support card | `GROUP BY player, pos HAVING COUNT(*) >= N` |
| **B. By era** | One card per patch era or 2–3-year window with enough games | "Puppey 2013–15", "Puppey 2019–22" | join to a `patch_era` table |
| **C. By stint** | Consecutive runs on one team (or one role), found automatically | Miracle-: Liquid stint vs Nigma stint | **gaps-and-islands**: `ROW_NUMBER()` difference trick over matches ordered by time |
| **D. Hybrid** | Stints, merged when they're too short (< N games) | — | C + a merge step |

These fit your **team packs**: a pack = an org, and it contains the variants that played for that org (option C gives exactly that).

---

## 5. Dynamic roles

- **Data:** `player_position_stats(player, pos, games, wins)`, built from the position estimate in §2.
- **Which roles are allowed** (options): any position with ≥ N games, or with ≥ X% of the player's games, or every position with a penalty.
- **Off-role penalty** (options): (a) flat, e.g. −5 OVR; (b) scaled by experience, `penalty = max_pen × (1 − min(1, games_at_pos / N))`, so N0tail at support pays nothing and Miracle- at pos 5 pays the full penalty; (c) use the player's rating computed **at that position** (from §3) if one exists, falling back to (b).
- **DB lesson:** changing a role is an `UPDATE run_pick SET pos = ?` inside a transaction that re-checks the 1-1-1-2 slot rule (a CHECK constraint or trigger), so two tabs can't create two pos 1s.

---

## 6. Hero-position synergy

Two separate effects, which can be combined:

**6a. Player × hero × position experience** — **dropped by Sadman (18:27 UTC).** The hero-position fit (6b) already penalizes off-meta picks like Lifestealer offlane, so cutting the player's mastery too would penalize twice. Hero mastery stays position-agnostic: a player's total pro games on the hero.
- Count a player's games on a hero **at the position they're slotted in**: `player_hero_pos_stats(player, hero, pos, games)`. A mid who played Faceless Void as a carry years ago gets no synergy for Void at mid. INFERRED that this fully covers the example; it uses the §2 estimate.
- An option is partial credit for other positions (e.g. 25% of off-position games), so flexible players aren't zeroed.

**6b. Hero's own position fit** (Gyrocopter good at support, Shadow Fiend bad)
- `hero_position_stats(hero, pos, games)` → `share = games_at_pos / hero_total`. Formula options:
  1. **Threshold:** share < 1% → penalty; 1–40% → **flex bonus**; > 40% → neutral (a standard pick). With the numbers above, Gyrocopter pos 4 (10.9%) gets the flex bonus and Shadow Fiend pos 4 (0.16%) gets the penalty. VERIFIED that the shares separate cleanly.
  2. **Smooth curve:** `bonus = a·log(share / median_share)`, clamped. That's more nuance, but harder to explain in a report.
  3. **Patch-aware:** compute shares per patch era, so a flex that was meta in 7.3x counts for players from that era. That ties into variants (§4B).
- **Composition check** (also from your example): count how many of the 5 heroes have the same primary position (the max-share position). Options: penalize when 3 or more are primary-pos-1 heroes, or require each slot's hero to have ≥ X% share at that slot for full synergy. That's a simple `GROUP BY primary_pos HAVING COUNT(*) >= 3` on the run's heroes.

**How this changes auto-allocation:** with position in the mix, the best assignment is still a 120-permutation search (5 heroes × 5 slots, since the players' positions are fixed). It's tiny for PHP or a recursive CTE. Manual mode keeps working as it does now.

---

## 7. Tournament placements: free sources

| Option | How | Notes |
|---|---|---|
| **A. Derive from OpenDota matches** | Rank a league's teams by the date of their last match, then break the tie at the top by who won the final match | Tested on TI 2024: Liquid, Gaimin, Tundra, Falcons, then XG / Cloud9, then Aurora / BetBoom. That order **matches the official top 8** (checked against 322-0's datdota placements; 5–6 and 7–8 are tied pairs in both). VERIFIED for one event. Group-stage exits only come out roughly in order. (`samples/od_explorer_placement_proxy.json`) |
| **B. Liquipedia MediaWiki API** | `liquipedia.net/dota2/api.php` | Free for your own projects. Limit: 1 request per 2 s (`action=parse` 1 per 30 s); needs a custom User-Agent with contact info; content is **CC-BY-SA 3.0** (attribute it); scraping HTML pages is not allowed. Their LPDB API needs approval and 60/hour. INFERRED (from a search summary of their API terms page). Liquipedia's robots.txt blocks AI agents like me, so I didn't call it; a script you run yourself, with your own User-Agent, falls under their API terms. |
| **C. Hand-entered** | An `event_placement` table typed in for the events you include (about 20 TIs and Majors × 16–20 teams ≈ 400 rows) | The most accurate. It's also a fine "seed data" story for the report. |

Combining them works: A for the bulk of events, with C overrides for TIs and Majors.

---

## 8. New entities this adds (plain English, not a schema)

match_player gains a derived **pos**. New summary tables: **player_position_stats**, **hero_position_stats** (player_hero_pos_stats was dropped, see §6a). Plus **player_variant** (player, split rule, start/end, role, rating), **event_placement** (event, team, place, source), and optionally **patch_era**.

---

## 9. Open questions for you

1. Which components go into the rating, and with what rough weights (win rate / peak / consistency / placements)?
2. ~~Variant split rule~~: decided, per-player rolling windows of at least 3 years, stretched so nobody has more than 3 cards; short last windows merge.
3. Off-role penalty style: flat, experience-scaled, or a per-position rating (§5)?
4. Hero-position formula: threshold, smooth curve, or patch-aware (§6b), and do you want the composition check?
5. Placements source: derived, Liquipedia, hand-entered, or a mix (§7)?
