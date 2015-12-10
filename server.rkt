#lang curly-fn racket

(require alexis/util/match
         data/collection
         db
         lens
         point-free
         web-server/servlet
         web-server/servlet-env
         (prefix-in env: "environment.rkt"))

(define query #<<SQL
SELECT (won_games.num_games / total_games.num_games) as win_percentage,
       won_games.num_games as games_won,
       total_games.num_games as games_played,
       total_games.plr1 as player_1,
       total_games.plr2 as player_2
FROM (
	SELECT COUNT(*) as num_games, pmt.pnum as p1, pmt2.pnum as p2
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
	WHERE (pmt.gp_team = 0 AND pmt.gm_tscore0 > pmt.gm_tscore1)
	   OR (pmt.gp_team = 1 AND pmt.gm_tscore1 > pmt.gm_tscore0)
	GROUP BY pmt.pnum, pmt2.pnum
) as won_games
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
ORDER BY win_percentage DESC;
SQL
  )

(define conn
  (mysql-connect #:server env:db-host
                 #:user env:db-user
                 #:password env:db-password
                 #:database env:db-database))

(define teams
  (map (thrush vector->immutable-vector
               #{lens-transform (vector-ref-lens 0) % format-percent})
       (query-rows conn query)))

(define (format-percent n)
  (~a (~r (* 100 n) #:precision 2) "%"))

(define (team->table-row team)
  `(tr . ,(sequence->list (map (λ (x) `(td ,(~a x))) team))))

(define (teams->table teams)
  `(table (tr (th "Win Percentage")
              (th "Games Won")
              (th "Total Games")
              (th "Player 1")
              (th "Player 2"))
          . ,(sequence->list (map team->table-row teams))))

(serve/servlet (const (response/xexpr (teams->table teams)))
               #:servlet-path "/"
               #:port env:port
               #:listen-ip #f
               #:command-line? #t)
