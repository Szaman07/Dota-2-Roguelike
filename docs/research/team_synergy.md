# Team synergy, draft archetypes and laning (research only)

_Date: 2026-10-11, 19:05 UTC. Follows Sadman's message about end-of-draft team scores. These are findings and options; every choice is Sadman's._

**Tags.** VERIFIED means I saw it in a live response or source data. INFERRED means it follows from evidence. GUESS means a plausible model with weak evidence.

**Short answer: yes, it makes sense, and it's the biggest gap in 322-0.** 322-0's score only uses player-on-hero games and player groups. It has no hero-with-hero, hero-vs-role or laning logic at all (VERIFIED, §3 of the teardown). So your layer would be the original part of the project.

---

## 1. What you asked for, as scores computed at the end of the draft

| Score | Your rule | Inputs |
|---|---|---|
| **Disables** | Count stuns and other disables across the 5 heroes | hero traits |
| **Teamfight** | Needs a balance of big teamfight spells (RP, Black Hole, Supernova); **zero should cost you** | hero traits |
| **Pickoff / playmaking** | Driven by the stuns of **pos 4 + pos 5 + mid**. A disable-less support duo (Abaddon + Phoenix in your example) is negative, offset only by a hyper-mobile mid (Ember, the Spirits); with an immobile mid (Sniper) it's "cooked" | traits per slot |
| **Scaling** | Late-game cores (Spectre, Void, Terrorblade, OD) outscale | hero traits or pro stats |
| **Early timing / snowball / early end** | Summons and push (Chen, Beastmaster, Lycan); snowball heroes (Huskar, mid DP) | hero traits or pro stats |
| **Laning: safe and off lane duos** | Melee + ranged or ranged + ranged ≫ melee + melee. Strong-lane supports (Jakiro, Lich, Bane) beat catch supports that lose lanes (Bounty Hunter, Earth Spirit) | attack_type + lane strength |
| **Laning: mid** | Lane dominators (Huskar, OD) get a lane edge; Invoker-style heroes give that up for teamfight, pickoff and scaling | lane strength + traits |
| **Matchups / counters** | Out of scope for solo play; maybe your teammate's 1v1 part (§5) | hero vs hero stats |

---

## 2. Where hero traits can come from

### 2a. Static data: dotaconstants (MIT, free) — VERIFIED
- `heroes.json` gives `attack_type` (Melee/Ranged), `attack_range`, `move_speed`, and Valve's role tags: Carry, Support, Disabler, Initiator, Escape, Nuker, Durable, Pusher. (Counts over 127 heroes: Disabler 95, Nuker 89, Carry 72, Initiator 55, Escape 53, Durable 50, Support 48, Pusher 29.) **Melee/ranged lane pairs come straight from this.**
- `abilities.json` has every spell's attributes (for example Reverse Polarity: `hero_stun_duration` 2.5/3/3.5, `bkbpierce: Yes`).
- **But reading stuns automatically from those attributes is unreliable.** A keyword scan found 0 stuns for **Lion** and Ember Spirit, and no Beastmaster Primal Roar stun, because attribute names vary by spell. **So a hand-checked trait table is needed.** VERIFIED (my scratch scan)

### 2b. Hand-curated trait table (recommended input, any formula)
`hero_trait(hero, disables, teamfight_ult, mobility, summons_push, lane_strength, scaling, early_power, …)`: 127 rows × about 8 columns. I can pre-fill it from dotaconstants and the pro stats in §2c, and you and your teammate (both Immortal) correct it. This is also a clean "domain data the DB doesn't derive" story for the report.

### 2c. Derived from pro matches (OpenDota explorer, free) — VERIFIED
**Scaling vs early power = win rate by game length** (pro matches since 2024; `samples/od_explorer_hero_duration.json`):

| Hero | < 30 min | 30–45 | 45+ | Reads as |
|---|---|---|---|---|
| Spectre | 40.7% | 45.1% | **58.4%** | scaling ✓ |
| Faceless Void | 42.9% | 52.2% | **56.6%** | scaling ✓ |
| Outworld Devourer (OD) | 40.2% | 49.7% | 48.1% | weak early, mild scaling |
| **Terrorblade** | **55.9%** | 50.0% | 44.7% | early, which contradicts the scaling reputation |
| Chen | **68.7%** | 55.1% | 55.2% | early timing ✓ |
| Lycan | **61.7%** | 48.6% | 45.2% | early timing ✓ |
| Beastmaster | **56.5%** | 49.0% | 45.9% | early timing ✓ |
| Huskar | 51.4% | 48.7% | 52.8% | flat |
| Death Prophet | 49.1% | 48.0% | 48.8% | flat |
| Invoker | 49.2% | 51.0% | 51.0% | flat |

