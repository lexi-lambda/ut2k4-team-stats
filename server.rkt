#lang curly-fn racket

(require alexis/util/match
         data/collection
         db
         lens
         point-free
         racket/runtime-path
         web-server/servlet
         web-server/servlet-env
         (prefix-in env: "environment.rkt"))

(define-runtime-path query-file "query.sql")
(define query (file->string query-file #:mode 'text))

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
  (~a (~r (* 100 (string->number (~a n))) #:precision 2) "%"))

(define (team->table-row team)
  `(tr . ,(sequence->list (map (λ (x) `(td ,(~a x))) team))))

(define (teams->table teams)
  `(table (tr (th "Win Percentage")
              (th "Games Won")
              (th "Total Games")
              (th "Player 1")
              (th "Player 2"))
          . ,(sequence->list (map team->table-row teams))))

(serve/servlet (const (response/xexpr `(html (head (title "Team Duos | UT2004 Stats"))
                                             (body ,(teams->table teams)))))
               #:servlet-path "/"
               #:port env:port
               #:listen-ip #f
               #:command-line? #t)
