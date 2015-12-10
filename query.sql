-- Calculates the best teams for Instagib CTF matches based on the data
-- contained in a MySQL database running the UT2k4 Stats system.
--
-- MySQL doesn't support WITH clauses, which would be very helpful for DRYing
-- up this query, but in the absence of that, this query just ends up being
-- long and repetitive.

SELECT (won_games.num_games / total_games.num_games) as win_percentage,
       won_games.num_games as games_won,
       total_games.num_games as games_played,
       total_games.plr1 as player_1,
       total_games.plr2 as player_2
-- First, calculate all the games won by teams containing pairings of two
-- players. The teams may contain other players, but the two players need to
-- share the same team.
FROM (
  SELECT COUNT(*) as num_games, pmt.pnum as p1, pmt2.pnum as p2
  -- In order to do this, we must access the player data and join it with the
  -- match data.
  FROM (
    SELECT p.plr_name, p.pnum, m.gm_num, gp.gp_team, m.gm_tscore0, m.gm_tscore1
    FROM ut_matches as m
    INNER JOIN ut_gplayers as gp ON m.gm_num = gp.gp_match
    INNER JOIN ut_players  as p  ON gp.gp_pnum = p.pnum
    WHERE gm_type = 11
  ) as pmt
  -- Now we join the above query with itself to get player pairings. This is
  -- almost identical to the query above, but it can't be DRYed up much due
  -- to the aforementioned MySQL restrictions.
  --
  -- We enforce the two player ids to be distinct to prevent pairing a player
  -- with themselves, which is obvious. Non-obviously, we enforce the first
  -- player id to be less than the second. This is to prevent duplicate
  -- pairings such as A+B and B+A.
  INNER JOIN (
    SELECT p.plr_name, p.pnum, m.gm_num, gp.gp_team
    FROM ut_matches as m
    INNER JOIN ut_gplayers as gp ON m.gm_num = gp.gp_match
    INNER JOIN ut_players  as p  ON gp.gp_pnum = p.pnum
    WHERE gm_type = 11
  ) as pmt2 ON pmt.gp_team = pmt2.gp_team AND pmt.gm_num = pmt2.gm_num AND pmt.pnum < pmt2.pnum
  -- Finally, we filter out all the won games by comparing the scores.
  WHERE (pmt.gp_team = 0 AND pmt.gm_tscore0 > pmt.gm_tscore1)
     OR (pmt.gp_team = 1 AND pmt.gm_tscore1 > pmt.gm_tscore0)
  GROUP BY pmt.pnum, pmt2.pnum
) as won_games
-- This query is also more or less identical to the above, but we need it for
-- the same reasons. This just doesn't include the WHERE clause to only include
-- games that were successfully won.
RIGHT JOIN (
  SELECT COUNT(*) as num_games, pmt.pnum as p1, pmt2.pnum as p2, pmt.plr_name as plr1, pmt2.plr_name as plr2
  FROM (
    SELECT p.plr_name, p.pnum, m.gm_num, gp.gp_team, m.gm_tscore0, m.gm_tscore1
    FROM ut_matches as m
    INNER JOIN ut_gplayers as gp ON m.gm_num = gp.gp_match
    INNER JOIN ut_players  as p  ON gp.gp_pnum = p.pnum
    WHERE gm_type = 11
  ) as pmt
  INNER JOIN (
    SELECT p.plr_name, p.pnum, m.gm_num, gp.gp_team
    FROM ut_matches as m
    INNER JOIN ut_gplayers as gp ON m.gm_num = gp.gp_match
    INNER JOIN ut_players  as p  ON gp.gp_pnum = p.pnum
    WHERE gm_type = 11
  ) as pmt2 ON pmt.gp_team = pmt2.gp_team AND pmt.gm_num = pmt2.gm_num AND pmt.pnum < pmt2.pnum
  GROUP BY pmt.pnum, pmt2.pnum
) as total_games ON won_games.p1 = total_games.p1 AND won_games.p2 = total_games.p2
-- Finally, just sort everything by the win percentage and call it a day.
ORDER BY win_percentage DESC;
