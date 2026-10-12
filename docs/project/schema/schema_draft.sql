-- =====================================================================
--  DRAFT FOR REVIEW. Not final, not run against a live MySQL server yet.
--  A Dice-Based Tournament Roguelike Deck Builder (CSE311 project) schema, MySQL 8.0+ (InnoDB, utf8mb4)
--  2026-10-11. Every table/column choice here is a proposal for Sadman to
--  accept or change. See data_dictionary.md and er_diagram.md.
--
--  Three layers:
--    A. Reference data imported from OpenDota / Liquipedia / Dota 2 Wiki
--    B. Derived summaries rebuilt by SQL from layer A (etl_draft.sql)
--    C. Game state written while a run is played
-- =====================================================================

CREATE DATABASE IF NOT EXISTS ati CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE ati;

-- =====================================================================
--  A. REFERENCE DATA
-- =====================================================================

CREATE TABLE hero (
    hero_id         SMALLINT UNSIGNED PRIMARY KEY,          -- OpenDota/Valve hero id
    code_name       VARCHAR(64)  NOT NULL UNIQUE,           -- npc_dota_hero_...
    name            VARCHAR(64)  NOT NULL UNIQUE,           -- "Shadow Fiend"
    primary_attr    ENUM('str','agi','int','all') NOT NULL,
    attack_type     ENUM('Melee','Ranged') NOT NULL,
    attack_range    SMALLINT UNSIGNED,
    move_speed      SMALLINT UNSIGNED
) ENGINE=InnoDB;

-- Valve role tags (Carry, Support, Disabler...). Multi-valued, so its own table (1NF).
CREATE TABLE hero_role_tag (
    hero_id   SMALLINT UNSIGNED NOT NULL,
    tag       VARCHAR(16) NOT NULL,
    PRIMARY KEY (hero_id, tag),
    FOREIGN KEY (hero_id) REFERENCES hero(hero_id)
) ENGINE=InnoDB;

CREATE TABLE ability (
    ability_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    hero_id      SMALLINT UNSIGNED NULL,                    -- NULL for items/units
    name         VARCHAR(80) NOT NULL,                      -- "Reverse Polarity"
    source_name  VARCHAR(80) NOT NULL,                      -- wiki "source" (hero or unit)
    UNIQUE KEY uq_ability (source_name, name),
    FOREIGN KEY (hero_id) REFERENCES hero(hero_id)
) ENGINE=InnoDB;

