-- =====================================================================
--  DRAFT FOR REVIEW: loading the pulled CSVs and building layer B.
--  Not run against MySQL yet. Requires schema_draft.sql first.
--  Run once at build time (and again whenever data is refreshed).
--
--  Steps
--    1. Staging tables + LOAD DATA (CSV files from data/raw and data/processed;
--       gunzip *.csv.gz first, and enable local_infile on client and server)
--    2. Reference tables from staging
--    3. Derived position per player row (window functions)
--    4. Era cards (CTEs), card stats, ratings (PERCENT_RANK)
--    5. Chemistry pairs (self-join), hero stats, matchups
--  Knobs are user variables at the top so the balance script can change them.
-- =====================================================================
USE ati;

SET @min_card_games   = 150;   -- games in a window to get a card (DEFAULT)
SET @shrink_k         = 50;    -- pull win rates toward 50% (k games of 0.5)
SET @peak_n           = 100;   -- rolling window for "peak"
SET @w_wr = 0.30, @w_peak = 0.25, @w_cons = 0.15, @w_place = 0.30;  -- weights (DEFAULT)
SET @curve_gamma      = 1.30;  -- rating = 68 + 31 * pct^gamma (KNOB)
SET @recent_from      = '2024-01-01';  -- hero stats period

-- ---------------------------------------------------------------------
-- 1. STAGING
-- ---------------------------------------------------------------------
CREATE TABLE stg_match (
    match_id BIGINT, leagueid INT, start_time BIGINT, duration INT, radiant_win VARCHAR(5),
    radiant_team_id INT, dire_team_id INT, radiant_team_name VARCHAR(200), dire_team_name VARCHAR(200),
    radiant_score INT, dire_score INT, series_id INT, series_type INT, patch INT
) ENGINE=InnoDB;

CREATE TABLE stg_player_match (
    match_id BIGINT, account_id BIGINT, player_slot INT, hero_id INT, lane INT, lane_role INT,
    is_roaming VARCHAR(5), gold_per_min INT, xp_per_min INT, last_hits INT, kills INT, deaths INT,
    assists INT, gold_10 INT, xp_10 INT, lh_10 INT
) ENGINE=InnoDB;

-- (stg_league, stg_team, stg_notable, stg_hero, stg_mechanic, stg_alias,
--  stg_tournament, stg_placement follow the same pattern: one column per CSV header.)

-- One LOAD DATA per file; a PHP or shell loop can generate these lines.
-- LOAD DATA LOCAL INFILE 'data/raw/opendota/matches/m_20240101.csv'
--   INTO TABLE stg_match FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
--   LINES TERMINATED BY '\n' IGNORE 1 LINES
--   (match_id, leagueid, start_time, duration, radiant_win, @rt, @dt, radiant_team_name,
--    dire_team_name, radiant_score, dire_score, @sid, @st, @patch)
--   SET radiant_team_id = NULLIF(@rt,''), dire_team_id = NULLIF(@dt,''),
--       series_id = NULLIF(@sid,''), series_type = NULLIF(@st,''), patch = NULLIF(@patch,'');

-- ---------------------------------------------------------------------
-- 2. REFERENCE TABLES
-- ---------------------------------------------------------------------
-- Teams first (only ids that appear in matches), then matches, then accounts, then player rows.
INSERT INTO pro_match (match_id, league_id, start_time, duration_s, radiant_win,
                       radiant_team_id, dire_team_id, series_id, series_type, patch_id)
SELECT match_id, leagueid, FROM_UNIXTIME(start_time), duration, radiant_win = 'True',
       NULLIF(radiant_team_id, 0), NULLIF(dire_team_id, 0), series_id, series_type, patch
FROM stg_match;

-- Every account seen; the alias table (data/processed/player_alias_candidates.csv,
-- hand-checked) then sets player_id and alias_status.
INSERT IGNORE INTO account (account_id)
SELECT DISTINCT account_id FROM stg_player_match
WHERE account_id IS NOT NULL AND account_id <> 4294967295;   -- anonymous Valve id

