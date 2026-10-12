# Game design: draft + historic gauntlet (combined, research only)

_Revision 6: 2026-10-11, 22:25 UTC (rating counts longevity and repeated top-3 finishes; an upper-bracket loss gives 2 picks). Revision 5: 21:55 UTC, updated 22:00 (upper-bracket wins give upgrades, lower-bracket wins give picks) (switched to a full TI run, era factor removed, group picks 2 per loss and 1 per win, 5-slot bench, playoff variant upgrades). Revision 4: 21:40 UTC (3 lanes with draw zones, random teamfight/pickoff, bench, drafts shown). Revision 3: 21:15 UTC (fight-based sim, no enemy chemistry, counters and aliases in scope). Revision 2: 20:45 UTC. This is the single design doc for both threads: team building (from the "Live 322-0 teardown" thread: [rating_and_roles.md](rating_and_roles.md), [team_synergy.md](team_synergy.md), [base_game_readiness.md](base_game_readiness.md)) and the gauntlet (this thread; earlier options in [gauntlet_mode_audit.md](gauntlet_mode_audit.md)). Tags: VERIFIED = checked live, PROTOTYPE = measured with throwaway Python in my scratch space (not project code), CHOSEN = Sadman asked me to decide. Nothing is built._

---

## 1. Decisions

| Area | Decision |
|---|---|
| Stack | PHP + MySQL 8.0+ |
| Data | Free only: OpenDota + Valve + Liquipedia (placements, tier-1 list, TI1), plus hand-entered tables |
| Accounts | **None.** No login, no leaderboard. If you win, screenshot it |
| Run type | Roguelike, no unlocks, nothing carries over |
| Economy | None: no items, shop or gold |
| Draft | One pick per pack: a player **or** a hero. Team packs. **Packs are not limited by era**, so a lucky early Yatoro is allowed |
| Heroes in a pack | **Random** |
| Rerolls | 0/1/2 by difficulty (322-0) |
| **Run flow** | **A full TI run** (decided 21:43, replaces the boss gauntlet): opening draft (10 picks), then a group stage, then a double-elimination bracket (§2) |
| **Bench** | **5 slots**, players or heroes. Bench cards can be swapped in before each game or series. When it's full, a new card replaces a bench card. A passed pick is gone |
| Field | 15 rosters from a pool of **tier-1 winners and finalists** (Liquipedia), each playing the real draft from its final ([ti_mode_audit.md](ti_mode_audit.md)) |
| Picks | **Group stage: a loss gives 2 picks, a win gives 1** (catch-up). **Playoffs: an upper-bracket series win gives a variant upgrade/swap** for a player you own (e.g. bench Ceb 83 → prime Ceb 95); **a lower-bracket series win gives 1 pick**; **the one upper-bracket series loss (your drop to the lower bracket) gives 2 picks** (22:07) |
| Opponent drafts | Shown before each game |
| Bosses, underlings, acts | **Removed** with the switch to the TI run |
| Match sim | **Fight-based 2d6 dice** (§4): 3 laning head-to-heads with a draw zone (mid weighted most), then each round a random teamfight or pickoff head-to-head (or Roshan); fight winners roll solo for buildings |
| Rock-paper-scissors edge | Light or removed; default **removed** for balance (§4) |
| Chemistry | **Your team only.** None for opponents (§5) |
| Player rating | Composite: win rate + peak window + consistency + placements, spread so most cards stay playable. **Revision 6 (22:07):** consistency now includes longevity and how often a player goes deep, and placements count every top finish, not only finals, so a one-title short stint ranks below a player who keeps finishing top 3 (§6) |
| Player cards | One per era: window = max(3 years, ⅓ of career); short last window merges; max 3 cards (a 4-year career = 1 card) |
| Player pool | Liquipedia tier-1 tournaments; can be cut down further if too big (§7) |
| Placements | Liquipedia |
| Era factor | **Removed** ("remove scaling entirely", read as the era factor): every roster plays at its own peak, an all-time TI |
| Hero-position rule | CHOSEN (§8) |
| Team building | Good team building is rewarded; a badly built team shouldn't get far (§4 shows it doesn't) |
| Roles, mastery, team scores | As decided in the team-building thread (dynamic roles, no double penalty, lane/teamfight/pickoff/scaling scores) |
| First slice | Opening draft + one group of 8 + a short bracket (my default) |
| **Now in scope** | Counter picks, lane matchups, team composition and the rock-paper-scissors archetype edges (§4, §10), no longer parked for the teammate |
| Player accounts | A hand-checked alias table for the top ~100 players (Arteezy, Nisha, Zai, Yatoro and others) (§11) |

