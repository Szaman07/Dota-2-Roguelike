# 322-0 teardown (research only)

_Date: 2026-10-11. Revision 2 (18:00 UTC): live evidence from the 322-0 client code and data files, 82-0.com, and direct OpenDota calls. Replaces the screenshot-only revision._

**Tags.** VERIFIED means I saw it directly in the site's code, its data files, a live response, or your screenshot. INFERRED means it follows from evidence but I didn't observe it directly. GUESS means a plausible model with weak evidence.

---

## 0. Method and access

- **Access (17:44 UTC):** 322-0.app, 82-0.com and api.opendota.com all answer 200. api.steampowered.com is reachable, but every Dota method needs a key, and per your brief I didn't create one.
- **No git repo** exists in this workspace, so these files live in the project's shared folder under `docs/research/`.
- **Browser:** this thread has **no browser tools**, so I couldn't click through the UI. Instead I:
  1. fetched the page and its single JS bundle (`/assets/index-BCFh8CR5.js`, 400 KB, Vite + React + zustand);
  2. fetched the 7 JSON files the page itself loads, **once each** (this is exactly what one page visit downloads). They were saved only to my scratch space, not to this folder;
  3. ran the site's own scoring, field and TI-sim functions in a throwaway Node harness (scratch only) and compared them with my own independent Python version. That is how "two runs" were checked (§3).
- **robots.txt:** 322-0.app has none (the URL returns the SPA shell). 82-0.com disallows `/draft`, `/profile`, `/c/`, `/store` and a few others, so I only read its home page and sitemap (§1b).
- Nothing from either site (code, data, art) is copied into this folder. Short quoted constants below are evidence for formulas.

---

## 1. Game loop

### 1a. 322-0 Classic (VERIFIED from client code unless tagged)

| Step | What happens |
|---|---|
| **Home / settings** | Two tabs: **322-0 Classic** and **Esports Manager (beta)**, a separate multi-season career mode (§1c). Classic settings: **Format** = *Valve Legacy* (every TI and Valve Major: 19 events, 330 packs) or *Standard* (events from the last ~2 years: 26 events, 389 packs). **Difficulty** = Hard (0 rerolls), Easy (1 reroll, default), Smurfing (2 rerolls). **Scoring** = Event Rating (enabled) or Peak Rating (listed but disabled). **Hero allocation** = Automatic (default) or Manual. Then Start Run. |
| **Pack draw** | A pack = one team's roster at one event. It is drawn **uniformly at random, with replacement**, from all packs in the chosen format. It shows that roster's 5 players plus **5 heroes picked at random from that pack's 10 "signature heroes"**. The draw retries up to 80 times to find a pack with at least one pickable player or hero. |
| **Pick** | You take **exactly one item per pack**: one player (into the open slot matching their role: safelane, mid, offlane, support ×2) or one hero (up to 5). A player already on your team, or one whose role slot is full, is disabled. After any pick a new pack is drawn. A run is **10 picks**: 5 players + 5 heroes. |
| **Reroll** | "↻ Reroll (n)" redraws the current pack. It costs only the count from Difficulty (0/1/2 per run). It isn't available once the draft is complete. |
| **Live scoring** | As you pick, the panel shows Base, Hero synergy and Chemistry with "Great" / "Insane!" tags (§3), the hero-to-player assignment with games counts, and the top 6 chemistry pairs. A help box explains: *"Hero synergy is the automatically optimized best configuration of player × hero combinations (more games is better!)"*, and *"Chemistry is the experience between various players (in the events of the packs, but also lifetime)."* |
| **Hero swap** | Only in **Manual** allocation: "tap two players to swap their heroes". Manual mode starts from the automatic assignment. |
| **Field + projection** | When the draft is complete: an 18-team field (your team plus 17 joke teams), sorted by rating, with "Projected finish · 18-team field" shown as a band. **"↻ Re-roll" redraws the field: free, unlimited**, available until you simulate. |
| **Simulate The International** | One click, one new random seed. It animates the group draw, group games, then the playoff bracket ("Simulating live…"). Once a result exists, the simulate button is gone, so **one sim per run**. |
| **Abandon Run** | Ends the run and returns home. The subtitle is a random joke excuse ("Smurf Detected", "Puppey Paused", "Visa Problems", and so on) chosen from the field seed. |
| **Results** | The title is **"322-0 — UNDEFEATED CHAMPIONS"** (won TI with zero game losses), "CHAMPIONS", or "Finished 5–6th". It also shows the champion, your roster with heroes, and buttons for "New Run · Same Settings" and "New Run (change settings)". |
| **Sharing** | A **download-PNG** button renders the result card to an image (`322-0-<place>.png`). There are no share links, no leaderboard and no server: nothing is posted anywhere. |
| **History** | The last 50 runs are kept in **localStorage** (`322-0-run`). The page shows counts for placements, Undefeated, Flawless Group, and games won/lost. |
| **Daily / seeded mode** | **None.** All seeds come from `Math.random()`. The field and sim are deterministic *given* their seed (a small seeded PRNG), and the seeds persist in localStorage, so a reload shows the same result. |
| Other pages | `/players` (player browser with career heroes and teammates), `/events`, `/legends`, `/shop`, `/styleguide`. |