INSERT INTO match_player (match_id, player_slot, account_id, hero_id, lane, lane_role, is_roaming,
                          gpm, xpm, last_hits, kills, deaths, assists, gold_10, xp_10, lh_10)
SELECT match_id, player_slot, NULLIF(account_id, 4294967295), hero_id, lane, lane_role,
       is_roaming = 'True', gold_per_min, xp_per_min, last_hits, kills, deaths, assists,
       gold_10, xp_10, lh_10
FROM stg_player_match;

-- ---------------------------------------------------------------------
-- 3. ESTIMATED POSITION (research rule, INFERRED)
--    mid lane -> 2; safe lane: higher GPM = 1, other = 5; off lane: higher GPM = 3, other = 4.
--    Before 2016 (no lane_role): GPM rank within the team, 1..5.
-- ---------------------------------------------------------------------
WITH ranked AS (
    SELECT match_id, player_slot, lane_role,
           ROW_NUMBER() OVER (PARTITION BY match_id, is_radiant, lane_role ORDER BY gpm DESC) AS rk_lane,
           ROW_NUMBER() OVER (PARTITION BY match_id, is_radiant ORDER BY gpm DESC)            AS rk_team
    FROM match_player
)
UPDATE match_player mp JOIN ranked r USING (match_id, player_slot)
SET mp.est_pos = CASE
    WHEN r.lane_role IS NULL      THEN r.rk_team
    WHEN r.lane_role = 2          THEN 2
    WHEN r.lane_role = 1          THEN IF(r.rk_lane = 1, 1, 5)
    WHEN r.lane_role = 3          THEN IF(r.rk_lane = 1, 3, 4)
    ELSE r.rk_team END;           -- jungle / odd lanes fall back to team GPM rank

-- ---------------------------------------------------------------------
-- 4. ERA CARDS
--    window = GREATEST(3 years, career / 3); cards = 1..3; short tail merges.
-- ---------------------------------------------------------------------
CREATE TEMPORARY TABLE player_game AS                   -- one row per (player, match)
SELECT a.player_id, mp.match_id, m.start_time, m.league_id, mp.hero_id, mp.est_pos,
       (mp.is_radiant = m.radiant_win) AS won
FROM match_player mp
JOIN account a   ON a.account_id = mp.account_id AND a.player_id IS NOT NULL
JOIN pro_match m ON m.match_id = mp.match_id;

CREATE TEMPORARY TABLE player_window AS
WITH career AS (
    SELECT player_id, MIN(start_time) AS debut, MAX(start_time) AS last_game,
           DATEDIFF(MAX(start_time), MIN(start_time)) AS len_days
    FROM player_game GROUP BY player_id
)
SELECT player_id, debut, len_days,
       GREATEST(3 * 365, len_days / 3)                                   AS window_days,
       GREATEST(1, LEAST(3, FLOOR(len_days / GREATEST(3 * 365, len_days / 3)))) AS n_cards
FROM career;

-- Regular table, not TEMPORARY: MySQL can't open a temporary table twice in one query.
CREATE TABLE player_game_card AS
SELECT g.*, LEAST(FLOOR(DATEDIFF(g.start_time, w.debut) / w.window_days), w.n_cards - 1) AS card_index
FROM player_game g JOIN player_window w USING (player_id);

INSERT INTO player_card (player_id, card_index, start_date, end_date, games, wins, primary_pos,
                         c_winrate, c_peak, c_consistency, c_placements, rating)
SELECT player_id, card_index, DATE(MIN(start_time)), DATE(MAX(start_time)), COUNT(*), SUM(won),
       1, 0, 0, 0, 0, 50                                  -- placeholders, filled below
FROM player_game_card
GROUP BY player_id, card_index
HAVING COUNT(*) >= @min_card_games;