Caveat: a game's length is partly an *effect* of who's winning. A hero whose team is ahead ends games early, so "wins short games" = snowball, which is what you want to measure anyway. But the numbers shift with the patch (Terrorblade's role changes). INFERRED

**Lane strength = gold and XP lead at 10:00 versus the opposing laner** (`player_matches.gold_t` / `xp_t` per-minute arrays plus `lane_role`; mid since June 2025; `samples/od_explorer_mid_lane10.json`):

| Mid hero | Gold lead @10 | XP lead @10 | Games |
|---|---|---|---|
| Huskar | **+718** | +868 | 1,109 |
| Shadow Fiend | +518 | +666 | 4,318 |
| Death Prophet | +400 | +231 | 884 |
| Sniper | +254 | +292 | 2,118 |
| Puck | −4 | +80 | 4,577 |
| **Outworld Devourer (OD)** | −6 | −90 | 842 |
| Ember Spirit | −16 | −28 | 5,095 |
| **Invoker** | **−214** | −202 | 3,563 |

Huskar and Invoker match your examples. **OD doesn't show as a lane dominator** in this window, which is a good example of where data and reputation differ. The same query shape works for side lanes (sum the duo's gold vs the enemy duo), for example Jakiro/Lich/Bane vs Bounty Hunter/Earth Spirit at pos 5. Not run yet; heavier, but doable in narrow date windows. INFERRED

**Option:** a blend. Use the curated table for things stats can't see (disables, teamfight ults, mobility) and the pro stats for scaling, early power and lane strength, with your manual overrides on top.

---

## 3. Turning traits into team scores (options)

**Lane duos** (safe = pos 1 + pos 5, off = pos 3 + pos 4):
- `attack_pattern`: RR or MR = bonus, MM = penalty (your "heavily favoured" rule).
- `+ lane_strength(core) + lane_strength(support)`, from §2c data or the curated column.
- Mid: `lane_strength(pos 2)` alone (no duo).

**Support duo** (pos 4 + pos 5): `disables(p4) + disables(p5)`, plus a "save or sustain" trait if you want Abaddon or Oracle credited for something other than catch.

**Pickoff:** `f(disables(p4) + disables(p5) + disables(mid), mobility(mid))`. Your rule as a formula: if the support-duo disables are 0, then pickoff is **negative** unless `mobility(mid)` is high, and it is doubly negative if the mid is immobile. A small CASE expression or lookup table expresses that cleanly.

**Teamfight:** `count(teamfight_ult)` mapped through a curve: 0 → penalty, 1–2 → bonus, 3+ → no extra bonus (balance, not stacking).

**Game-plan archetype:** `early = Σ early_power`, `late = Σ scaling`. A strong lean either way is a valid identity (Chen + BM + Lycan = timing push; Spectre + Void + TB = late game). Mixed-signal drafts get no identity bonus.

**How it reaches the result (pick one):**
- **(a) Add it to OVR**, like 322-0's synergy and chemistry: simple and visible on screen.
- **(b) Make the sim phase-aware:** each simulated game gets a random length, and early/late teams win more of the short/long games. Laning shifts the early part. Field teams get random archetypes too, so a scaling team can lose to a fast push. More interesting, but more design work.
- **(c) Both:** a small OVR part for visibility plus phase effects in the sim.

---

## 4. DB mapping (plain English)
- **hero_trait** (curated), **hero_phase_stats** (hero, length_bucket, games, wins: one `CASE` bucket + `GROUP BY`), **hero_lane_stats** (hero, lane_role, avg_gold_diff_10, avg_xp_diff_10: a same-match, opposite-side self-join).
- OpenDota's per-minute gold is a **Postgres array** (`gold_t[11]`). MySQL has no arrays, so pull just the 10-minute value into a column during ETL, or store a JSON column. That's a good normalization (1NF) talking point in the report.
- A run's team scores are a `SUM`/`CASE` over its 5 run_pick rows joined to hero_trait. Store them on the run row when it's finalized (in the same transaction as the sim).

---

## 5. Matchups for your teammate (future, optional)

> **Parked by Sadman (18:58 UTC) for later; base game first.** Archetype counter cycle, each a *slight* advantage: early timing > late scaling; laning-heavy > pickoff-heavy; teamfight-heavy > laning-heavy; pickoff-heavy > scaling-heavy. Tuned so no single archetype is universally best.
`hero_matchup(hero_a, hero_b, games, a_wins)` comes from the **same self-join as chemistry, but on opposite sides**. For lane matchups specifically, add `lane_role`. It's feasible on free OpenDota in date windows. It only matters once there's an opponent draft (1v1 or a field with real drafts). It's a cleanly separate module, so it splits well between two people. INFERRED

---

## 6. Open questions for you
1. Traits: curated table, pro-stats-derived, or a blend (§2)?
2. How team scores reach the result: OVR bonus, phase-aware sim, or both (§3)?
3. Should field teams get archetypes and drafts so your team's identity matters against them, or stay as plain ratings like 322-0?
4. Lane strength: measure it per patch era (it changes, as OD shows) or once overall?