---

## 2. One run (TI format, revision 5)

1. **Draft:** 10 picks, one per pack (player or hero), from all eras. Rerolls by difficulty.
2. **Group stage** (default: 16 teams, 2 groups of 8, Bo1 round robin, so 7 games). Before each game you see the opponent's draft and can swap bench cards in, move heroes and change roles.
   - **After each group game: a loss gives 2 picks, a win gives 1.** Over 7 games that's 7 picks (7–0) to 14 (0–7). Each pick is one pack: take a player or hero onto the 5-slot bench, or pass (a passed pick is gone).
   - Places 1–4 go to the upper bracket, 5–6 to the lower bracket, 7–8 are out.
3. **Playoffs** (upper bracket Bo3, lower bracket Bo1 then Bo3, grand final Bo5).
   - **Upper-bracket series win:** one **variant upgrade or swap**: replace a card you own with a different era card of the **same player** (bench Ceb 2020–23, 83 → Ceb 2016–19, 95).
   - **Lower-bracket series win:** **1 pick** (a pack onto the bench).
   - **Upper-bracket series loss:** **2 picks** (decided 22:07). You can lose only one upper-bracket series before dropping, so this happens at most once per run. It mirrors the group-stage catch-up and lets you rebuild for the lower-bracket run.
   - Upgrades are the bigger reward, so finishing top 4 in the group is worth more than farming loss-picks (decided 21:50, to discourage throwing group games). A team that drops from the upper to the lower bracket switches to picks.
4. Win the grand final and you've won TI.

### Notes on the new rules
- **Catch-up picks:** losing early gives more options to rebuild, as you intended. Throwing group games to farm picks is discouraged two ways: 7th or 8th means elimination, and only the upper bracket (top 4) gives the stronger reward, variant upgrades.
- **Variant upgrades for single-card players:** a player with a 4-year career has only one card, so there's nothing to upgrade to. Default (my pick): the upgrade can be used on any owned player who has another card, and if none do, it becomes one extra pick.
- **Upper-bracket loss picks don't invite throwing:** losing gives 2 picks but forfeits the upgrade and sends you into lower-bracket series where one more loss ends the run. A grand-final loss ends the run, so it gives nothing.
- **"Upgrade" can also go down:** a swap to an older or younger card is allowed (e.g. if a weaker card fits a role better). The max-3-cards rule already limits options.

## 3. Era factor (REMOVED in revision 5; kept for reference)

**Rule:** a player's rating is computed **within their era** first, then multiplied by an era factor that grows quickly in the early years and flattens later:

`factor = 0.85 + 0.15 × sqrt((year − 2011) / 15)`

| Year | 2011 | 2013 | 2015 | 2016 | 2017 | 2019 | 2021 | 2023 | 2026 |
|---|---|---|---|---|---|---|---|---|---|
| Factor | 0.850 | 0.905 | 0.927 | 0.937 | 0.945 | 0.960 | 0.972 | 0.985 | 1.000 |

**Why this shape:** the game's skill ceiling rose fastest in its first few years, as the meta, coordination and drafting were being figured out. Since about 2017 the top level has changed less. A straight line would make 2017 and 2026 teams too far apart, and Liquid, OG and Spirit should all feel like final-level threats. With packs open to every era, a draft with several modern cards beats the early bosses comfortably. The later bosses still need a well-built team.

**How it'll be tuned:** once real ratings exist, a script plays thousands of auto-drafted runs and adjusts the range (0.85) so that a random draft beats an act-1 boss ~60% of the time and Liquid TI7 ~35%, while a well-built draft beats Liquid ~55–60%. These targets are my default and easy to change.

---