INSERT INTO card_position (card_id, pos, games, wins)
SELECT c.card_id, g.est_pos, COUNT(*), SUM(g.won)
FROM player_game_card g JOIN player_card c USING (player_id, card_index)
WHERE g.est_pos IS NOT NULL GROUP BY c.card_id, g.est_pos;

UPDATE player_card c
JOIN (SELECT card_id, pos, ROW_NUMBER() OVER (PARTITION BY card_id ORDER BY games DESC) rn
      FROM card_position) t ON t.card_id = c.card_id AND t.rn = 1
SET c.primary_pos = t.pos;

-- Main and alternate roles (Sadman, 2026-10-12): alt = at least 15% of the card's matches
-- at that position, or the main role of another card of the same player.
UPDATE card_position cp JOIN player_card c USING (card_id)
SET cp.role_kind = CASE
    WHEN cp.pos = c.primary_pos THEN 'main'
    WHEN cp.games >= 0.15 * c.games THEN 'alt'
    WHEN EXISTS (SELECT 1 FROM (SELECT player_id, card_id, primary_pos FROM player_card) o
                 WHERE o.player_id = c.player_id AND o.card_id <> c.card_id AND o.primary_pos = cp.pos) THEN 'alt'
    ELSE 'off' END;

INSERT INTO card_hero (card_id, hero_id, games, wins)
SELECT c.card_id, g.hero_id, COUNT(*), SUM(g.won)
FROM player_game_card g JOIN player_card c USING (player_id, card_index)
GROUP BY c.card_id, g.hero_id;

-- Rating components -----------------------------------------------------
-- Top-4 finishes per card (same join path as the placement points below), used for longevity.
CREATE TABLE etl_card_top4 AS
SELECT c.card_id, COUNT(DISTINCT pl.tournament_id) AS n
FROM player_card c
JOIN player_game_card g USING (player_id, card_index)
JOIN match_player mp ON mp.match_id = g.match_id
JOIN account a       ON a.account_id = mp.account_id AND a.player_id = c.player_id
JOIN pro_match m     ON m.match_id = g.match_id
JOIN org_team ot     ON ot.team_id = IF(mp.is_radiant, m.radiant_team_id, m.dire_team_id)
JOIN tournament_league tl ON tl.league_id = m.league_id
JOIN placement pl    ON pl.tournament_id = tl.tournament_id AND pl.org_id = ot.org_id AND pl.place_from <= 4
GROUP BY c.card_id;

CREATE TEMPORARY TABLE card_comp AS
WITH roll AS (                                          -- rolling 100-game win rate
    SELECT c.card_id,
           AVG(g.won) OVER (PARTITION BY c.card_id ORDER BY g.start_time
                            ROWS BETWEEN 99 PRECEDING AND CURRENT ROW) AS wr_roll,
           ROW_NUMBER() OVER (PARTITION BY c.card_id ORDER BY g.start_time) AS n
    FROM player_game_card g JOIN player_card c USING (player_id, card_index)
),
peak AS (SELECT card_id, MAX(wr_roll) AS peak FROM roll WHERE n >= @peak_n GROUP BY card_id),
ev AS (                                                 -- per-event win rate (events with 5+ games)
    SELECT c.card_id, g.league_id, AVG(g.won) AS wr
    FROM player_game_card g JOIN player_card c USING (player_id, card_index)
    GROUP BY c.card_id, g.league_id HAVING COUNT(*) >= 5
),
steady AS (SELECT card_id, 1 - COALESCE(STDDEV_SAMP(wr), 0.25) AS steady FROM ev GROUP BY card_id),
-- Longevity (Sadman, 22:07): tier-1 events attended and top-4 finishes in the window,
-- so a one-off winner who then missed tier-1 events or retired ranks below a steady 3rd-place finisher.
t1 AS (
    SELECT c.card_id, COUNT(DISTINCT tl.tournament_id) AS t1_events
    FROM player_game_card g JOIN player_card c USING (player_id, card_index)
    JOIN tournament_league tl ON tl.league_id = g.league_id
    JOIN tournament t ON t.tournament_id = tl.tournament_id AND t.lp_tier = 1
    GROUP BY c.card_id
),
cons AS (
    SELECT c.card_id,
           0.5 * COALESCE(s.steady, 0.75)
         + 0.5 * PERCENT_RANK() OVER (ORDER BY COALESCE(t1.t1_events, 0) + 2 * COALESCE(top4.n, 0)) AS cons
    FROM player_card c
    LEFT JOIN steady s USING (card_id)
    LEFT JOIN t1 USING (card_id)
    LEFT JOIN (SELECT card_id, n FROM etl_card_top4) top4 USING (card_id)
)
SELECT c.card_id,
       (c.wins + @shrink_k * 0.5) / (c.games + @shrink_k) AS wr_adj,
       COALESCE(p.peak, c.wins / c.games)               AS peak,
       COALESCE(k.cons, 0.75)                           AS cons,
       0.0                                              AS place_pts
