# Full audit (design, data, feasibility, risks)

_2026-10-11. Covers every doc in [docs/research/](../research/), project memory, and the data pulled today ([data/README.md](../../data/README.md)). Tags: VERIFIED = checked against data or a live source today; INFERRED; OPINION._

## 0. Verdict
**The project is buildable on free data, and all the data it needs is now in the project folder except Liquipedia's tier-1 list and placements**, which you have to pull yourself with the script provided (their robots.txt blocks Claude's agents). The design is consistent apart from five small conflicts between older docs and memory (§1), none of which blocks anything. The biggest real risks are hand work (alias table, hero traits, org table) and balance tuning, not feasibility.

## 1. Design consistency audit

What I checked: every rule in game_design.md rev 5 against the other research docs, the memory notes and Sadman's latest messages (including 22:07: longevity in consistency, 2 picks for the upper-bracket loss).

| # | Conflict or stale point | Where | Status / what the drafts do |
|---|---|---|---|
| 1 | **Rock-paper-scissors edges:** the archetype memory note still says "in scope since 20:51", while game_design.md §4 and the memory index say **removed** for balance (scaling lost two matchups and won none, averaging 46%) | memory `archetype-counter-cycle` vs game_design.md §1, §4 | Drafts follow game_design.md (removed). Open question 23 |
| 2 | Upper-bracket loss reward: 2 picks (Sadman 22:07) isn't in game_design.md yet | game_design.md §1–2 | The gauntlet thread owns that doc; my outline, open questions and schema (`run_pack.reason = 'ub_loss_reward'`) already include it |
| 3 | Consistency now includes longevity (22:07); earlier docs define it as win-rate spread only | rating_and_roles.md §3, game_design.md §6 | Outline §4.1 and `etl_draft.sql` split consistency half steadiness, half longevity (tier-1 events attended + top-4 finishes) |
| 4 | game_design.md §12 still lists gauntlet tables (`boss`, `boss_draft`, `run_act`) | game_design.md §12 | Superseded by the TI run; the draft schema uses `run_team`, `series` (self-referencing), `game` instead |
| 5 | base_game_readiness.md defaults (accounts and leaderboard "yes", packs show "org's most-played heroes") | base_game_readiness.md §2 | Superseded by decisions (no accounts; random heroes); its own update notes say so |
| 6 | Hero-position thresholds: rating_and_roles.md option (<1% / 1–40%) vs game_design.md §8 (<2% / 8–25% / ≥25%) | both | §8 is the chosen rule; drafts use it |
| 7 | Rating percentiles within position (rating_and_roles.md suggestion) vs over all players (prototype) | rating_and_roles.md §3, game_design.md §6 | Not decided; drafts rank over all cards. Worth a look during the smell test |
| 8 | ti_mode_audit.md §1 records Sadman's first wording (win 2, loss 1), later reversed to loss 2, win 1 | ti_mode_audit.md §1 | Header of that doc records the final decision; fine |

**Rule interactions worth a second look (OPINION):**
- **The 2-pick upper-bracket loss creates a small tanking incentive.** Losing your first upper-bracket series gives 2 picks; winning it gives 1 upgrade. Losing drops you into a **Bo1** lower-bracket elimination game, which is the deterrent. For a team with one weak slot, two picks might be worth more than an upgrade, so some players will throw a Bo3. The balance script (build_plan M8) should measure champion odds for "always try" vs "throw UB round 1"; if throwing wins more often, make the drop reward 1 pick or keep 2 picks but apply them after the LB round 1 game.
- **Group catch-up plus upgrades:** a 0–7 group means elimination, so the 14-pick maximum can't be banked. Fine as designed.
- **Upgrades on single-card players** fall back to 1 pick (default) so the reward is never empty.

## 2. Data audit (VERIFIED today)

### 2.1 What was pulled
- **OpenDota:** 226,846 pro matches and 2,268,452 player rows, 2012-05 → 2026-09, 420 API calls (inside the free 3,000/day). 56 MB gzipped. Plus leagues (10,348), teams seen in matches (21,810), notable players (5,657), heroes (127).
- **Dota 2 Wiki:** 443 mechanic rows from 12 usable pages; dotaconstants heroes, abilities and 61 patches.
- **Liquipedia:** not pulled (robots.txt); script ready.

### 2.2 Checks against known facts
| Check | Result |
|---|---|
| TI grand finals 2012–2026 from the derived finals table | **All 14 correct winners and runners-up** with the right number of games (TI7 Liquid 3–0 Newbee, TI8 OG 3–2 LGD, TI9 OG 3–1 Liquid, TI 2026 Spirit 3–2 Team Vision) |
| Hero-position shares since 2024 | Gyrocopter 12.7% pos 4 + 9.6% pos 5; Shadow Fiend 0.2% each at pos 4/5. Same picture as the research |
| Mid lane strength (gold diff at 10 vs enemy mid, real mids only) | Top: Alchemist +830, Huskar +530, Shadow Fiend +471, TA +405. Bottom: Spirit Breaker −703, Legion −673. Matches reputation |
| Wiki mechanics | Lion, Enigma and Invoker get 2 hard disables; Spectre and Chen 0. Matches the research checks |