## 4. Match sim: fight-based 2d6 dice (revision 4)

The sim runs in under a second; a replay can be shown as fast as you like. "Fights" below are rounds of the sim, not real minutes.

### Two kinds of checks
| Kind | Checks | How it rolls |
|---|---|---|
| **Head-to-head** | 3 laning checks, teamfight, pickoff, Roshan | Both teams roll 2d6 + modifiers; the higher total wins. A weak laner rolling 11 beats a strong one rolling 3 + 2 = 5 |
| **Solo** | T1, T2, T3, Barracks, Ancient | Only the team that just won a fight rolls 2d6 + modifiers against a target. A very high roll takes two buildings |

### Flow of one game
1. **Laning: three head-to-heads**, one per lane: your safe lane vs their off lane, mid vs mid, your off lane vs their safe lane. Each uses that lane's heroes and matchups (§10).
   - **Draw zone:** if the two totals are within a set range, that lane is a **draw** and gives nothing. Default: the range is wider when both sides of a lane are passive laners and narrower when one side is a lane bully (my pick for "depending on drafts"; the prototype below used one fixed range, so this still needs tuning).
   - **Weights:** mid counts for half the lane result, each side lane for a quarter. If one team comes out ahead overall, it gets a bonus on its T1 push and on the first few fights. If laning nets out even, nobody carries anything.
2. **Each later round is one head-to-head fight**, chosen at random:
   - **Roshan** when he's up (from round 4, and again 2 rounds after each kill). The winner gets Aegis (+2 on the next fights).
   - Otherwise a **teamfight** (about 57% of rounds) or a **pickoff** (about 43%). Both work exactly the same way. A teamfight-heavy draft gets its bonus in teamfights, and a pickoff-heavy draft gets its bonus in pickoffs.
   - The fight winner makes a **solo roll** for the next enemy building.
3. **The first Ancient to fall loses.**

Timing: early-game scores count in rounds 1–5, scaling ramps in from round 10, and a team behind in buildings gets a small comeback bonus in fights.

### Tuned results (PROTOTYPE: automatic search over the knobs, then 20,000 games per line)
| Test | Result |
|---|---|
| Game length | Median 13 fights (10% end by 7, 10% go past 21) |
| Laning | 22% of games end laning even (no carry-over); the team that wins laning goes on to win **66%** |
| Strong laners (+2 in every lane) vs an even team | 60% |
| +5 / +10 rating | 62% / 76% |
| Each style vs the others, **no rock-paper-scissors edge** | Averages **47–53%**: nothing dominates (laning 53%, teamfight 47%, pickoff, early and late all 50%) |
| Badly built team (−2 in every style) | 13% per game |

### The rock-paper-scissors edge: my recommendation is to remove it
With a light edge (+0.15 per fight), each favored matchup lands at **54–60%** as intended. But **scaling's overall average drops to 46%**, because in your cycle scaling **loses to two styles** (early timing and pickoff) and **beats none**. Following your rule ("if it favors balancing, remove it"), the default is **no edge**. The alternative is to give scaling a win somewhere (for example "scaling beats laning") so every style wins one and loses one.

Lessons from tuning: per-fight bonuses add up over 13 fights (+1 per fight turns a slight edge into 85%+), so every modifier stays small. These knobs were tuned with made-up team scores and get re-tuned once real hero traits exist.

---

## 5. Chemistry

**Decision (20:52 UTC): chemistry counts for your team only.** Underlings and bosses get none, so the numbers below are background. They still matter for your own picks: drafting Liquid's long-running core together pays off.

### Background: how long boss lineups played together

VERIFIED (OpenDota, pro league games with all 5 boss players on the same side):

| Boss lineup | Games as a five | Together from → to |
|---|---|---|
| Wings (TI6) | **406** | Nov 2015 → Apr 2017 (~17 months) |
| Liquid (TI7) | 503 | Nov 2016 → May 2019 (~31 months) |
| OG (TI9) | 127 | Jun 2018 → Aug 2019 (~14 months) |
| Spirit (TI15 lineup) | 92 | May 2026 → Aug 2026 (~3 months) |