FROM player_card c LEFT JOIN peak p USING (card_id) LEFT JOIN cons k USING (card_id);

-- Placement points: a card earns a tournament's points if the player played
-- that tournament's leagues for a team of the placed org, inside the card window.
UPDATE card_comp cc JOIN (
    SELECT card_id, SUM(pts) AS place_pts FROM (
        SELECT c.card_id, t.tournament_id,
               MAX(t.weight * CASE WHEN pl.place_from = 1 THEN 100 WHEN pl.place_from = 2 THEN 70
                                   WHEN pl.place_from <= 4 THEN 50 WHEN pl.place_from <= 8 THEN 30
                                   WHEN pl.place_from <= 16 THEN 15 ELSE 0 END) AS pts,
               ROW_NUMBER() OVER (PARTITION BY c.card_id ORDER BY
                   MAX(t.weight * CASE WHEN pl.place_from = 1 THEN 100 WHEN pl.place_from = 2 THEN 70
                                       WHEN pl.place_from <= 4 THEN 50 WHEN pl.place_from <= 8 THEN 30
                                       WHEN pl.place_from <= 16 THEN 15 ELSE 0 END) DESC) AS rn
        FROM player_card c
        JOIN player_game_card g USING (player_id, card_index)
        JOIN match_player mp    ON mp.match_id = g.match_id
        JOIN account a          ON a.account_id = mp.account_id AND a.player_id = c.player_id
        JOIN pro_match m        ON m.match_id = g.match_id
        JOIN org_team ot        ON ot.team_id = IF(mp.is_radiant, m.radiant_team_id, m.dire_team_id)
        JOIN tournament_league tl ON tl.league_id = m.league_id
        JOIN tournament t       ON t.tournament_id = tl.tournament_id
        JOIN placement pl       ON pl.tournament_id = t.tournament_id AND pl.org_id = ot.org_id
        GROUP BY c.card_id, t.tournament_id
    ) x WHERE rn <= 5 GROUP BY card_id                  -- best 5 events
) p USING (card_id)
SET cc.place_pts = p.place_pts;

-- Percentiles, weighted mix, curve onto 68..99
UPDATE player_card c JOIN (
    SELECT card_id, pr_wr, pr_peak, pr_cons, pr_place,
           PERCENT_RANK() OVER (ORDER BY @w_wr*pr_wr + @w_peak*pr_peak + @w_cons*pr_cons + @w_place*pr_place) AS pr_mix
    FROM (SELECT card_id,
                 PERCENT_RANK() OVER (ORDER BY wr_adj)    AS pr_wr,
                 PERCENT_RANK() OVER (ORDER BY peak)      AS pr_peak,
                 PERCENT_RANK() OVER (ORDER BY cons)      AS pr_cons,
                 PERCENT_RANK() OVER (ORDER BY place_pts) AS pr_place
          FROM card_comp) a
) r USING (card_id)
SET c.c_winrate = r.pr_wr, c.c_peak = r.pr_peak, c.c_consistency = r.pr_cons,
    c.c_placements = r.pr_place,
    c.rating = ROUND(68 + 31 * POW(r.pr_mix, @curve_gamma));

