-- =====================================================================
--  DRAFT FOR REVIEW: the main queries the game and the course demo need.
--  Placeholders like :run_id are PDO named parameters (prepared statements,
--  which also covers the SQL-injection part of the course).
-- =====================================================================
USE ati;

-- 1. Draw a pack: a random org with >= 3 eligible cards, then 5 random players of it.
--    The PHP side seeds its own RNG from run.seed + pack_no and passes :r1/:r2 in [0,1),
--    so a reload shows the same pack.
WITH eligible AS (
    SELECT org_id, COUNT(DISTINCT c.player_id) AS n
    FROM card_org co JOIN player_card c USING (card_id)
    WHERE co.games >= 30 GROUP BY org_id HAVING n >= 3
), numbered AS (
    SELECT org_id, ROW_NUMBER() OVER (ORDER BY org_id) AS rn, COUNT(*) OVER () AS total FROM eligible
)
SELECT org_id FROM numbered WHERE rn = 1 + FLOOR(:r1 * total);

SELECT card_id, player_id FROM (
    SELECT c.card_id, c.player_id,
           ROW_NUMBER() OVER (PARTITION BY c.player_id ORDER BY RAND(:seed_a)) AS pick_card,
           RAND(:seed_b) AS r
    FROM card_org co JOIN player_card c USING (card_id)
    WHERE co.org_id = :org_id AND co.games >= 30
) t WHERE pick_card = 1 ORDER BY r LIMIT 5;

-- 2. Chemistry for the 5 drafted players: every subset of size 2..5 with its games together.
--    Groups are found from match_player directly (on demand), then weighted in PHP
--    (weights 1 / 1.6 / 2.2 / 3 x min(4, games/230), capped).
WITH five AS (SELECT player_id FROM run_card WHERE run_id = :run_id AND kind = 'player' AND location = 'active'),
side_games AS (                                     -- per match and side, which of the five played
    SELECT mp.match_id, mp.is_radiant,
           GROUP_CONCAT(a.player_id ORDER BY a.player_id) AS members, COUNT(*) AS k
    FROM match_player mp JOIN account a ON a.account_id = mp.account_id
    WHERE a.player_id IN (SELECT player_id FROM five)
    GROUP BY mp.match_id, mp.is_radiant HAVING k >= 2
)
SELECT members, k, COUNT(*) AS games
FROM side_games GROUP BY members, k ORDER BY k DESC, games DESC;
-- (A game where 3 of the five played also counts for each of its 3 pairs; PHP expands
--  each member set into its subsets before applying the weights.)

-- 3. Hero mastery matrix for auto allocation (5 players x 5 heroes -> PHP tries 120 permutations).
SELECT rc.slot, h.hero_id, COALESCE(ch.games, 0) AS games
FROM run_card rc
CROSS JOIN (SELECT hero_id FROM run_card WHERE run_id = :run_id AND kind = 'hero' AND location = 'active') h
LEFT JOIN card_hero ch ON ch.card_id = rc.card_id AND ch.hero_id = h.hero_id
WHERE rc.run_id = :run_id AND rc.kind = 'player' AND rc.location = 'active';

-- 4. Hero-position fit for the current lineup (thresholds from the design: 25% / 8% / 2%).
SELECT rc.slot AS pos, rc.hero_id, hps.share,
       CASE WHEN hps.games IS NULL OR tot.games < 50 THEN 'no data'
            WHEN hps.share >= 0.25 THEN 'normal'
            WHEN hps.share >= 0.08 THEN 'flex bonus'
            WHEN hps.share >= 0.02 THEN 'rare'
            ELSE 'off-meta penalty' END AS fit
FROM run_card rc
LEFT JOIN hero_position_share hps ON hps.hero_id = rc.hero_id AND hps.pos = rc.slot AND hps.period_id = :period
LEFT JOIN (SELECT hero_id, SUM(games) games FROM hero_position_share WHERE period_id = :period GROUP BY hero_id) tot
       ON tot.hero_id = rc.hero_id
