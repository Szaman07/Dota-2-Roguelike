# OpenDota samples

## `od_*.json`: direct curl, 2026-10-11 ~17:50 UTC (8 calls, no key)
Saved straight from `api.opendota.com/api`. Large responses are trimmed (each file's `_note` says how); row values are unmodified.
- `od_metadata.json`: `/metadata` (freeCallLimit 3000/day, freeRateLimit 60/min).
- `od_proPlayers_trimmed.json`: `/proPlayers` (5,657 rows in total).
- `od_heroes_trimmed.json`: `/heroes` (127 heroes).
- `od_players_77490514_heroes_lobby1_trimmed.json`: Boxi's `/players/{id}/heroes?lobby_type=1`.
- `od_players_77490514_peers_lobby1_trimmed.json`: Boxi's `/players/{id}/peers?lobby_type=1`, including the SabeRLight- row.
- `od_explorer_boxi_heroes.json`: explorer SQL, Boxi's pro games per hero.
- `od_explorer_pair_boxi_saber.json`: explorer self-join, Boxi + SabeRLight- pro games on the same side (returns **346**, the same as 322-0 shows).
- `od_explorer_ti2024_rosters.json`: explorer SQL, who played for which team at TI 2024 (a "pack").

## Older files (earlier thread, network blocked)
- `live_*.json` files contain values returned by the live API on 2026-10-11 via a relay fetch tool (formatting may differ).
- `spec_*.json` files list field names taken from OpenDota's OpenAPI spec (github.com/odota/core, `svc/api/responses/*.ts`, commit b877fd1). They are not live responses.

## Added 18:20 UTC (3 more explorer calls, for rating/roles research)
- `od_explorer_lane_cov_ti.json`: `lane_role` and `gold_per_min` coverage at each TI (lane_role is present from TI 2016 on).
- `od_explorer_hero_pos.json`: estimated position (lane_role + farm rank in lane) for Gyrocopter (72) and Shadow Fiend (11), pro matches since 2024.
- `od_explorer_placement_proxy.json`: TI 2024 teams ranked by the date of their last match (a placement proxy).

## Added 19:00 UTC (4 more explorer calls, for team-synergy research; one timed out and isn't saved)
- `od_explorer_pm_cols.json`: `player_matches` columns useful for laning and teamfights (gold_t, xp_t, lh_t, lane, lane_role, stuns, teamfight_participation…).
- `od_explorer_hero_duration.json`: win rate by game length (<30, 30–45, 45+ min) for 10 heroes, pro matches since 2024.
- `od_explorer_mid_lane10.json`: average gold/XP lead at 10:00 vs the enemy mid, 8 mid heroes, pro matches since June 2025.

## Added 19:10 UTC (2 explorer calls, for edge cases)
- `od_explorer_alias.json`: pros with several Steam accounts in `notable_players` (Yatoro 6, Miracle- 2).
- `od_explorer_teams_alias.json`: team-name collisions (two real "Natus Vincere" team_ids, 36 and 9828954, plus many look-alikes).
