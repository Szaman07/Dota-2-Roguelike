# Open questions (with recommended defaults)

_2026-10-11. Everything already decided is in project memory and [game_design.md](../research/game_design.md); this list is only what's still open. Each line has my recommended default, which the outline and schema already use, so "go with the defaults" is a valid answer. Most important first._

## Data and ratings
| # | Question | Recommended default | Why |
|---|---|---|---|
| 1 | **Tier-1 list and placements:** run the Liquipedia script yourself, or live with the curated OpenDota list? | **Run [pull_liquipedia.py](../../data/scripts/pull_liquipedia.py) once on your machine** (needs your email in the User-Agent; about 20 requests). Until then the curated OpenDota list is the fallback | Liquipedia's robots.txt blocks Claude's agents, so I didn't pull it. OpenDota's own tiers are wrong in places (TI 2017 is "professional") |
| 2 | Rating weights: win rate / peak / consistency (incl. longevity) / placements | **30 / 25 / 15 / 30**, consistency split half steadiness, half longevity (tier-1 events attended + top-4 finishes) | Your 22:07 rule; weights barely change the order, the curve matters more |
| 3 | Rating curve | `68 + 31 × percentile^1.3` (median ≈ 80, top 5% ≈ 97) | Most cards draftable, greatness still shows |
| 4 | Minimum games for a card (per window) | **150** pro games | Cuts stand-ins and noise |
| 5 | Pre-2016 cards (no lane data, positions guessed from GPM rank) | **Include them**, with positions marked "estimated" | Keeps 2012–2015 legends (Dendi, Puppey's early years) |
| 6 | TI 2011 (not in OpenDota) | **Leave it out** | Only drafts exist (Liquipedia), no player-hero data |
| 7 | Valve Steam API key | **Not needed** | Everything the game uses came from OpenDota, the wiki and dotaconstants |
| 8 | Hero traits: who checks the pre-fill (127 heroes) | Split between you and your teammate, ~65 each | Only `teamfight_ult` and `save` have no data source at all |

## Draft and team
| # | Question | Recommended default |
|---|---|---|
| 9 | What's in an org pack | 5 random players with ≥ 30 games for that org (each as the era card covering their time there) + 5 random heroes |
| 10 | Two era cards of the same player on one team | **No** |
| 11 | Off-role penalty (roles that are neither main nor alternate) | **Experience-scaled:** full penalty with 0 games at that position, none at 100+ |
| 11b | Alternate-role threshold (new 2026-10-12) | A position is alternate if it is **≥ 15% of the card's matches** or another card's main role |
| 12 | Hero mastery window | **The card's own window** (chemistry uses whole careers, as decided) |
| 13 | Heroes released after a card's era (a 2013 card on Marci) | **Allowed**, mastery 0 |
| 14 | A player on your team who also appears in an AI roster | **Allowed** (it's an all-time event) |

## Tournament
| # | Question | Recommended default |
|---|---|---|
| 15 | Group format | **Bo1** round robin (pending from game_design.md) |
| 16 | Field and seeding | **16 teams, 2 groups of 8; TI winners as top seeds** split across groups (pending) |
| 17 | Group tiebreakers | Wins → head-to-head → seeded coin flip, no tiebreaker games |
| 18 | Grand final bracket reset (the lower-bracket team must win two series) | **No reset** (TI style: one Bo5) |
| 19 | Upgrade when no owned player has another card | Becomes **1 pick** |
| 20 | The 2-pick upper-bracket loss (new at 22:07) also applies when you lose the UB final? | **Yes**: it's the one UB loss wherever it happens |
| 21 | AI rosters get hero mastery (they really played those heroes)? | **Yes**; chemistry stays off for them, as decided |
| 22 | Duplicate players across AI rosters in one field | Allowed, but no two rosters sharing 3+ players |

## Sim
| # | Question | Recommended default |
|---|---|---|
| 23 | Rock-paper-scissors archetype edges | **Removed** (game_design.md default). One older memory note still says "in scope", so please confirm |
| 24 | Lane draw zone | Wider between passive lanes, narrower with a lane bully (pending) |

## Schema
| # | Question | Recommended default |
|---|---|---|
| 25 | Chemistry trios/quads/five-stacks: precompute or on demand | **On demand** for the 5 drafted players; pairs precomputed |
| 26 | Keep all 10k OpenDota leagues or only referenced ones | **Only referenced** |
| 27 | Partition `match_player` by year | **No** (InnoDB partitions can't have foreign keys); mention it in the report as a trade-off |
