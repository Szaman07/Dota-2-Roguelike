# 322-0: how the game works, and what a PHP/SQL clone needs

## What it is

- **322-0** (https://322-0.app) is a free browser game made by Dota 2 analyst Ben "Noxville" Steenhuisen. Its tagline is *"Draft a frankenstein all-time team from historic Dota 2 LAN packs and win a simulated International."*
- It belongs to a family of "perfect record" draft games. **82-0** (NBA: draft 5 players, then simulate an unbeaten 82-game season) came first, then **38-0** (Premier League). Noxville said he based 322-0 on 38-0.
- The site is a client-rendered JS app and our sandbox could not download its source, so the mechanics below come from your screenshot plus two articles. Anything marked *(inferred)* is my reading of the numbers, not something confirmed.

## The run loop

1. **Choose a mode.** The front page has a filter. "Standard" uses only tier-1 events from roughly the last two seasons. The default pool spans Dota's whole history.
2. **Draft rounds.** Each round opens a **pack**: one historic **roster at a specific LAN** (for example "Team X at TI8"), which shows its **five players and five heroes**. You take one player and one hero for your lineup. Roles and ratings belong to that event, so one person can appear more than once with different values (Ceb is 85+ in his TI-winning era and 64 in another; n0tail is a carry at the Kiev Major but a support at TI8).
3. **Fill five slots.** The slots are Carry, Mid, Offlane and two Supports, arranged on the pentagon in your screenshot.
4. **Reroll.** Standard mode gives you **one** reroll of an offered pack. The field panel also has a "Re-roll" button that rerolls the 17 opponent teams.
5. **Assign heroes.** The game places each hero on a position, and you cannot directly move a flexible hero such as Enigma or Mirana to the role you wanted. You can, however, **tap two players to swap their heroes** ("Hero Allocation" in the screenshot).
6. **Check your projection.** The live panel shows your Team OVR ranked against an **18-team field** and a projected finish (yours says "1st–3rd").
7. **Simulate The International.** Your final placement is the result: winning gives you the **Aegis**, and anything less ends at a placement such as top 8 or top 12.
8. **Abandon Run** ("Smurf Detected") throws the run away and starts over.

**Win:** you win The International. **Loss:** any other placement, or abandoning. The title "322-0" refers to a flawless run.

## Rating math (taken from the screenshot)

```
Team OVR = Base + Hero Synergy + Chemistry
94       = 85   + 7.5          + 1.5
```

- **Base** is the average of the five event ratings: (87+95+76+80+86)/5 = 84.8, shown as 85.
- **Hero Synergy** grows with how many pro games each player has on their assigned hero. Your lineup had Boxi on Tusk (134 games), SabeRLight- on Mars (122), Gpk on Puck (117), Yatoro on Terrorblade (100) and PlAnet on Tiny (25), for a total of +7.5. The UI labels it with tiers ("INSANE!"). *(Inferred: a tiered bonus of roughly +1.5 to +2 per player once they have about 100 games on the hero.)* Heroes released recently (Marci, Muerta, Dawnbreaker) have few pro games, so they give almost nothing.
- **Chemistry** applies to each pair of your players who have played together. Boxi and SabeRLight- have 346 shared games, which gives +1.5. *(Inferred: tiered by shared games.)*
- **The field** is 17 generated teams named after Dota memes, with OVRs between 76 and 95 in the screenshot. You are ranked among them by OVR.
- **Simulation** *(inferred)* is probably a series of matches where the higher OVR has the better win probability, for example a logistic function of the OVR difference. It plays out a TI bracket and returns your placement.

## Data entities a clone would need

| Table | Key columns |
|---|---|
| `player` | id, nickname, country |
| `team` | id, name (historic org) |
| `event` | id, name (TI8, Kiev Major...), year, tier |
| `roster_entry` (the "pack") | event_id, team_id, player_id, position (1–5), rating |
| `hero` | id, name, primary_attr, release_year, image |
| `player_hero_stats` | player_id, hero_id, games, wins |
| `player_pair_stats` | player_a_id, player_b_id, games_together |
| `synergy_tier` / `chemistry_tier` | min_games, bonus (lookup tables) |
| `app_user` | id, username, password_hash |
| `run` | id, user_id, mode, status (drafting/finished/abandoned), rerolls_left, base, synergy, chemistry, ovr, final_place, created_at |
| `run_pick` | run_id, slot (1–5), roster_entry_id, hero_id |
| `run_pack_offer` | run_id, round, roster_entry/team offered, was_rerolled |
| `field_team` | run_id, name, ovr |
| `match` | run_id, stage, team_a, team_b, winner |

The design gives you plenty of material for a DBMS course: foreign keys, a composite key on `player_hero_stats`, a symmetric pair table on `player_pair_stats` (enforce `a_id < b_id`), aggregate queries for OVR such as AVG plus a SUM joined to the tier tables, and leaderboards (`GROUP BY user`, counting Aegis wins).

## Sources

- https://322-0.app/ (title and meta description)
- Noxville's launch post: https://x.com/Noxville/status/2063961567884931132
- Noxville on "Standard" mode: https://x.com/Noxville/status/2064412967500665045
- Cybersport.ru guide: https://www.cybersport.ru/tags/dota-2/vyigrali-the-international-s-dendi-na-mide-v-novoi-igre-po-dota-2-ochen
- 82-0 lineage: https://82-0-challenge.com/82-0-football and https://khelnow.com/football/how-play-38-0-football-game-premier-league-team-builder-inspired-82-0-202606