CREATE TABLE mechanic (
    mechanic_id  TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(32) NOT NULL UNIQUE,               -- Stun, Silence, Root, Hex...
    is_disable   BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE ability_mechanic (                             -- M:N
    ability_id   INT UNSIGNED NOT NULL,
    mechanic_id  TINYINT UNSIGNED NOT NULL,
    wiki_revid   INT UNSIGNED,
    PRIMARY KEY (ability_id, mechanic_id),
    FOREIGN KEY (ability_id)  REFERENCES ability(ability_id),
    FOREIGN KEY (mechanic_id) REFERENCES mechanic(mechanic_id)
) ENGINE=InnoDB;

-- Curated, hand-checked (pre-filled from data, corrected by the team).
CREATE TABLE hero_trait (
    hero_id        SMALLINT UNSIGNED PRIMARY KEY,
    disables       TINYINT  NOT NULL DEFAULT 0 CHECK (disables BETWEEN 0 AND 5),
    teamfight_ult  BOOLEAN  NOT NULL DEFAULT FALSE,
    mobility       TINYINT  NOT NULL DEFAULT 1 CHECK (mobility BETWEEN 0 AND 3),
    lane_strength  TINYINT  NOT NULL DEFAULT 0 CHECK (lane_strength BETWEEN -2 AND 2),
    early_power    TINYINT  NOT NULL DEFAULT 0 CHECK (early_power BETWEEN -2 AND 2),
    scaling        TINYINT  NOT NULL DEFAULT 0 CHECK (scaling BETWEEN -2 AND 2),
    summons_push   BOOLEAN  NOT NULL DEFAULT FALSE,
    save_ability   BOOLEAN  NOT NULL DEFAULT FALSE,
    status         ENUM('prefill','checked') NOT NULL DEFAULT 'prefill',
    checked_by     VARCHAR(32) NULL,
    updated_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (hero_id) REFERENCES hero(hero_id)
) ENGINE=InnoDB;

CREATE TABLE patch (
    patch_id     SMALLINT UNSIGNED PRIMARY KEY,             -- OpenDota patch index
    name         VARCHAR(16) NOT NULL UNIQUE,               -- "7.37"
    released_at  DATE NOT NULL
) ENGINE=InnoDB;

CREATE TABLE league (                                       -- OpenDota league
    league_id    INT UNSIGNED PRIMARY KEY,
    name         VARCHAR(160) NOT NULL,
    od_tier      ENUM('premium','professional','amateur','excluded') NOT NULL
) ENGINE=InnoDB;

CREATE TABLE tournament (                                   -- Liquipedia event
    tournament_id  SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    lp_page        VARCHAR(200) NOT NULL UNIQUE,            -- Liquipedia page title
    name           VARCHAR(160) NOT NULL,
    lp_tier        TINYINT NOT NULL CHECK (lp_tier BETWEEN 1 AND 5),
    is_valve       BOOLEAN NOT NULL DEFAULT FALSE,          -- TI or Valve Major
    is_ti          BOOLEAN NOT NULL DEFAULT FALSE,
    start_date     DATE NOT NULL,
    end_date       DATE NOT NULL,
    prize_pool_usd INT UNSIGNED NULL,
    weight         DECIMAL(3,2) NOT NULL DEFAULT 1.00,       -- placement weight (TI > Major > other)
    CHECK (end_date >= start_date)
) ENGINE=InnoDB;

-- A Liquipedia tournament can span several OpenDota leagues (main event, groups) and vice versa.
CREATE TABLE tournament_league (
    tournament_id SMALLINT UNSIGNED NOT NULL,
    league_id     INT UNSIGNED NOT NULL,
    mapped_by     ENUM('auto','hand') NOT NULL DEFAULT 'auto',
    PRIMARY KEY (tournament_id, league_id),
    FOREIGN KEY (tournament_id) REFERENCES tournament(tournament_id),
    FOREIGN KEY (league_id)     REFERENCES league(league_id)
) ENGINE=InnoDB;

CREATE TABLE team (                                         -- OpenDota team id (one per Steam team)
    team_id   INT UNSIGNED PRIMARY KEY,
    name      VARCHAR(120) NULL,
    tag       VARCHAR(32)  NULL
) ENGINE=InnoDB;

-- An org groups team ids across rebrands and duplicates (two real "Natus Vincere" ids).
CREATE TABLE org (
    org_id   SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name     VARCHAR(80) NOT NULL UNIQUE,
    lp_page  VARCHAR(200) NULL
) ENGINE=InnoDB;

CREATE TABLE org_team (
    team_id  INT UNSIGNED PRIMARY KEY,                      -- a team id belongs to at most one org
    org_id   SMALLINT UNSIGNED NOT NULL,
    FOREIGN KEY (team_id) REFERENCES team(team_id),
    FOREIGN KEY (org_id)  REFERENCES org(org_id)
) ENGINE=InnoDB;

CREATE TABLE player (
    player_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    display_name  VARCHAR(64) NOT NULL,
    country_code  CHAR(2) NULL,
    lp_page       VARCHAR(200) NULL UNIQUE
) ENGINE=InnoDB;

-- Every Steam account seen in pro games. player_id links an account to a
-- person (the alias table); NULL = not a card player.
CREATE TABLE account (
    account_id    INT UNSIGNED PRIMARY KEY,                 -- 32-bit Steam account id
    player_id     INT UNSIGNED NULL,
    od_name       VARCHAR(64) NULL,                         -- name from OpenDota notable_players
    alias_status  ENUM('auto','verified','rejected') NULL,
    KEY ix_account_player (player_id),
    FOREIGN KEY (player_id) REFERENCES player(player_id)
) ENGINE=InnoDB;

CREATE TABLE placement (
    tournament_id  SMALLINT UNSIGNED NOT NULL,
    team_label     VARCHAR(120) NOT NULL,                   -- name as Liquipedia shows it
    place_from     TINYINT UNSIGNED NOT NULL,               -- "5-8" is stored as 5..8
    place_to       TINYINT UNSIGNED NOT NULL,
    org_id         SMALLINT UNSIGNED NULL,
    source         ENUM('liquipedia','derived','hand') NOT NULL,
    PRIMARY KEY (tournament_id, team_label),
    CHECK (place_to >= place_from),
    FOREIGN KEY (tournament_id) REFERENCES tournament(tournament_id),
    FOREIGN KEY (org_id)        REFERENCES org(org_id)
) ENGINE=InnoDB;

-- `match` is a reserved word in MySQL 8 (MATCH ... AGAINST), hence pro_match.
CREATE TABLE pro_match (
    match_id         BIGINT UNSIGNED PRIMARY KEY,
    league_id        INT UNSIGNED NOT NULL,
    start_time       DATETIME NOT NULL,                     -- UTC
    duration_s       SMALLINT UNSIGNED NOT NULL,
    radiant_win      BOOLEAN NOT NULL,
    radiant_team_id  INT UNSIGNED NULL,
    dire_team_id     INT UNSIGNED NULL,
    series_id        INT UNSIGNED NULL,
    series_type      TINYINT UNSIGNED NULL,                 -- 0 Bo1, 1 Bo3, 2 Bo5 (OpenDota)
    patch_id         SMALLINT UNSIGNED NULL,
    KEY ix_match_time (start_time),
    KEY ix_match_league_time (league_id, start_time),
    FOREIGN KEY (league_id)       REFERENCES league(league_id),
    FOREIGN KEY (radiant_team_id) REFERENCES team(team_id),
    FOREIGN KEY (dire_team_id)    REFERENCES team(team_id),
    FOREIGN KEY (patch_id)        REFERENCES patch(patch_id)
) ENGINE=InnoDB;

CREATE TABLE match_player (
    match_id      BIGINT UNSIGNED NOT NULL,
    player_slot   TINYINT UNSIGNED NOT NULL,                -- 0-4 Radiant, 128-132 Dire
    account_id    INT UNSIGNED NULL,                        -- NULL = anonymous
    hero_id       SMALLINT UNSIGNED NOT NULL,
    is_radiant    BOOLEAN AS (player_slot < 128) STORED,
    lane          TINYINT NULL,
    lane_role     TINYINT NULL,                             -- 1 safe 2 mid 3 off 4 jungle (2016+)
    is_roaming    BOOLEAN NULL,
    gpm           SMALLINT UNSIGNED NULL,
    xpm           SMALLINT UNSIGNED NULL,
    last_hits     SMALLINT UNSIGNED NULL,
    kills         TINYINT UNSIGNED NULL,
    deaths        TINYINT UNSIGNED NULL,
    assists       TINYINT UNSIGNED NULL,
    gold_10       MEDIUMINT UNSIGNED NULL,                  -- from OpenDota gold_t[11] (array -> scalar, 1NF)
    xp_10         MEDIUMINT UNSIGNED NULL,
    lh_10         SMALLINT UNSIGNED NULL,
    est_pos       TINYINT NULL CHECK (est_pos BETWEEN 1 AND 5),  -- derived in ETL
    PRIMARY KEY (match_id, player_slot),
    KEY ix_mp_account (account_id, match_id),
    KEY ix_mp_hero (hero_id, match_id),
    FOREIGN KEY (match_id)   REFERENCES pro_match(match_id),
    FOREIGN KEY (account_id) REFERENCES account(account_id),
    FOREIGN KEY (hero_id)    REFERENCES hero(hero_id)
) ENGINE=InnoDB;

-- =====================================================================
--  B. DERIVED SUMMARIES (rebuilt from A; never edited by the game)
-- =====================================================================

-- One card per player per era window (max 3).
CREATE TABLE player_card (
    card_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_id      INT UNSIGNED NOT NULL,
    card_index     TINYINT UNSIGNED NOT NULL CHECK (card_index BETWEEN 0 AND 2),
    start_date     DATE NOT NULL,
    end_date       DATE NOT NULL,
    games          SMALLINT UNSIGNED NOT NULL,
    wins           SMALLINT UNSIGNED NOT NULL,
    primary_pos    TINYINT NOT NULL CHECK (primary_pos BETWEEN 1 AND 5),
    c_winrate      DECIMAL(5,4) NOT NULL,                   -- component percentiles 0..1
    c_peak         DECIMAL(5,4) NOT NULL,
    c_consistency  DECIMAL(5,4) NOT NULL,
    c_placements   DECIMAL(5,4) NOT NULL,
    rating         TINYINT UNSIGNED NOT NULL CHECK (rating BETWEEN 50 AND 99),
    UNIQUE KEY uq_card (player_id, card_index),
    UNIQUE KEY uq_card_player (card_id, player_id),         -- target for run_card's composite FK
    CHECK (wins <= games),
    CHECK (end_date >= start_date),
    FOREIGN KEY (player_id) REFERENCES player(player_id)
) ENGINE=InnoDB;

CREATE TABLE card_position (
    card_id  INT UNSIGNED NOT NULL,
    pos      TINYINT NOT NULL CHECK (pos BETWEEN 1 AND 5),
    games    SMALLINT UNSIGNED NOT NULL,
    wins     SMALLINT UNSIGNED NOT NULL,
    role_kind ENUM('main','alt','off') NOT NULL DEFAULT 'off', -- alt = >=15% of matches or another card's main role
    PRIMARY KEY (card_id, pos),
    FOREIGN KEY (card_id) REFERENCES player_card(card_id)
) ENGINE=InnoDB;

CREATE TABLE card_hero (                                     -- hero mastery (position-agnostic, decided)
    card_id  INT UNSIGNED NOT NULL,
    hero_id  SMALLINT UNSIGNED NOT NULL,
    games    SMALLINT UNSIGNED NOT NULL,
    wins     SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (card_id, hero_id),
    FOREIGN KEY (card_id) REFERENCES player_card(card_id),
    FOREIGN KEY (hero_id) REFERENCES hero(hero_id)
) ENGINE=InnoDB;

CREATE TABLE card_org (                                      -- which org packs a card can appear in
    card_id  INT UNSIGNED NOT NULL,
    org_id   SMALLINT UNSIGNED NOT NULL,
    games    SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (card_id, org_id),
    KEY ix_card_org_org (org_id, games),
    FOREIGN KEY (card_id) REFERENCES player_card(card_id),
    FOREIGN KEY (org_id)  REFERENCES org(org_id)
) ENGINE=InnoDB;

-- Chemistry base: games two players played on the same side (whole careers).
-- Trios, quads and five-stacks are computed on demand for the 5 drafted players.
CREATE TABLE player_pair (
    player_a  INT UNSIGNED NOT NULL,
    player_b  INT UNSIGNED NOT NULL,
    games     SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (player_a, player_b),
    CHECK (player_a < player_b),                             -- store each pair once
    FOREIGN KEY (player_a) REFERENCES player(player_id),
    FOREIGN KEY (player_b) REFERENCES player(player_id)
) ENGINE=InnoDB;

CREATE TABLE stat_period (                                   -- windows for hero stats (e.g. "2024+")
    period_id  TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    label      VARCHAR(32) NOT NULL UNIQUE,
    date_from  DATE NOT NULL,
    date_to    DATE NOT NULL
) ENGINE=InnoDB;

CREATE TABLE hero_position_share (
    hero_id    SMALLINT UNSIGNED NOT NULL,
    period_id  TINYINT UNSIGNED NOT NULL,
    pos        TINYINT NOT NULL CHECK (pos BETWEEN 1 AND 5),
    games      INT UNSIGNED NOT NULL,
    share      DECIMAL(5,4) NOT NULL,
    PRIMARY KEY (hero_id, period_id, pos),
    FOREIGN KEY (hero_id)   REFERENCES hero(hero_id),
    FOREIGN KEY (period_id) REFERENCES stat_period(period_id)
) ENGINE=InnoDB;

CREATE TABLE hero_matchup (                                  -- counters: hero vs hero on opposite sides
    hero_id     SMALLINT UNSIGNED NOT NULL,
    vs_hero_id  SMALLINT UNSIGNED NOT NULL,
    period_id   TINYINT UNSIGNED NOT NULL,
    games       INT UNSIGNED NOT NULL,
    wins        INT UNSIGNED NOT NULL,
    edge        DECIMAL(6,4) NOT NULL,                       -- shrunk win rate minus expected
    PRIMARY KEY (hero_id, vs_hero_id, period_id),
    CHECK (hero_id <> vs_hero_id),
    FOREIGN KEY (hero_id)    REFERENCES hero(hero_id),
    FOREIGN KEY (vs_hero_id) REFERENCES hero(hero_id),
    FOREIGN KEY (period_id)  REFERENCES stat_period(period_id)
) ENGINE=InnoDB;

CREATE TABLE lane_matchup (                                  -- gold diff at 10 min, same lane
    hero_id       SMALLINT UNSIGNED NOT NULL,
    vs_hero_id    SMALLINT UNSIGNED NOT NULL,
    lane_kind     ENUM('mid','side') NOT NULL,
    period_id     TINYINT UNSIGNED NOT NULL,
    games         INT UNSIGNED NOT NULL,
    avg_gold_diff SMALLINT NOT NULL,
    PRIMARY KEY (hero_id, vs_hero_id, lane_kind, period_id),
    FOREIGN KEY (hero_id)    REFERENCES hero(hero_id),
    FOREIGN KEY (vs_hero_id) REFERENCES hero(hero_id),
    FOREIGN KEY (period_id)  REFERENCES stat_period(period_id)
) ENGINE=InnoDB;

CREATE TABLE matchup_override (                              -- hand-written reputation matchups
    hero_id     SMALLINT UNSIGNED NOT NULL,
    vs_hero_id  SMALLINT UNSIGNED NOT NULL,
    lane_kind   ENUM('mid','side','fight') NOT NULL,
    edge        TINYINT NOT NULL CHECK (edge BETWEEN -2 AND 2),
    note        VARCHAR(200) NULL,
    PRIMARY KEY (hero_id, vs_hero_id, lane_kind),
    FOREIGN KEY (hero_id)    REFERENCES hero(hero_id),
    FOREIGN KEY (vs_hero_id) REFERENCES hero(hero_id)
) ENGINE=InnoDB;

CREATE TABLE hero_phase_stat (                               -- win rate by game length (early vs scaling)
    hero_id    SMALLINT UNSIGNED NOT NULL,
    period_id  TINYINT UNSIGNED NOT NULL,
    bucket     ENUM('lt30','30to45','ge45') NOT NULL,
    games      INT UNSIGNED NOT NULL,
    wins       INT UNSIGNED NOT NULL,
    PRIMARY KEY (hero_id, period_id, bucket),
    FOREIGN KEY (hero_id)   REFERENCES hero(hero_id),
    FOREIGN KEY (period_id) REFERENCES stat_period(period_id)
) ENGINE=InnoDB;

-- The field: winners and finalists of tier-1 events.
CREATE TABLE pool_roster (
    roster_id      SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tournament_id  SMALLINT UNSIGNED NOT NULL,
    org_id         SMALLINT UNSIGNED NULL,
    display_name   VARCHAR(120) NOT NULL,                    -- "Team Liquid" (no year or event in the name)
    description    VARCHAR(200) NULL,                        -- "Winner, The International 2017"
    place          TINYINT UNSIGNED NOT NULL CHECK (place IN (1,2)),
    is_ti_winner   BOOLEAN NOT NULL DEFAULT FALSE,
    final_series_id INT UNSIGNED NULL,
    UNIQUE KEY uq_roster (tournament_id, place),
    FOREIGN KEY (tournament_id) REFERENCES tournament(tournament_id),
    FOREIGN KEY (org_id)        REFERENCES org(org_id)
) ENGINE=InnoDB;

CREATE TABLE pool_roster_player (
    roster_id  SMALLINT UNSIGNED NOT NULL,
    pos        TINYINT NOT NULL CHECK (pos BETWEEN 1 AND 5),
    player_id  INT UNSIGNED NOT NULL,
    card_id    INT UNSIGNED NOT NULL,                        -- era card covering the final's date
    PRIMARY KEY (roster_id, pos),
    UNIQUE KEY uq_roster_player (roster_id, player_id),
    FOREIGN KEY (roster_id) REFERENCES pool_roster(roster_id),
    FOREIGN KEY (card_id, player_id) REFERENCES player_card(card_id, player_id)
) ENGINE=InnoDB;

-- Each game the roster played in its final; heroes come from match_player (no copy).
CREATE TABLE pool_roster_game (
    roster_game_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    roster_id       SMALLINT UNSIGNED NOT NULL,
    match_id        BIGINT UNSIGNED NOT NULL,
    is_radiant      BOOLEAN NOT NULL,
    UNIQUE KEY uq_roster_match (roster_id, match_id),
    FOREIGN KEY (roster_id) REFERENCES pool_roster(roster_id),
    FOREIGN KEY (match_id)  REFERENCES pro_match(match_id)
) ENGINE=InnoDB;

-- =====================================================================
--  C. GAME STATE (one browser session token per run; no accounts, decided)
-- =====================================================================

CREATE TABLE run (
    run_id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    session_token  CHAR(64) NOT NULL,                        -- random token in a cookie
    seed           BIGINT UNSIGNED NOT NULL,
    difficulty     ENUM('hard','normal','easy') NOT NULL,    -- 0 / 1 / 2 rerolls
    hero_alloc     ENUM('auto','manual') NOT NULL DEFAULT 'auto',
    rerolls_left   TINYINT NOT NULL CHECK (rerolls_left >= 0),
    status         ENUM('drafting','groups','playoffs','finished','abandoned') NOT NULL DEFAULT 'drafting',
    final_place    VARCHAR(8) NULL,                          -- "1", "5-6", ...
    version        INT UNSIGNED NOT NULL DEFAULT 0,          -- optimistic locking
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY ix_run_session (session_token, status)
) ENGINE=InnoDB;

CREATE TABLE run_pack (
    pack_id     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    run_id      BIGINT UNSIGNED NOT NULL,
    pack_no     SMALLINT UNSIGNED NOT NULL,                  -- order within the run
    reason      ENUM('draft','group_reward','ub_loss_reward','lb_reward','upgrade_fallback') NOT NULL,
    org_id      SMALLINT UNSIGNED NOT NULL,
    status      ENUM('open','picked','passed','rerolled') NOT NULL DEFAULT 'open',
    picked_option TINYINT UNSIGNED NULL,
    UNIQUE KEY uq_pack (run_id, pack_no),
    FOREIGN KEY (run_id) REFERENCES run(run_id) ON DELETE CASCADE,
    FOREIGN KEY (org_id) REFERENCES org(org_id)
) ENGINE=InnoDB;

CREATE TABLE run_pack_option (
    pack_id    BIGINT UNSIGNED NOT NULL,
    option_no  TINYINT UNSIGNED NOT NULL CHECK (option_no BETWEEN 1 AND 10),
    card_id    INT UNSIGNED NULL,
    hero_id    SMALLINT UNSIGNED NULL,
    PRIMARY KEY (pack_id, option_no),
    CHECK ((card_id IS NULL) <> (hero_id IS NULL)),          -- exactly one of the two
    FOREIGN KEY (pack_id) REFERENCES run_pack(pack_id) ON DELETE CASCADE,
    FOREIGN KEY (card_id) REFERENCES player_card(card_id),
    FOREIGN KEY (hero_id) REFERENCES hero(hero_id)
) ENGINE=InnoDB;

-- Cards the run owns right now (active five, assigned heroes, bench).
-- Active slot n = position n; a hero in active slot n is played by the player in slot n.
CREATE TABLE run_card (
    run_card_id  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    run_id       BIGINT UNSIGNED NOT NULL,
    kind         ENUM('player','hero') NOT NULL,
    card_id      INT UNSIGNED NULL,
    player_id    INT UNSIGNED NULL,                          -- copied from the card so UNIQUE can stop duplicates
    hero_id      SMALLINT UNSIGNED NULL,
    location     ENUM('active','bench') NOT NULL,
    slot         TINYINT UNSIGNED NOT NULL CHECK (slot BETWEEN 1 AND 5),
    slot_key     VARCHAR(8) AS (CASE WHEN location = 'bench' THEN CONCAT('B', slot)
                                     ELSE CONCAT(LEFT(kind,1), slot) END) STORED,
    from_pack_id BIGINT UNSIGNED NULL,
    UNIQUE KEY uq_run_slot (run_id, slot_key),               -- one card per slot; bench has 5 shared slots
    UNIQUE KEY uq_run_player (run_id, player_id),            -- no two cards of one player (DEFAULT)
    UNIQUE KEY uq_run_hero (run_id, hero_id),
    CHECK ((kind = 'player' AND card_id IS NOT NULL AND player_id IS NOT NULL AND hero_id IS NULL)
        OR (kind = 'hero'   AND hero_id IS NOT NULL AND card_id IS NULL AND player_id IS NULL)),
    FOREIGN KEY (run_id) REFERENCES run(run_id) ON DELETE CASCADE,
    FOREIGN KEY (card_id, player_id) REFERENCES player_card(card_id, player_id),
    FOREIGN KEY (hero_id) REFERENCES hero(hero_id),
    FOREIGN KEY (from_pack_id) REFERENCES run_pack(pack_id)
) ENGINE=InnoDB;

CREATE TABLE run_team (                                      -- the 16 entrants
    run_team_id  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    run_id       BIGINT UNSIGNED NOT NULL,
    seed_no      TINYINT UNSIGNED NOT NULL CHECK (seed_no BETWEEN 1 AND 16),
    group_code   CHAR(1) NOT NULL CHECK (group_code IN ('A','B')),
    is_player    BOOLEAN NOT NULL DEFAULT FALSE,
    roster_id    SMALLINT UNSIGNED NULL,
    player_flag  TINYINT AS (CASE WHEN is_player THEN 1 END) STORED,
    UNIQUE KEY uq_run_seed (run_id, seed_no),
    UNIQUE KEY uq_run_roster (run_id, roster_id),
    UNIQUE KEY uq_one_player_team (run_id, player_flag),     -- NULLs don't collide, so only one is_player row
    CHECK (is_player <> (roster_id IS NOT NULL)),
    FOREIGN KEY (run_id)    REFERENCES run(run_id) ON DELETE CASCADE,
    FOREIGN KEY (roster_id) REFERENCES pool_roster(roster_id)
) ENGINE=InnoDB;

-- Group games and playoff series in one table. Each playoff series points to
-- the series its winner and loser go to next (self-referencing FKs).
CREATE TABLE series (
    series_id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    run_id           BIGINT UNSIGNED NOT NULL,
    stage            ENUM('group','ub_qf','lb_r1','ub_sf','lb_r2','lb_r3','ub_f','lb_r4','lb_f','gf') NOT NULL,
    bracket_slot     TINYINT UNSIGNED NOT NULL,              -- order within the stage
    best_of          TINYINT UNSIGNED NOT NULL CHECK (best_of IN (1,3,5)),
    team_a           BIGINT UNSIGNED NULL,                   -- NULL until the feeder series finishes
    team_b           BIGINT UNSIGNED NULL,
    wins_a           TINYINT UNSIGNED NOT NULL DEFAULT 0,
    wins_b           TINYINT UNSIGNED NOT NULL DEFAULT 0,
    winner           BIGINT UNSIGNED NULL,
    next_win_series  BIGINT UNSIGNED NULL,
    next_win_side    ENUM('a','b') NULL,
    next_lose_series BIGINT UNSIGNED NULL,
    next_lose_side   ENUM('a','b') NULL,
    status           ENUM('pending','ready','live','done') NOT NULL DEFAULT 'pending',
    UNIQUE KEY uq_series (run_id, stage, bracket_slot),
    CHECK (team_a IS NULL OR team_b IS NULL OR team_a <> team_b),
    FOREIGN KEY (run_id)  REFERENCES run(run_id) ON DELETE CASCADE,
    FOREIGN KEY (team_a)  REFERENCES run_team(run_team_id),
    FOREIGN KEY (team_b)  REFERENCES run_team(run_team_id),
    FOREIGN KEY (winner)  REFERENCES run_team(run_team_id),
    FOREIGN KEY (next_win_series)  REFERENCES series(series_id),
    FOREIGN KEY (next_lose_series) REFERENCES series(series_id)
) ENGINE=InnoDB;

CREATE TABLE game (
    game_id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    series_id        BIGINT UNSIGNED NOT NULL,
    game_no          TINYINT UNSIGNED NOT NULL CHECK (game_no BETWEEN 1 AND 5),
    seed             BIGINT UNSIGNED NOT NULL,               -- stored BEFORE the sim runs
    a_roster_game_id INT UNSIGNED NULL,                      -- AI draft used (NULL for the player's side)
    b_roster_game_id INT UNSIGNED NULL,
    a_is_radiant     BOOLEAN NOT NULL,
    winner_side      ENUM('a','b') NULL,                     -- NULL while simulating
    rounds           TINYINT UNSIGNED NULL,
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_game (series_id, game_no),                 -- a refresh can't re-roll a game
    FOREIGN KEY (series_id) REFERENCES series(series_id) ON DELETE CASCADE,
    FOREIGN KEY (a_roster_game_id) REFERENCES pool_roster_game(roster_game_id),
    FOREIGN KEY (b_roster_game_id) REFERENCES pool_roster_game(roster_game_id)
) ENGINE=InnoDB;

-- Snapshot of who played what (the bench can change later).
CREATE TABLE game_lineup (
    game_id   BIGINT UNSIGNED NOT NULL,
    side      ENUM('a','b') NOT NULL,
    pos       TINYINT NOT NULL CHECK (pos BETWEEN 1 AND 5),
    card_id   INT UNSIGNED NOT NULL,
    hero_id   SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (game_id, side, pos),
    UNIQUE KEY uq_lineup_hero (game_id, hero_id),            -- a hero once per game (both sides)
    FOREIGN KEY (game_id) REFERENCES game(game_id) ON DELETE CASCADE,
    FOREIGN KEY (card_id) REFERENCES player_card(card_id),
    FOREIGN KEY (hero_id) REFERENCES hero(hero_id)
) ENGINE=InnoDB;

CREATE TABLE game_event (                                    -- the replay log
    game_id     BIGINT UNSIGNED NOT NULL,
    seq         SMALLINT UNSIGNED NOT NULL,
    round_no    TINYINT UNSIGNED NOT NULL,
    kind        ENUM('lane_safe','lane_mid','lane_off','teamfight','pickoff','roshan','building') NOT NULL,
    side        ENUM('a','b') NULL,                          -- who won / who rolled
    roll_a      TINYINT UNSIGNED NULL CHECK (roll_a BETWEEN 2 AND 12),
    roll_b      TINYINT UNSIGNED NULL CHECK (roll_b BETWEEN 2 AND 12),
    mod_a       DECIMAL(4,2) NULL,
    mod_b       DECIMAL(4,2) NULL,
    outcome     VARCHAR(24) NOT NULL,                        -- 'win','draw','t1_down','aegis',...
    detail      JSON NULL,                                   -- modifier breakdown for the replay
    PRIMARY KEY (game_id, seq),
    FOREIGN KEY (game_id) REFERENCES game(game_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE run_upgrade (                                   -- UB series rewards
    upgrade_id   BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    run_id       BIGINT UNSIGNED NOT NULL,
    series_id    BIGINT UNSIGNED NOT NULL,
    run_card_id  BIGINT UNSIGNED NULL,                       -- NULL if converted to a pick
    from_card_id INT UNSIGNED NULL,
    to_card_id   INT UNSIGNED NULL,
    UNIQUE KEY uq_upgrade_series (series_id),                -- one reward per series win
    FOREIGN KEY (run_id)       REFERENCES run(run_id) ON DELETE CASCADE,
    FOREIGN KEY (series_id)    REFERENCES series(series_id) ON DELETE CASCADE,
    FOREIGN KEY (from_card_id) REFERENCES player_card(card_id),
    FOREIGN KEY (to_card_id)   REFERENCES player_card(card_id)
) ENGINE=InnoDB;

-- =====================================================================
--  VIEWS (examples; more in queries_draft.sql)
-- =====================================================================

-- Group standings with window functions. Tiebreak beyond wins is done in PHP (DEFAULT rule).
CREATE OR REPLACE VIEW v_group_standings AS
WITH results AS (
    SELECT s.run_id, rt.group_code, rt.run_team_id,
           SUM(CASE WHEN s.winner = rt.run_team_id THEN 1 ELSE 0 END) AS wins,
           SUM(CASE WHEN s.status = 'done' AND s.winner <> rt.run_team_id THEN 1 ELSE 0 END) AS losses
    FROM run_team rt
    JOIN series s ON s.run_id = rt.run_id AND s.stage = 'group'
                 AND rt.run_team_id IN (s.team_a, s.team_b)
    GROUP BY s.run_id, rt.group_code, rt.run_team_id
)
SELECT run_id, group_code, run_team_id, wins, losses,
       RANK() OVER (PARTITION BY run_id, group_code ORDER BY wins DESC) AS group_rank
FROM results;

-- A card with its player's name and top position, for the draft screen.
CREATE OR REPLACE VIEW v_card AS
SELECT c.card_id, p.player_id, p.display_name,
       CONCAT(YEAR(c.start_date), '–', YEAR(c.end_date)) AS description,   -- years live here, never in the name
       c.rating, c.primary_pos, c.games, ROUND(c.wins / c.games, 3) AS win_rate
FROM player_card c JOIN player p USING (player_id);

-- =====================================================================
--  STORED PROCEDURE (example of the transaction rule; DRAFT)
--  Records a finished playoff series and moves both teams on, atomically.
-- =====================================================================
DELIMITER //
CREATE PROCEDURE sp_finish_series(IN p_series_id BIGINT UNSIGNED, IN p_winner BIGINT UNSIGNED)
BEGIN
    DECLARE v_a, v_b, v_loser, v_nw, v_nl BIGINT UNSIGNED;
    DECLARE v_sw, v_sl CHAR(1);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

    START TRANSACTION;
    SELECT team_a, team_b, next_win_series, next_win_side, next_lose_series, next_lose_side
      INTO v_a, v_b, v_nw, v_sw, v_nl, v_sl
      FROM series WHERE series_id = p_series_id AND status <> 'done'
      FOR UPDATE;                                            -- lock: a double click can't advance twice
    IF v_a IS NULL OR v_b IS NULL OR p_winner NOT IN (v_a, v_b) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'series not ready or bad winner';
    END IF;
    SET v_loser = IF(p_winner = v_a, v_b, v_a);

    UPDATE series SET winner = p_winner, status = 'done' WHERE series_id = p_series_id;
    IF v_nw IS NOT NULL THEN
        UPDATE series SET team_a = IF(v_sw = 'a', p_winner, team_a),
                          team_b = IF(v_sw = 'b', p_winner, team_b)
        WHERE series_id = v_nw;
    END IF;
    IF v_nl IS NOT NULL THEN
        UPDATE series SET team_a = IF(v_sl = 'a', v_loser, team_a),
                          team_b = IF(v_sl = 'b', v_loser, team_b)
        WHERE series_id = v_nl;
    END IF;
    UPDATE series SET status = 'ready'
     WHERE series_id IN (v_nw, v_nl) AND team_a IS NOT NULL AND team_b IS NOT NULL;
    COMMIT;
END //
DELIMITER ;