-- ---------------------------------------------------------------------
-- 5. CHEMISTRY, HERO STATS, MATCHUPS
-- ---------------------------------------------------------------------
-- Pairs: same match, same side, two different card players (self-join).
INSERT INTO player_pair (player_a, player_b, games)
SELECT a1.player_id, a2.player_id, COUNT(*)
FROM match_player x
JOIN match_player y ON y.match_id = x.match_id AND y.is_radiant = x.is_radiant AND y.player_slot <> x.player_slot
JOIN account a1 ON a1.account_id = x.account_id
JOIN account a2 ON a2.account_id = y.account_id
WHERE a1.player_id < a2.player_id
GROUP BY a1.player_id, a2.player_id
HAVING COUNT(*) >= 10;

INSERT INTO stat_period (label, date_from, date_to) VALUES ('2024+', @recent_from, '2099-12-31');
SET @p = LAST_INSERT_ID();

INSERT INTO hero_position_share (hero_id, period_id, pos, games, share)
SELECT hero_id, @p, est_pos, n, n / SUM(n) OVER (PARTITION BY hero_id)
FROM (SELECT mp.hero_id, mp.est_pos, COUNT(*) n
      FROM match_player mp JOIN pro_match m USING (match_id)
      WHERE m.start_time >= @recent_from AND mp.est_pos IS NOT NULL
      GROUP BY mp.hero_id, mp.est_pos) t;

-- Counters: hero vs hero on opposite sides, shrunk toward 50% (k = 30), minus expected 50%.
INSERT INTO hero_matchup (hero_id, vs_hero_id, period_id, games, wins, edge)
SELECT x.hero_id, y.hero_id, @p, COUNT(*), SUM(x.is_radiant = m.radiant_win),
       (SUM(x.is_radiant = m.radiant_win) + 15) / (COUNT(*) + 30) - 0.5
FROM match_player x
JOIN match_player y ON y.match_id = x.match_id AND y.is_radiant <> x.is_radiant
JOIN pro_match m    ON m.match_id = x.match_id
WHERE m.start_time >= @recent_from
GROUP BY x.hero_id, y.hero_id;

-- Mid lane matchups: both mids, gold at 10 minutes.
INSERT INTO lane_matchup (hero_id, vs_hero_id, lane_kind, period_id, games, avg_gold_diff)
SELECT x.hero_id, y.hero_id, 'mid', @p, COUNT(*), ROUND(AVG(x.gold_10 - y.gold_10))
FROM match_player x
JOIN match_player y ON y.match_id = x.match_id AND y.is_radiant <> x.is_radiant
JOIN pro_match m    ON m.match_id = x.match_id
WHERE m.start_time >= @recent_from AND x.lane_role = 2 AND y.lane_role = 2
  AND x.gold_10 IS NOT NULL AND y.gold_10 IS NOT NULL
GROUP BY x.hero_id, y.hero_id;
-- Side lanes: safe-lane core vs the enemy off-lane core (est_pos 1 vs 3), same pattern with 'side'.

INSERT INTO hero_phase_stat (hero_id, period_id, bucket, games, wins)
SELECT mp.hero_id, @p,
       CASE WHEN m.duration_s < 1800 THEN 'lt30' WHEN m.duration_s < 2700 THEN '30to45' ELSE 'ge45' END,
       COUNT(*), SUM(mp.is_radiant = m.radiant_win)
FROM match_player mp JOIN pro_match m USING (match_id)
WHERE m.start_time >= @recent_from
GROUP BY mp.hero_id, 3;

DROP TEMPORARY TABLE player_game, player_window, card_comp;
DROP TABLE player_game_card, etl_card_top4;