**Surprise:** Wings didn't play together for long, but they played a **lot** in that time. By games together they're near Liquid. By time together they're low.

**Liquid by year (VERIFIED, added 20:40 UTC; the table above counts only games with all five):**

| Year | All 5 (TI7 lineup) | 4 of the 5 |
|---|---|---|
| 2016 | 22 | 43 |
| 2017 | 214 | 0 |
| 2018 | 171 | 16 |
| 2019 | 96 | 92 |
| 2020–2023 | 0 | 409 (the core kept going as a four, as Nigma) |

So you're right that the core stayed together: 503 games as a five from late 2016 to mid-2019, and another ~500 as a four after that. The chemistry design already counts groups of 2, 3 and 4, so Liquid's long-running core scores well even though the full five broke up in 2019. Some games are probably still missing because players switched Steam accounts (Miracle- has 2), which the alias table fixes.

**Design:** chemistry uses the same rule for the boss and for you, counted over whole careers (players who played together, played together) and capped. The rule needs one choice, question 1 below. For the 2026 Spirit lineup, the pairs and trios (Yatoro, Larl, Collapse played together for years) still give strong chemistry even though the five-stack is new.

---

## 6. Player rating: a first real test (PROTOTYPE)

I tried your four ingredients on OpenDota data: **444 players** with ≥ 150 games in OpenDota's "premium" leagues.
- **Win rate:** career, pulled toward 50% for small samples.
- **Peak:** best 2-year stretch, same smoothing.
- **Consistency:** how little the yearly win rate swings.
- **Placements:** a stand-in for now: points for reaching a premium grand final (3 for a win, 1.5 for a loss). Liquipedia replaces this in the real build.

Each ingredient becomes a percentile among all players, then the weighted mix (30% win rate, 25% peak, 15% consistency, 30% placements) is mapped onto 68–99.

| Rating | 322-0 (for comparison) | Prototype |
|---|---|---|
| ≥ 95 | — | 8% |
| ≥ 90 | — | 17% |
| ≥ 85 | 10% | 27% |
| ≥ 80 | — | 39% |
| ≥ 70 | — | 78% |

Legends land where they should: Puppey 97, Yatoro 99, Miracle- 97, Collapse 99, Ceb 95, SumaiL 93, Quinn 97. No legend sank because of one bad event, since a bad tournament is a few games out of hundreds.

**Per-era cards (PROTOTYPE, added 20:45 UTC).** The numbers above rate a whole career at once. The real game rates **each era card** separately, using your window rule (max(3 years, ⅓ of career), short last window merged). That's how weak stints count: they lower the card for that window instead of dragging down a player's prime.

| Player | Cards (window: rating, games, win rate) |
|---|---|
| Ceb | 2016–19: **95** (237 g, 60%) · 2020–23: **83** (192 g, 53%) |
| Puppey | 2017–20: 98 (395 g, 68%) · 2021–23: 84 (263 g, 54%) |
| Miracle- | 2016–18: 99 (247 g, 64%) · 2019–22: 94 (348 g, 56%) |
| Topson | 2017–20: 90 · 2021–24: 78 |
| SumaiL | 2016–19: 91 · 2020–23: 87 |
| Quinn | 2016–18: 89 · 2019–21: 90 · 2022–24: 95 (improved over time) |
| Dendi | 2017–20: 68 · 2021–23: 71 (only his late career is in this data) |

909 cards from 658 players. Two data gaps show up clearly: OpenDota's "premium" label starts around 2016, so Puppey's and Dendi's early years are missing, and Yatoro's games after 2023 sit under other Steam accounts. Liquipedia's tier-1 list and the alias table fix both.

**What the test exposed:**
1. **The weights barely change the order** (30/25/15/30 vs 25/25/10/40 gave nearly the same top 15), because good players are good on all four measures. The **curve** that maps the mix onto 68–99 decides how many cards feel playable. That's the knob to tune, not the weights.
2. **Old players look worse**: Dendi comes out 81–84. OpenDota labels few pre-2016 events "premium", and their win rates were spread differently. Comparing players **within their era** (§3) fixes this, which is one more reason for era-relative ratings.
3. **Names are missing**: N0tail, ana and Arteezy have no name in OpenDota at all, and KuroKy and MinD_ContRoL appear as "kky" and "mc". The hand-checked alias table from the readiness doc is required.
4. **OpenDota's "premium" tier is messy**: it includes DPC Division II leagues and regional qualifiers. That's why the pool should come from Liquipedia's tier-1 list (§7).

