-- Create database
CREATE DATABASE ipl_2025_analysis;


-- Table for auction data
CREATE TABLE auction_2025 (
    sr_no INT PRIMARY KEY,
    player_name VARCHAR(100),
    base_price BIGINT,
    sold_price BIGINT
);

select*from auction_2025;

COPY auction_2025 (sr_no,player_name,base_price,sold_price)
FROM 'C:\Users\chirag lohakare\Desktop\ipl 2025 auction.csv'
DELIMITER ','
CSV HEADER;

-- Table for match performance data
CREATE TABLE match_performance_2025 (
    match_id INT,
    season INT,
    start_date timestamp,
    venue VARCHAR(100),
    innings INT,
    ball DECIMAL(4,1),
    batting_team VARCHAR(100),
    bowling_team VARCHAR(100),
    striker VARCHAR(100), 
    bowler VARCHAR(100),
    runs_off_bat INT,
    extras INT,
    wicket_type VARCHAR(50),
    player_dismissed VARCHAR(100)
);

select*from match_performance_2025 ;

CREATE TABLE batting_stats_2025 AS
SELECT
  player AS player,
  COALESCE(balls_faced,0) AS balls_faced,
  COALESCE(runs,0) AS runs,
  COALESCE(fours,0) AS fours,
  COALESCE(sixes,0) AS sixes,
  COALESCE(matches,0) AS matches
FROM (
  SELECT
    striker AS player,
    COUNT(*) AS balls_faced,
    SUM(runs_off_bat) AS runs,
    SUM(CASE WHEN runs_off_bat = 4 THEN 1 ELSE 0 END) AS fours,
    SUM(CASE WHEN runs_off_bat = 6 THEN 1 ELSE 0 END) AS sixes,
    COUNT(DISTINCT match_id) AS matches
  FROM match_performance_2025
  GROUP BY striker
) s;

CREATE TABLE dismissals_2025 AS
SELECT
  player_dismissed AS player,
  COUNT(*)::int AS dismissals
FROM match_performance_2025
WHERE player_dismissed IS NOT NULL
GROUP BY player_dismissed;


CREATE TABLE batting_stats_full_2025 AS
SELECT
  COALESCE(b.player, d.player) AS player,
  COALESCE(b.runs,0) AS runs,
  COALESCE(b.balls_faced,0) AS balls_faced,
  COALESCE(b.fours,0) AS fours,
  COALESCE(b.sixes,0) AS sixes,
  COALESCE(b.matches,0) AS matches,
  COALESCE(d.dismissals,0) AS dismissals,
  CASE WHEN COALESCE(d.dismissals,0) > 0 THEN ROUND(COALESCE(b.runs,0)::numeric / d.dismissals, 2) ELSE NULL END AS batting_average,
  CASE WHEN COALESCE(b.balls_faced,0) > 0 THEN ROUND(COALESCE(b.runs,0)::numeric * 100.0 / b.balls_faced, 2) ELSE NULL END AS strike_rate,
  CASE WHEN COALESCE(b.matches,0) > 0 THEN ROUND(COALESCE(b.runs,0)::numeric / b.matches, 2) ELSE NULL END AS runs_per_match
FROM batting_stats_2025 b
FULL OUTER JOIN dismissals_2025 d USING (player);

select*from batting_stats_full_2025 ;


CREATE TABLE bowling_stats_2025 AS
SELECT
  bowler AS player,
  COUNT(*) AS balls_bowled,
  SUM(runs_off_bat + COALESCE(extras,0)) AS runs_conceded,
  SUM(CASE WHEN wicket_type IS NOT NULL AND NOT (lower(wicket_type) LIKE '%run out%') THEN 1 ELSE 0 END) AS wickets,
  COUNT(DISTINCT match_id) AS matches_bowled
FROM match_performance_2025
GROUP BY bowler;

CREATE TABLE bowling_stats_full_2025 AS
SELECT
  player,
  balls_bowled,
  runs_conceded,
  wickets,
  matches_bowled,
  CASE WHEN balls_bowled > 0 THEN ROUND((runs_conceded::numeric / (balls_bowled::numeric/6.0)), 2) ELSE NULL END AS economy,
  CASE WHEN wickets > 0 THEN ROUND(balls_bowled::numeric / wickets, 2) ELSE NULL END AS bowling_strike_rate,
  CASE WHEN wickets > 0 THEN ROUND(runs_conceded::numeric / wickets, 2) ELSE NULL END AS bowling_average
FROM bowling_stats_2025;

select*from bowling_stats_full_2025 ;


-- Creating players role
CREATE TABLE player_roles AS
SELECT player,
CASE
  WHEN runs >= 100 AND (wickets IS NULL OR wickets < 5) THEN 'Batter'
  WHEN wickets >= 3 AND (runs IS NULL OR runs < 100) THEN 'Bowler'
  WHEN runs >= 100 AND wickets >= 3 THEN 'Allrounder'
  ELSE 'Unknown'
END AS role
FROM (
  SELECT
    COALESCE(b.player, bo.player) AS player,
    COALESCE(b.runs,0) AS runs,
    COALESCE(bo.wickets,0) AS wickets
  FROM batting_stats_full_2025 b
  FULL OUTER JOIN bowling_stats_full_2025 bo USING (player)
) t;

select*from player_roles ;


CREATE TABLE player_master_2025 AS
SELECT
  coalesce(b.player, bo.player, a.player_name) AS player,
  coalesce(a.player_name, coalesce(b.player, bo.player)) AS player_name_original,
  pr.role,
  COALESCE(b.matches,0) AS batting_matches,
  COALESCE(b.runs,0) AS runs,
  COALESCE(b.balls_faced,0) AS balls_faced,
  COALESCE(b.fours,0) AS fours,
  COALESCE(b.sixes,0) AS sixes,
  COALESCE(b.dismissals,0) AS dismissals,
  b.batting_average,
  b.strike_rate,
  COALESCE(bo.matches_bowled,0) AS bowling_matches,
  COALESCE(bo.balls_bowled,0) AS balls_bowled,
  COALESCE(bo.wickets,0) AS wickets,
  bo.runs_conceded,
  bo.economy,
  bo.bowling_average,
  a.base_price,
  a.sold_price,
  CASE WHEN a.sold_price > 0 THEN LN(a.sold_price) ELSE NULL END AS log_sold_price,
  CASE
    WHEN b.matches > 0 THEN ROUND(b.runs::numeric / b.matches, 2)
    ELSE NULL END AS runs_per_match
FROM batting_stats_full_2025 b
FULL OUTER JOIN bowling_stats_full_2025 bo USING (player)
LEFT JOIN auction_2025 a ON a.player_name = COALESCE(b.player, bo.player)
LEFT JOIN player_roles pr ON pr.player = COALESCE(b.player, bo.player);

select*from player_master_2025 ;