### 2.3 Gaps and quirks found
| Issue | Impact | Handling |
|---|---|---|
| **OpenDota's league tiers are wrong in places:** TI 2014, TI 2015, TI 2017 and the Kiev Major are "professional"; DPC Division II and qualifiers are "premium" | Can't use OpenDota tier as "tier 1" | Name-family candidate list (159 leagues) until Liquipedia's list replaces it |
| **Team names are today's names** (EG's id → "Shopify Rebellion", DC's id → "123") | Pack and roster names would be wrong | `org` + `org_team` tables (hand-checked) for every org that gets a pack or a pool roster |
| **2,482 of 3,086 regular accounts are unnamed** in OpenDota; 12 names sit on several accounts | Stars missing or split (N0tail, Arteezy, Zai, Miracle-...) | Alias candidates file with top teams per account; hand-check the top ~150 by tier-1 games |
| No lane data before 2016 (0% in 2012–14, 30% in 2015) | Older positions are guesses | GPM rank within the team; mark positions "estimated" on old cards |
| 2026 has only 5,479 matches vs 20–30k in 2023–25 | Recent cards (2026) rest on fewer games | Acceptable; recheck before the demo (an incremental pull by date is built into the script) |
| Pool rosters thin in 2020–2023 (4–6 per year) | Fewer DPC-era rosters in fields | Liquipedia's list fixes it (DPC Majors and tier-1 events missing from the name filter) |
| Wiki pages Slow, Banish, Mute returned nothing (redirects / other layout) | No slow data | Slows aren't used by the current team scores; hand-check if needed |
| TI 2011 absent | No Na'Vi 2011 roster | Leave out (default) |

## 3. Feasibility audit

| Part | Effort (INFERRED) | Notes |
|---|---|---|
| Schema (42 tables) | Low–medium | Draft exists; needs a real MySQL run and edits. Not executed here (no MySQL server in this environment, and I didn't install one) |
| Loading 2.3M rows | Low | `LOAD DATA` per slice; minutes |
| ETL SQL (cards, ratings, chemistry, matchups) | Medium | Drafted; heaviest queries are the self-joins (pairs ~2.3M rows × 4 teammates; counters since 2024 ~1M × 5). Fine with the composite indexes, run once |
| Hand tables | **Medium–high (the real cost)** | Alias (~150 players), orgs (~60–100), hero traits (127 × 8), tier-1 list review |
| Sim in PHP | Medium | Rules are fully specified (game_outline §6.5); knobs need tuning |
| Front end (12 screens) | Medium–high | Plain PHP + HTML/CSS is enough; replays are the most work |
| Balance script | Medium | A CLI PHP or Python script that drafts and plays thousands of runs |
| Report | Medium | Outline in dbms_coursework_map.md §4 |

## 4. Course fit (summary)
All 8 official CSE 311 objectives map to concrete features ([dbms_coursework_map.md](dbms_coursework_map.md)). Strongest material: window functions (ratings), self-joins (chemistry, counters), a recursive bracket, real normalization problems (aliases, rebrands, arrays), and transactions/locking (no re-roll, double click, two tabs). The official NSU page doesn't list an explicit transactions unit, but "concurrency control" is in the description; check your section's outline.

## 5. Risks, licences and policies
| Risk | Severity | Mitigation |
|---|---|---|
| Liquipedia access (robots, rate limits) | Medium | Run the script once yourself (≈20 requests); fallback is the OpenDota-derived list |
| Hand-table workload | Medium | Pre-fills done; split between two people (build_plan.md) |
| Balance (dominant strategy, tanking) | Medium | Knobs + batch tuning; the UB-loss tanking test above |
| Data drift (new patches, new heroes) | Low | Data is a snapshot; heroes released after a card's era just have 0 mastery |
| **Valve IP:** hero names fine; hero art/icons are Valve's | Low | Valve's fan-content terms allow non-commercial fan use of its game assets with a disclaimer; check the current policy before using images, or ship text-only |
| **Licences:** OpenDota data (from Valve's public API), Liquipedia and Dota 2 Wiki text CC-BY-SA, dotaconstants MIT | Low | Credits screen + report section (proposal §11) |
| 322-0 similarity | Low | Own data, own formulas, different mode; credited as inspiration |
| Personal data | Low | Pro players' public handles only; no user accounts |

## 6. What I didn't do, and why
- **Didn't pull Liquipedia:** robots.txt disallows Anthropic's agents. Script provided.
- **Didn't run the SQL on MySQL:** no server here; syntax was parsed with sqlglot (MySQL dialect), which catches typos but not every MySQL rule. First step of M1 is a real run.
- **Didn't compute final ratings:** they depend on the hand-checked alias and org tables. The ETL computes them once those exist; game_design.md §6 has the prototype numbers.
- **Didn't copy anything from 322-0.**