### Revision 6 (22:07): longevity and repeated deep runs (PROTOTYPE)
Your rule: someone who won one event and then missed the next tier-1 event or retired shouldn't rate above someone who kept finishing 3rd. The old mix only rewarded finals (3 points for a title, 1.5 for a lost final), so a 3rd place counted for nothing, and consistency only measured how much the yearly win rate swung.

**New mix per card** (each ingredient is a percentile among all cards, then mapped onto 68–99 exactly as before):

| Ingredient | Weight | What it measures |
|---|---|---|
| Win rate | 20% (was 30%) | Same, pulled toward 50% for small samples |
| Peak | 15% (was 25%) | Best 2-year stretch |
| Consistency | 30% (was 15%) | Equal thirds: yearly win-rate swing (as before), **longevity** (years in the window with ≥ 30 tier-1 games, plus a bonus for events attended), and **deep-run rate** (share of attended events where the team reached the top 3–4) |
| Placements | 35% (was 30%) | 10 per title, 6 per lost final, **3 per other top 3–4 finish** |

**Results (909 cards; the spread is unchanged: ≥ 95 7%, ≥ 90 17%, ≥ 85 27%, ≥ 80 39%, ≥ 70 78%):**

| Group | Card | Old → new | Why |
|---|---|---|---|
| One title, short stint (≤ 6 events) | Lou 2021–23 | 95 → **92** | 1 title, 6 events |
| | Cloud 2021–24 | 93 → **89** | 1 title, 4 events |
| | Worick 2021–23 | 89 → **86** | 1 title, 2 events |
| | zzq 2021–23 | 89 → **86** | 1 title, 2 deep runs in 6 events |
| Keeps going deep, few titles | Fly 2017–20 | 90 → **95** | 23 events, 9 deep runs, 0 titles |
| | YapzOr 2016–18 | 92 → **96** | 11 deep runs in 17 events |
| | Dy 2021–24 | 92 → **96** | 10 deep runs in 12 events |
| | SumaiL 2016–19 | 94 → **97** | 12 deep runs in 24 events |
| Arteezy | 2016–18 / 2019–21 / 2022–23 | 91 / 98 / 94 → **93 / 97 / 92** | Already high: 21 deep runs, 2 titles and 3 lost finals in this data |
| Others | Puppey 2017–20 / 2021–23 | 98 / 85 → 99 / 88 | |
| | ana 2018–20 | 98 → 95 | Short window, 5 events |
| | Topson 2021–24 | 75 → 81 | |
| | Ceb 2016–19 / 2020–23 | 97 / 85 → 95 / 87 | |

(These "old" numbers come from the same run as the new ones, so they differ by 1–2 points from the earlier card table above.)

**Caveat:** "deep run" here means the player still played in the **last 2 days** of an OpenDota premium event, which is roughly the top 3–4. That label includes some regional leagues. Liquipedia placements (1st, 2nd, 3rd–4th, …) replace this proxy in the real build and make it exact. Arteezy may move once only tier-1 events count.

---

## 7. Player pool: Liquipedia tier-1

VERIFIED (Liquipedia's free MediaWiki API, 20:30–20:50 UTC):
- **It's usable but slow.** Liquipedia rate-limits hard. Requests 10 seconds apart still got "429 Too Many Requests" after two pages, so the import has to run once at build time, slowly (one request per 30+ seconds), and be cached in MySQL. The game never calls Liquipedia.
- **The "Tier 1 Tournaments" category is noisy.** The first 1,000 entries (it stops partway through "K") include DotA 1 events from 2005–2010 and many **qualifier subpages** (for example "Kiev Major/2017/Southeast Asia/Open Qualifier/1"). Those have to be filtered out by page name.
- **The cleaner source** is Liquipedia's "Tier 1 Tournaments" page, which lists events by year, but its tables are generated, so it needs the slower "parse" request (about 20 requests, one per year section).
- **Placements:** each tournament page has a prize-pool table with every team's place (VERIFIED on TI 2011: Na'Vi 1st, EHOME 2nd, Scythe 3rd, MYM 4th).
- **Size estimate (INFERRED):** a few hundred main events from 2011 to 2026 after removing qualifiers. Each tournament has to be linked to OpenDota leagues by name and dates for the match stats, through a small mapping table checked by hand.