### 1b. 82-0.com (light; home page and sitemap only, since robots.txt disallows `/draft`)

- It's a Next.js app with sign-in, coins, "draft boosters" and a shop. VERIFIED (UI strings in the page payload)
- Loop, from its own copy: *"Each round, spin to get a random NBA team and decade" → "Select one player from that era" → "Complete all 5 rounds"*. A respin is available for team or decade, with a limited count ("Respin {scope} ({remaining} left)"). VERIFIED
- Rating: *"Rated on PPG, RPG, APG, SPG, and BPG"*. Missing defensive stats from old eras are estimated. The sim *"runs your aggregate stats through a win-projection curve"* that is non-linear, and *"A deficiency in even one category can prevent a perfect season."* The result is an 82-game record ("Projected Record"). VERIFIED (copy); the exact curve is unknown.
- Modes: **Classic** (stats visible) and **HoopIQ** (stats hidden, "draft entirely from memory"). Career is "coming soon". There are also challenge boards you share by link and a leaderboard ("Top {percent}%"). Share text: "I just went {score}, think you can go 82-0?". VERIFIED
- I found no daily mode string (a "Daily" token exists, but its context isn't visible without the draft page). GUESS: no daily mode.

### 1c. What 322-0 changed vs 82-0 (VERIFIED from both sites' copy and code)

1. **A pack is a roster at an event**, not a franchise + decade. A player's rating is per event (the `ovr` field on each roster entry).
2. **Heroes are a second draft axis.** Every pick is a trade-off: take a player *or* a hero from this pack.
3. **Chemistry** rewards real shared pro games among 2–5 of your players. 82-0 has nothing like it.
4. **A season becomes a tournament.** Instead of 82 independent games, you play an 18-team TI (groups, then a double-elimination bracket). The "322-0" name is a pun: in this format a perfect run is about **25–28 games, not 322**.
5. **No accounts, server, leaderboard or boosters** in Classic. Esports Manager adds money, seasons, Elo across a 64-team world, and "Aghanim's Shards" meta-progression.

---

## 2. Data sources

**All of the game's data is static JSON served from `322-0.app/data/`, loaded once by the client.** There are no OpenDota, Stratz or Valve calls; the only remote resources are `cdn.datdota.com` hero images and Google Analytics. VERIFIED (every `fetch` in the bundle). Files were last modified **2026-06-16** (HTTP `last-modified`).

| File | Shape | Rows | Notes |
|---|---|---|---|
| `events.json` | id, name, short, type (`ti`/`major`/`tier1`), year, patch, formats | **44 events**: 14 TI, 5 majors, 25 tier-1. **2011 (TI1) → 2026** (ESL One Birmingham 2026). Patches 6.74 → 7.41 | VERIFIED |
| `packs.json` | id, eventId, teamId, teamName, tag, logoId, placement, signatureHeroes[10], players[] | **703 packs**, 3,516 roster entries (702 packs have 5 players, 1 has 6), **589 distinct players** | VERIFIED |
| └ players[] | steamId, nickname, role (`safelane`/`mid`/`offlane`/`support`), **ovr**, impact, economy, reliability, games | ovr 55–98, mean 74.1. `games` = games at that event. **`reliability` is constant per player across every event** (career-level). | VERIFIED |
| `heroes.json` | id, name, picture | 127 | VERIFIED |
| `playerHeroStats.json` | {steamId: {heroId: {games, winrate}}} | 594 players, **36,281 player×hero rows**, max 314 games | VERIFIED |
| `squadSynergy.json` | [{ids[2..5], games, winrate}] | **3,865 groups**: 2,859 pairs, 701 trios, 262 quads, 43 five-stacks. Max 1,884 games (Boxi + MiCKe) | VERIFIED |
| `teammates.json` | {steamId: [teammate steamIds]} | 589 players, 5,528 links; used only on the /players page | VERIFIED |
| `eventHeroStats.json` | {eventId: {steamId: {heroId: {games, winrate}}}} | 44 events; used for the "Heroes at this event" popup | VERIFIED |

**Where it comes from.** The author is Noxville, who runs **datdota** (pro-only stats). Player links go to `datdota.com/players/{id}` and the footer links to ko-fi.com/datdota. The player popup labels the hero data **"Career hero combos (tier 1–2)"**. VERIFIED (UI). So the data is a datdota export. INFERRED

**Pro only or pubs too? Pro only (tier 1–2 leagues).** VERIFIED (UI label), and confirmed against OpenDota (pro-only explorer tables):
- Boxi + SabeRLight- together: 322-0 says **346**. An OpenDota explorer self-join over pro `player_matches` returns **346** exactly. Boxi's peers endpoint with `lobby_type=1` (all lobbies) says 349. VERIFIED (`samples/od_explorer_pair_boxi_saber.json`)
- Boxi on Tusk: 322-0 says **134**. OpenDota explorer (pro) says **142**, and Boxi's last Tusk game there is 2026-08-21, after 322-0's data snapshot (2026-06-16). The gap is consistent with the snapshot date plus datdota's tier filter. INFERRED
- `games` on a roster entry equals the sum of that player's `eventHeroStats` at that event in 1,482 of 1,501 checked rows. VERIFIED

**Signature heroes.** A pack's 10 `signatureHeroes` overlap on average **8.9 of 10** with the 10 heroes that roster played most at that event (from `eventHeroStats`). So they're roughly "the team's most-played heroes there". INFERRED

---

## 3. Formulas

All rows below are VERIFIED from the client code. They were checked on (a) your screenshot and (b) two runs I scored with both the site's own function and my independent re-implementation, which agreed to the decimal. Constants are quoted from the bundle.

### 3a. Team rating

| Number | Formula | Constants |
|---|---|---|
| **Player rating** | Precomputed `ovr` per (player, event) in `packs.json`; the client never computes it. A least-squares fit `ovr ≈ 0.53·impact + 0.22·economy + 0.17·reliability + 5.4` leaves RMSE 3.6 (max error 17), so it isn't a simple linear mix. It's probably a datdota rating that also uses games or opponent strength. | Fit INFERRED; true derivation unknown (GUESS) |
| **Base** | `avg(ovr)` of the 5 players. The display is rounded; the unrounded average feeds the total. | — |
| **Hero assignment (Automatic)** | Tries all **120 permutations** of your 5 heroes over 5 players and keeps the one with the **largest total raw games**. | — |
| **Hero synergy** | `round1( 1.5 × Σ min(1, games_i / 25) )`. Each player is worth 0 → 1.5 points, linear up to **25 games**, then capped. **Max +7.5.** | `mk=1.5`, `/25` |
| **Chemistry** | For every group in `squadSynergy` (pairs, trios, quads, five-stacks) whose members are **all** on your team: `weight(size) × min(4, games / 230)`. Sum, cap at **13**, then round1. | weights `{2:1, 3:1.6, 4:2.2, 5:3}`, `pk=230`, `hk=4`, `xk=13` |
| **Team OVR** | `round( avg(ovr) + synergy + chemistry )` | — |
| **Tags** | Base: Great ≥ 88, **Insane ≥ 94**. Synergy: Great ≥ 4.5, **Insane ≥ 6.5**. Chemistry: Great ≥ 5, **Insane ≥ 9**. | `No(e.base,88,94)`, `No(heroBonus,4.5,6.5)`, `No(chemBonus,5,9)` |

**Check 1, your screenshot.** Synergy +7.5 means all 5 players had ≥ 25 games (134/122/117/100/25), giving 5 × 1.5. Chemistry: 346/230 = 1.504 → **+1.5**. 84.8 + 7.5 + 1.5 = 93.8 → **94**. ✓ "INSANE!" on synergy, because 7.5 ≥ 6.5. ✓

**Check 2, run A** (Gpk @ Wallachia S8 95, Yatoro @ Wallachia S6 87, SabeRLight- / Boxi / INSaNiA @ TI14 73/77/77; heroes Tusk, Faceless Void, Puck, Mars, Hoodwink). Base 81.8. Synergy: games 117/74/122/134/1 → 4 × 1.5 + 0.06 = **6.1**. Chemistry: INSaNiA+Boxi 1,707 → capped 4.0; Boxi+SabeRLight- 346 → 1.50; INSaNiA+SabeRLight- 321 → 1.40; the **trio** at 321 games → 1.6 × 1.40 = 2.23; total **9.1**. OVR **97**. Site function and mine both give 82 / 6.1 / 9.1 / 97. ✓

**Check 3, run B** (a random legal roster: Watson 89, Crystallize 77, BOOM 64, Kataomi 81, ARS-ART 68; 5 random heroes). Both give 76 / 2.6 / 1.5 / 80. ✓

**A finding that matters for design: Automatic allocation doesn't maximize synergy.** It maximizes total games, but the bonus caps at 25 games per player. On 3,000 random 5-player/5-hero draws, the automatic assignment scored **below the best possible synergy in 36%** of cases, by up to **2.1 points**. Manual mode lets a player fix that. VERIFIED (code + simulation in scratch)

### 3b. Field

- 17 opponents. Strength = `round(clamp(Normal(86, 5), 76, 99))`. The field is **independent of your team**; your entry's strength is your Team OVR. VERIFIED (`i1(r,86,5)`, clamp 76..99)
- Names: 4–8 "No X" or meme names ("No Tinker", "Nyx Sideways", "OD Bench", "SF Upside Down"...) plus random adjective + noun pairs ("Mid or" + "Creeps", "Aegis Spirits"...). VERIFIED
- Re-roll = a new random seed, so a new field (free, unlimited). VERIFIED

### 3c. Projected finish

`rank` = your position when the 18 teams are sorted by strength, shown as **`max(1, rank−1)` to `min(18, rank+1)`**. VERIFIED. Tie-breaking follows the stable sort order (your team is listed first in the array, so you win ties). INFERRED

### 3d. TI simulation (random; deterministic given its seed)

- **Per-game win probability** `p = 1 / (1 + 10^(−(S_you − S_opp) / 22))`, an Elo-style logistic with scale 22. +10 OVR gives p = 0.74; +20 gives 0.89. Every game is an independent coin flip with p. VERIFIED (`l1=22`)
- **Groups:** teams are sorted by strength and **snake-seeded** into A/B (positions 1,4,5,8,… → A). Each group of 9 plays a round robin of **two games per pairing** (16 games per team). Standings: wins, then strength. VERIFIED
- **Playoffs:** each group's top 4 → upper bracket, 5–8 → lower bracket, 9th → 17th/18th. A double-elimination bracket (UB R1, semis, final; LB R1–R5, LB final). **All Bo3, Grand Final Bo5.** VERIFIED
- **Undefeated** = champion with zero game losses across groups and playoffs. **Flawless group** = zero group game losses. VERIFIED

**Win odds** (4,000 sims per row, using the site's own field and sim functions):

| Team OVR | P(win TI) | P(top 3) | P(undefeated) | Avg games played |
|---|---|---|---|---|
| 84 | 0.2% | 3% | 0 | 21 |
| 88 | 3% | 18% | 0 | 24 |
| 90 | 8% | 29% | 0 | 25 |
| 92 | 17% | 45% | 0 | 26 |
| 94 | 26% | 59% | 0 | 27 |
| 96 | 38% | 69% | 0.03% | 28 |
| 98 | 51% | 80% | 0.03% | 28 |
| 100 | 65% | 88% | 0.15% | 28 |
| 105 | 86% | 96% | 2% | 27 |

The ceiling is about 98 + 7.5 + 13, so "322-0 Undefeated" is near-impossible by design. VERIFIED (sim); the design intent is INFERRED.

---

## 4. Where Dota knowledge beats reading numbers

**Knowledge helps (the UI hides it until after you commit):**
- **Player vs hero from the same pack.** You see a pack's 5 heroes and 5 players but not how many games *your already-drafted* players have on those heroes until you pick. Knowing that, say, Boxi lives on Tusk and Batrider tells you which hero to take. The ≥ 25-game threshold is low, so the skill is knowing whether a player has *any* real pro history on a hero.
- **Chemistry across packs.** The panel only scores pairs you already own. Knowing which players shared long-lived rosters, including across orgs and eras, lets you aim for trios and quads, which are worth 1.6–3× a pair. That is where the 9+ "Insane" chemistry comes from.
- **Roles and eras.** Roles are fixed per event (a player can be `safelane` at one event and `support` at another). Knowing a player's history tells you which pack version to wait for.
- **Reroll judgement.** With 0–2 rerolls, you need to know whether a pack's players or heroes can still pair with your picks.

**Pure arithmetic (the UI shows everything):**
- Base, the synergy and chemistry totals, the tags, the field, the projected finish, and the sim odds (the field is shown with ratings).
- **Manual hero swaps.** Once all 10 picks are made, every games count is visible. The optimal swap is a 120-case search, which a spreadsheet does as well as an Immortal player, and it beats the Automatic setting about a third of the time (§3a).

---

## 5. OpenDota feasibility (8 live calls, direct curl, no key)

**Access and limits (live, 2026-10-11).** `/api/metadata` returns `freeCallLimit: 3000` (per day) and `freeRateLimit: 60` (per minute). Responses carry `x-rate-limit-remaining-minute` and `x-rate-limit-remaining-day` headers. The day counter jumped around between calls (2796, 2590, 2705, 2739) even though I made only 8 calls. That suggests the free quota is **per IP and shared** with other users of this environment's egress. INFERRED. Keyed use costs $0.01 per 100 calls and needs a card (earlier revision, from `odota/web`), so that's out under your free-only rule.

| Need | Endpoint / table | Real fields (live) | Pro only? | Tag |
|---|---|---|---|---|
| Pro players | `GET /proPlayers` (5,657 rows) | account_id, name, team_id, team_name, team_tag, fantasy_role, country_code, is_pro, is_locked, last_match_time, … | yes (curated) | VERIFIED live |
| Heroes | `GET /heroes` (127) or dotaconstants `heroes.json` | id, name, localized_name, primary_attr, attack_type, roles, legs | — | VERIFIED live |
| Per-player hero games (pro) | `/explorer?sql=` over `player_matches` ⨝ `matches` | Boxi: Tusk 142, Dark Willow 90, Batrider 86, Hoodwink 86, Tiny 79 | yes | VERIFIED live |
| Per-player hero games (all lobbies) | `/players/{id}/heroes?lobby_type=1` | hero_id, games, win, with_games, against_games, last_played | **no**: this includes non-league lobbies (Boxi Tusk 143 vs 142 pro) | VERIFIED live |
| Shared games between two players | explorer self-join on `match_id` + same side (`player_slot < 128`) | Boxi + SabeRLight- **346** (matches 322-0) | yes | VERIFIED live |
| | `/players/{id}/peers?lobby_type=1` | with_games 349, with_win, against_games, name | no | VERIFIED live |
| Roster at an event (a "pack") | explorer: `leagues` ⨝ `matches` ⨝ `player_matches` ⨝ `teams`, with a team = radiant/dire_team_id by slot | TI 2024 = leagueid 16935; e.g. Aurora Gaming: J, Q, Oli~, lorenof, 23savage, 16 games each | yes | VERIFIED live |
| Matches with players | explorer `matches`, `player_matches` | match_id, start_time, leagueid, radiant_win, radiant/dire_team_id; account_id, player_slot, hero_id | yes; range 2012-05-28 → today | VERIFIED |
| Patches | dotaconstants `patch.json` | 6.70 (2010) → 7.41 | — | VERIFIED (earlier revision) |

**Every number 322-0 shows can be rebuilt from free OpenDota explorer aggregates** (player-hero games, groups of players with shared games, rosters per league), at tens of calls in total. All three explorer queries above, including the self-join, came back well under the 15 s timeout. The previous revision's relay errors were a relay problem. VERIFIED

Samples are in [`samples/`](samples/) (`od_*.json`; see `samples/README.md`).

---

## 5b. Valve's official API (free sources only)

**Yes, Valve publishes one**: the Steam Web API (`IDOTA2Match_570/GetMatchHistory`, `GetMatchDetails`, `GetMatchHistoryBySequenceNum`, `IEconDOTA2_570/GetHeroes`, …). OpenDota, Dotabuff, Stratz and datdota all build on it plus replay parsing. It's free with a key from steamcommunity.com/dev/apikey, limited to **100,000 calls/day** (Steam Web API Terms). The key needs a Steam account that has games and must stay private. VERIFIED (earlier revision, ToS and wiki). **I did not create or use a key** (api.steampowered.com is reachable; the methods need `key=`).

It returns raw matches only: no hero-games or games-together aggregates, no reliable pro names, and anonymized players for anyone who hid match data. Building a pro dataset is one GetMatchDetails call per match, a multi-day crawl. INFERRED

| | Valve Steam Web API | OpenDota (no key) |
|---|---|---|
| Cost | Free (key needs a Steam account with games) | Free, **no key** |
| Limit | 100k/day | 3,000/day, 60/min, apparently shared per IP |
| Pro filter | You filter by league yourself | Built in |
| Aggregates | None; you compute them in MySQL | One explorer SQL query each |
| Calls to build the dataset | ~1 per match (tens of thousands) | Tens |

---

## 5d. All free Dota data sources compared (added 2026-10-11 18:05 UTC)

**Access from here:** STRATZ (`api.stratz.com`), Dotabuff and datdota all answer this environment's curl with a **Cloudflare bot challenge** (HTTP 403, `cf-mitigated: challenge`, or datdota's `cfattack` page). I didn't try to get past it, so their rows come from their own docs on GitHub/Medium and from search results. Those are tagged by source age.

| | **OpenDota** | **Valve Steam Web API** | **STRATZ** | **datdota** | **Dotabuff** |
|---|---|---|---|---|---|
| Free public API? | Yes, REST + SQL explorer. VERIFIED live | Yes, REST. VERIFIED | Yes, GraphQL at `api.stratz.com/graphql`, "free" per STRATZ. INFERRED (docs, 2020–21) | Yes, REST, Swagger at `api.datdota.com/swagger-ui`. VERIFIED (datdota wiki) | **No public API** (2012 forum post saying none is planned; nothing newer found). GUESS that this is still true |
| Key? | None needed for the free tier. VERIFIED | Yes, a free key; the Steam account needs games. VERIFIED | Yes, a free Bearer token from stratz.com/api after Steam sign-in. INFERRED (third-party docs) | Some endpoints need a key, "added because of excessive request volume". INFERRED (search summary of datdota's About page) | — |
| Terms | MIT code; data free to use | 100k/day; key confidential; no implied endorsement. VERIFIED | Not found. A 2021 post *asks* users to credit STRATZ (an informal request). GUESS: no formal non-commercial clause | **Non-commercial only**; "please identify yourself with an appropriate user-agent"; commercial use → contact Noxville. VERIFIED (wiki) | robots.txt disallows `/players/*/heroes`, `/players/*/matches`, and the per-event heroes/players/matches pages. VERIFIED. So scraping exactly the data we'd want is off-limits |
| Rate limit | 60/min, 3,000/day, apparently shared per IP. VERIFIED live | 100,000/day. VERIFIED (ToS) | Default token: 20/s, 250/min, 2,000/h, **10,000/day**; Individual token: 4,000/h, 20,000/day. INFERRED (STRATZ GitHub issue, Oct 2020, may be stale) | ≥ 3 s between requests; contact the author above ~500 requests/day. INFERRED (search summary of the About page; I couldn't open it) | — |
| Pro-match coverage | Premium/professional leagues, 2012 → now. VERIFIED | Everything public; you filter leagues yourself. VERIFIED | Pro + pubs, with league tiers. INFERRED | **Pro only, tier 1–2**; it is 322-0's source. VERIFIED (322-0 UI label) | Pro + pubs (website only) |
| Hero-games per player | Explorer `GROUP BY` (pro), or `/players/{id}/heroes`. VERIFIED | No; compute it yourself. VERIFIED | Yes, per-player hero performance in GraphQL. INFERRED (not tested) | Yes; the site shows player-hero stats. INFERRED | Website only, and robots-disallowed |
| Shared games (pairs) | Explorer self-join (346 ✓), or `/peers`. VERIFIED | No; compute it yourself | Probably (player peers / "played with"). GUESS | Probably (322-0's `squadSynergy` looks like a datdota export). INFERRED | Website only |
| Bulk use OK? | Yes, within the limits | Yes, within the limits | Yes, within the token limits | **No**: the wiki says not to use it in place of Valve's API for bulk pulls (e.g. every match of a league) | No |

**Reading it:**
- For a free, keyless, legally simple course dataset, **OpenDota is the only one verified end to end**.
- **Valve** is the official root source, but it means computing everything yourself.
- **STRATZ** has the highest documented free limits, but it needs a Steam-linked token, and I couldn't check its current terms or limits from here.
- **datdota** has exactly 322-0's data, but its terms (non-commercial, low volume, no bulk pulls) make it a poor bulk source. It works as a cross-check.
- **Dotabuff** isn't a data source for us: there's no API, and robots.txt bars the relevant pages.

Sources: [datdota API wiki](https://github.com/datdota/datdota/wiki/API-Intro-&-Gotchas), [datdota About](https://www.datdota.com/about) (search summary only), [STRATZ rate limits issue #15](https://github.com/STRATZ-eSports/knowledge-base/issues/15), [STRATZ API update post](https://stratz.medium.com/stratz-api-major-update-5557335dbdfd), [Pipeworx STRATZ docs](https://pipeworx.io/docs/reference/stratz/), [Dotabuff API forum post (2012)](https://www.dotabuff.com/topics/2012-11-28-dotabuff-api), dotabuff.com and stratz.com `robots.txt` (fetched live).

---

## 5c. Rating options without per-player-per-event (unchanged, plus one new data point)

You ruled out per-event ratings. New evidence: even 322-0 has one **career-level** stat, `reliability`, which is constant for each player across every event (§2).

| Option | How it's computed | Pros | Cons |
|---|---|---|---|
| **A. Career win rate, Bayesian-adjusted** | `(wins + k·0.5) / (games + k)` over pro matches, scaled to 60–99 | One GROUP BY | Ignores opponent strength |
| **B. Player Elo / Glicko** | Replay pro matches in order and update each player from the team result | Rewards beating strong teams; a procedure-plus-transaction demo | Iterative (PHP or a stored procedure); tuning K |
| **C. Inherit from team rating** | Games-weighted average of OpenDota `team_rating` over teams played for | Very cheap | A great player on a weak team is underrated |
| **D. Peak window** | Best rolling N-game win rate or Elo, via a window function | Captures a player's prime; a showcase window query | Noisy for low-game players |
| **E. Per player + role** | Any of A–D split by position | Fits the 5 slots | Old matches lack lane data |
| **F. Curated** | Hand-tuned, seeded by A–D | Full control | Manual and subjective |
| **G. Per player per era (new)** | A–D computed per patch window or year instead of per event | Keeps "Ceb then vs now" variety with far fewer rows than per event | Era boundaries are a design choice |

Pack options once there's no event: team (an org's all-time players), era, role, or random. Team and era packs keep chemistry meaningful.

---

## 6. Draft database mapping (plain English, not a schema; MySQL 8.0+)

Mapping each number the game shows:

- **Card rating.** A lookup in a players (or player × role / era) table, computed in a batch step (§5c).
- **Base.** `AVG(rating)` over a run's 5 player picks (`run_pick ⨝ player`, `GROUP BY run`).
- **Hero games ("134 games").** match → match_player (match, player, hero, side) → hero. `COUNT(*)` per (player, hero), stored in a **player_hero_stats** summary table.
- **Hero assignment + synergy.** Needs the 5×5 grid of games: a cross join of the run's player picks × hero picks, left-joined to player_hero_stats. The best permutation is either (a) brute-forced in PHP over 120 cases, or (b) done in SQL with a recursive CTE that builds permutations. (b) is a nice CTE exercise but heavy, and 120 rows is fine either way. Bonus = `SUM(LEAST(1, games/25)) * 1.5` if you keep 322-0's curve; that's your call.
- **Chemistry.** Pairs: **self-join** match_player on the same match and same side, `a.player < b.player`, `GROUP BY a, b`, `COUNT`. 322-0 also scores trios, quads and five-stacks: either a 3-, 4- and 5-way self-join (expensive), or a **lineup** table (the 5 account_ids per side per match, sorted) from which you count subsets. For a run, join the C(5,2)=10 pairs (+10 trios, 5 quads, 1 five) of picks to the summary tables, weight by size, `LEAST(cap, …)`, and `SUM`.
- **Field.** A per-run field table (name, strength), generated in PHP from a name-pool table and a seeded random number (store the seed for replays).
- **Projected finish.** `RANK() OVER (ORDER BY strength DESC)` across your team ∪ field. A **window function**.
- **TI sim.** A sim_match table (run, stage, team_a, team_b, best_of, score_a, score_b, seed). Group standings: `SUM(wins) … GROUP BY team` then `ROW_NUMBER() OVER (PARTITION BY group ORDER BY wins DESC, strength DESC)`. Placement = the stage where you were eliminated.
- **History / leaderboard.** A run table with the result. Best run per user via `ROW_NUMBER() OVER (PARTITION BY user ORDER BY place, overall DESC)`. Counts via `SUM(CASE WHEN place = 1 THEN 1 ELSE 0 END)` (MySQL has no `FILTER`).

**MySQL specifics** (from MySQL 8.0 documentation as I know it, not re-checked this session; confirm the lab version): window functions and (recursive) CTEs need 8.0+. `CHECK` is enforced only from 8.0.16. There are no materialized views (summaries are plain tables refreshed by a script, a procedure or `EVENT`). Upsert is `INSERT … ON DUPLICATE KEY UPDATE`. The OpenDota explorer speaks Postgres, so the ETL boundary is Postgres → CSV/JSON → MySQL.

**Course-lesson hooks:**
- **Normalization.** match → match_player → player/hero is clean 3NF. player_hero_stats, player_pair_stats and lineup are deliberate **denormalizations**, rebuilt in batch.
- **Window functions.** Field rank, group standings, best run per user, top hero per player.
- **Recursive CTE.** Hero-assignment permutations (optional showcase).
- **Transactions.** A reroll = check `rerolls_left > 0`, decrement and insert the new pack atomically. A pick = insert the pick, mark the slot and draw the next pack together. Finishing = write the field, every sim_match row and the result, or none of them.
- **Concurrency.** Double-clicking reroll or simulate in two tabs: `SELECT … FOR UPDATE` on the run row (or a version column), plus `UNIQUE(run, slot)` and `UNIQUE(run, hero)`.
- **Constraints.** `CHECK (a < b)` on the pair table; role-slot rules (exactly 1 safelane, 1 mid, 1 offlane, 2 supports) as a CHECK or a trigger.

---

## 7. Risks

- **Rate limits.** OpenDota free is 3,000/day and 60/min, and the day budget appears shared per IP (§5), so pull once into MySQL and never call live during gameplay. Valve needs a key (a Steam account with games). Explorer has a 15 s timeout; my heaviest test (TI 2024 rosters) was fine, but whole-history 3–5-player lineup counts may need splitting by year.
- **Data gaps.** OpenDota pro coverage depends on leagues being tagged premium/professional, and early years may be thin. `notable_players.name` is the *current* handle (Boxi's peers row shows "Saberlight" for SabeRLight-). 322-0's "tier 1–2" set (datdota) differs slightly from OpenDota's pro set (Tusk 134 vs 142). There's no ready-made player rating, which you'd define (§5c).
- **Valve assets / fan content.** Hero names and portraits are Valve IP. 322-0 hot-links datdota's CDN; you should use dotaconstants or Valve CDN images under Valve's fan-content terms (not re-verified this session; GUESS on specifics). A non-commercial course demo is lowest risk. Pro players are real people.
- **Licensing.** OpenDota core and dotaconstants are MIT. 322-0's code and data are the author's (no license seen), so build our own from OpenDota and don't reuse their JSON.
- **Remaining unknowns.** How `ovr`, impact and economy are computed (datdota-side). The UI wasn't clicked through (no browser tools), so animations and exact screen layout come from code, not observation.

---

## 8. Open questions for you

**Answered by Sadman, 2026-10-11 18:03 UTC:**
- Pack type: **team** packs (an org's players).
- Data source: **both** OpenDota and Valve's Steam Web API.
- Chemistry: **pairs, trios, quads and five-stacks**, like 322-0 (needs the lineup table from §6).
- MySQL: development and the demo run on Sadman's own machines, so **MySQL 8.0+ features are available** (window functions, CTEs, enforced CHECKs). The lab version doesn't matter.
- Hero allocation: **both** automatic and manual.

**Still open:**
1. Which rating option (§5c, A–G)?
2. Data source: OpenDota explorer without a key (tens of calls, the 346 matched exactly), Valve's API (official, you compute everything, needs a Steam key), or both?
3. Should chemistry count only pairs (simple self-join) or also trios through five-stacks like 322-0 (a lineup table, more SQL)?
4. Does your lab have **MySQL 8.0+**? Window functions, CTEs and enforced CHECKs depend on it.
5. Should hero allocation be automatic, manual, or both, given that 322-0's automatic mode is beaten by manual about a third of the time?

---

**Sources:** 322-0.app (page, `/assets/index-BCFh8CR5.js`, `/data/*.json`, fetched 2026-10-11); 82-0.com home page, `/robots.txt`, `/sitemap.xml`; api.opendota.com (8 calls, `samples/od_*.json`); earlier revision's sources: Noxville on X, Cybersport.ru guide, github.com/odota/core @ b877fd1, odota/web, odota/dotaconstants, Steam Web API Terms, TF2 wiki WebAPI pages.