WHERE rc.run_id = :run_id AND rc.kind = 'hero' AND rc.location = 'active';

-- 5. Counter total between two lineups (25 cross pairs).
SELECT SUM(COALESCE(hm.edge, 0)) AS counter_edge
FROM game_lineup a JOIN game_lineup b ON b.game_id = a.game_id AND b.side = 'b'
LEFT JOIN hero_matchup hm ON hm.hero_id = a.hero_id AND hm.vs_hero_id = b.hero_id AND hm.period_id = :period
WHERE a.game_id = :game_id AND a.side = 'a';

-- 6. Pick the AI draft for a game: one of the roster's final games at random (seeded).
SELECT roster_game_id FROM pool_roster_game WHERE roster_id = :roster_id ORDER BY RAND(:seed) LIMIT 1;

-- 7. Record a game safely (the transaction rule).
START TRANSACTION;
SELECT version FROM run WHERE run_id = :run_id FOR UPDATE;          -- serialize this run
INSERT INTO game (series_id, game_no, seed, a_is_radiant, a_roster_game_id, b_roster_game_id)
VALUES (:series_id, :game_no, :seed, :a_rad, :a_rg, :b_rg);         -- fails if already played
-- ... PHP runs the sim from :seed, then:
-- INSERT INTO game_lineup ...; INSERT INTO game_event ... (multi-row);
-- UPDATE game SET winner_side = :w, rounds = :r WHERE game_id = LAST_INSERT_ID();
-- UPDATE series SET wins_a = wins_a + (:w = 'a'), wins_b = wins_b + (:w = 'b') WHERE series_id = :series_id;
UPDATE run SET version = version + 1 WHERE run_id = :run_id;
COMMIT;

-- 8. Demo / report queries ------------------------------------------------
-- 8a. Top 10 cards by rating with their best hero (window function + join).
SELECT * FROM (
    SELECT v.display_name, v.description, v.rating, h.name AS best_hero, ch.games,
           ROW_NUMBER() OVER (PARTITION BY v.card_id ORDER BY ch.games DESC) AS rn
    FROM v_card v JOIN card_hero ch USING (card_id) JOIN hero h USING (hero_id)
) t WHERE rn = 1 ORDER BY rating DESC LIMIT 10;

-- 8b. Pool rosters that win the most simulated TIs across all runs (a "meta" query).
SELECT pr.display_name, COUNT(*) AS titles
FROM series s JOIN run_team rt ON rt.run_team_id = s.winner
JOIN pool_roster pr USING (roster_id)
WHERE s.stage = 'gf' GROUP BY pr.roster_id ORDER BY titles DESC LIMIT 10;

-- 8c. Gaps-and-islands: a player's stints (consecutive games for one org).
WITH g AS (
    SELECT a.player_id, ot.org_id, m.start_time,
           ROW_NUMBER() OVER (PARTITION BY a.player_id ORDER BY m.start_time)
         - ROW_NUMBER() OVER (PARTITION BY a.player_id, ot.org_id ORDER BY m.start_time) AS island
    FROM match_player mp JOIN account a USING (account_id) JOIN pro_match m USING (match_id)
    JOIN org_team ot ON ot.team_id = IF(mp.is_radiant, m.radiant_team_id, m.dire_team_id)
    WHERE a.player_id = :player_id
)
SELECT o.name, MIN(start_time) AS from_date, MAX(start_time) AS to_date, COUNT(*) AS games
FROM g JOIN org o USING (org_id) GROUP BY org_id, island ORDER BY from_date;

-- 8d. Recursive CTE: walk a team's path through the bracket.
WITH RECURSIVE path AS (
    SELECT series_id, stage, next_win_series, 1 AS depth FROM series
    WHERE run_id = :run_id AND stage = 'ub_qf' AND :team IN (team_a, team_b)
    UNION ALL
    SELECT s.series_id, s.stage, s.next_win_series, p.depth + 1
    FROM series s JOIN path p ON s.series_id = p.next_win_series
)
SELECT * FROM path;