If that's too much, the first cut is **Valve events only** (TIs and Majors), roughly 40 events (INFERRED count) and the easiest to map.

Liquipedia's content is CC-BY-SA, so the project credits it.

---

## 8. Hero-position rule (CHOSEN, plain version)

For each hero, the data gives **what share of its pro games were played at each position**. The rule only looks at that share:

| Share at the slot you put it in | Meaning | Effect |
|---|---|---|
| ≥ 25% | Normal role | none |
| 8–25% | Real flex (Gyrocopter pos 4/5 is ~18%) | small bonus |
| 2–8% | Rare but seen | none |
| < 2% | Off-meta (Shadow Fiend at support is ~0.3%) | penalty |
| Hero has < 50 pro games in the window | Not enough data | none |

This handles "3 carry heroes on 3 cores" without a special rule: a carry hero put at mid or offlane usually has a low share there and gets no bonus, or a penalty. Shares are computed over a window of patches, so a hero that changed roles over the years is judged by its recent use.

---

## 9. Hero traits (what that means)

The team scores (stuns, pickoff, teamfight, lanes, scaling) need to know **what each hero can do**. Hero traits are a small table with one row per hero and a few columns, for example:

| Hero | Melee/ranged | Stun | Teamfight ult | Mobility | Lane strength | Summons |
|---|---|---|---|---|---|---|
| Lion | ranged | yes | no | low | medium | no |
| Enigma | ranged | yes | **Black Hole** | low | low | yes |
| Ember Spirit | melee | no | medium | **high** | medium | no |

**Source: the Dota 2 Wiki (dota2.fandom.com), not pro data** (VERIFIED, 20:40 UTC). Its free API returns each mechanic page's list of abilities:

| Wiki page | Abilities listed | Heroes or units |
|---|---|---|
| Stun | 135 | 87 |
| Silence | 86 | 51 |
| Root | 36 | 28 (includes Ember Spirit's Searing Chains) |
| Hex | 5 | 5 |
| Slow | uses a different layout; needs its own parser |

It gets Lion right (Earth Spike), plus Jakiro (Ice Path), Bane (Nightmare, Fiend's Grip) and Earth Spirit, and correctly lists **no** stuns for Abaddon and Lich. A few rows name units rather than heroes (for example Brewmaster's Earth spirit), so those need a small mapping.

Caveats: the wiki describes the **current patch** only, so a hero whose kit changed has today's kit. Its text is CC-BY-SA, so the project credits it. Lane strength and "teamfight ult" aren't wiki categories; those stay a short hand-checked list.

---

## 10. Counter picks, lane matchups and team composition (now in scope)

### What the free data supports (VERIFIED, OpenDota explorer, 21:00 UTC)
| Need | Data | Finding |
|---|---|---|
| **Hero vs hero counters** | Pro matches since Jan 2024, heroes on opposite sides | 8,001 hero pairs; **median 175 games per pair**; 73% of pairs have 100+ games, 97% have 30+. Enough for a win-rate-vs-expected number per pair, pulled toward neutral when the sample is small |
| **Lane matchups** | Same games, both heroes in the same lane (lane data from 2016), gold difference at 10 minutes | Works for common pairs. Mid examples: Huskar vs Invoker **+850** gold at 10 (71 games), Huskar vs OD +1,183 (29 games), Viper vs Huskar +360 for Viper (50 games). Rare pairs are sparse, so they fall back to each hero's general lane strength |
| **Pub data** | OpenDota's public match feed | **Not usable:** hero lists come back empty (all zeros), and the explorer times out on the public table |
| Older eras | — | Counters shift with patches, so they're computed per era window, like everything else |

### Does the data match reputation? (VERIFIED, pro mid lanes since 2022, gold difference at 10 minutes)
| Your read | Data |
|---|---|
| Huskar demolishes melee mids | **+952** vs melee (1,220 games), +455 vs ranged (1,989) ✅ |
| Monkey King demolishes melee mids | **+599** vs melee (1,808), −33 vs ranged (2,029) ✅ |
| Slark demolishes melee mids | +160 vs melee (247), −120 vs ranged (214): mild, and Slark is rarely mid ⚠️ |
| Viper beats most mids except ones that outrange him | Viper **loses** to Sniper (−351, 118 games) and Lina (−164, 115), and beats Ember (+630), Storm (+578), Monkey King (+1,059) and even Huskar (+445) ✅ |

The data agrees with your reads almost everywhere, so **data does the work**, pulled toward neutral when a pair has few games. A short hand-written override list stays available for cases where you know better.

### How each piece plugs into the sim (proposal)
| Piece | Where it acts |
|---|---|
| **Lane matchups** | Three laning checks (§4): your safe lane (pos 1 + 5) vs their off lane (pos 3 + 4), mid vs mid, and your off lane vs their safe lane. Each uses the matchup numbers for those exact heroes (fallback: lane strength, melee/ranged) |
| **Counter picks** | Teamfight and pickoff checks. Sum the counter numbers across all 25 hero pairings and turn the total into a small ± modifier |
| **Team composition** | The archetype scores (laning, teamfight, pickoff, early, late) from the hero traits decide which checks a team is good at |
| **Rock-paper-scissors edges** | Default removed (§4) |

### Where the player gets to use it
**Decided:** boss and underling drafts are shown before each game. You counter them by moving heroes between your players, changing roles and swapping in bench cards.

---

## 11. Player accounts (aliases)

You're right that this is a must. VERIFIED (OpenDota, 21:00 UTC):
- **Arteezy** = account 86745912 (Kaipi 2013, EG 2014, Secret 2015–16, EG to 2024), but OpenDota has **no name** on it.
- **Zai** = 73562326 (EG 2014, Secret 2015, EG 2016–17, Secret 2018–21, Liquid 2021–23), also unnamed. It was the "73562326" rated 99 in §6.
- **Nisha** has two accounts: 201358612 (named, Liquid 2023–26) and **121769650** (unnamed, 663 games for Secret 2019–22). That account was the unnamed "121769650" rated 98 in §6.
- **Yatoro** has 6+ accounts named "Yatoro", but name search is unsafe: two other "Miracle-" accounts belong to random teams ("Krasyliv Team", "Yelling Shrek"), and "Yatorogod" is a fan.

**Method:** for each of the ~100 top players, find accounts that played **in that player's roster slot for the right team in the right years**. For example, Nisha's Secret account was found by listing everyone who played 50+ games for Secret in 2019–22. I'd pre-fill the table this way, and you'd spot-check names you know. It's one small table (`player_account`), and every stat is grouped through it.

---

## 12. Database implications

As in revision 1, without the accounts and leaderboard: `era`, `boss`, `boss_draft`, `run_act`, `run_series`, `run_game`, `game_event` (turn log), `run_pick` with act number. Runs are stored per browser session (no login). They still need the transaction rule: the seed is stored **before** a game is simulated, and a unique key on (run, act, series, game) stops "refresh to re-roll a lost game". Revision 3 adds `player_account` (the alias table, §11), `hero_matchup` (counter number per hero pair and era) and `lane_matchup` (gold at 10 minutes per pair and lane). Liquipedia data adds `tournament` (tier, dates, Liquipedia page) and `placement` (tournament, team, place), each linked to OpenDota leagues by a mapping table.

---

## 13. Questions left

Defaults I'm using unless you say otherwise:
1. **Group games:** Bo1 (fast, swingy). Bo2 is the old TI style and doubles the games.
2. **Seeding:** TI-winning rosters as top seeds in the other group, so you likely meet one in the bracket.
3. **Field size:** 16 teams in 2 groups of 8.
4. **Rock-paper-scissors:** removed (no answer yet, so the balance default stands).
5. **Lane draw zone:** wider between passive lanes, narrower with a lane bully.
