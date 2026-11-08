-- ============================================================
-- Task 5.1: Connect producers to their data
-- Theme 2: Movie / TV
-- Database: ex603_data (loaded from the provided movies.sql)
-- Run with: psql -d ex603_data -P pager=off -e -f q5_1.sql
--
-- Roles: actor = users, producer = movies, event = ratings,
-- catalog = genres, junction = movie_genres.
-- Movies flagged in Assignment 4 (1.5x the 16.5% baseline or
-- more): 11, 9 and 2. Failure = rating_status = 'withdrawn'.
-- ============================================================


-- ------------------------------------------------------------
-- Q1 Three-table join
--   Requirement: join three tables to show the actor who
--   performed each event, the producer it belongs to, and the
--   event's date and time.
--   Plain question: who wrote each rating, for which movie, and
--   when?
--   ratings is the hub: each rating points to one user and one
--   movie, so two INNER JOINs on the foreign keys attach a name
--   to each side. Status is shown so withdrawn ratings are
--   visible next to the person who made them.
-- ------------------------------------------------------------
SELECT r.rating_id,
       u.user_id,
       u.user_name,
       m.movie_id,
       m.title,
       r.rated_at,
       r.rating_status
FROM   ratings r
JOIN   users   u ON u.user_id  = r.user_id
JOIN   movies  m ON m.movie_id = r.movie_id
ORDER  BY r.rated_at, r.rating_id;


-- ------------------------------------------------------------
-- Q2 Junction-table traversal
--   Requirement: connect the producer table to the catalog table
--   through the junction table, and return the producers that
--   carry the theme's catalog tag.
--   Plain question: which movies are tagged Comedy, and is that
--   tag something the Assignment 4 movies have in common?
--
--   Tag chosen: Comedy. Two of the three flagged movies (11 and
--   2) carry it. Drama would also cover two (9 and 2), but 9 of
--   the 12 tagged movies are Drama, so sharing it says nothing.
--   movies -> movie_genres -> genres: the junction holds one row
--   per (movie, genre) pair, which is the only place the
--   many-to-many link is recorded.
-- ------------------------------------------------------------

-- Q2 (step 0) The tags the catalog actually holds, so the tag
--   choice is made from what exists: Drama, Sci-Fi, Comedy,
--   Thriller, Documentary. (There is no Horror genre.)
SELECT genre_id, genre_name
FROM   genres
ORDER  BY genre_id;

SELECT m.movie_id,
       m.title,
       g.genre_name,
       mg.tagged_on,
       CASE WHEN m.movie_id IN (11, 9, 2)
            THEN 'Flagged in A4' ELSE '' END       AS a4_flag
FROM   movies       m
JOIN   movie_genres mg ON mg.movie_id = m.movie_id
JOIN   genres       g  ON g.genre_id  = mg.genre_id
WHERE  g.genre_name = 'Comedy'
ORDER  BY m.movie_id;

-- Q2 (supporting) Failure rate per genre, so the Comedy result
--   can be read against the other tags. A movie with several
--   genres counts once in each of them.
SELECT g.genre_name,
       COUNT(DISTINCT mg.movie_id)                         AS movies,
       COUNT(r.rating_id)                                  AS ratings,
       SUM(CASE WHEN r.rating_status = 'withdrawn'
                THEN 1 ELSE 0 END)                         AS withdrawn,
       ROUND(100.0 * SUM(CASE WHEN r.rating_status = 'withdrawn'
                              THEN 1 ELSE 0 END)
                   / COUNT(r.rating_id), 1)                AS failure_rate_pct
FROM   genres       g
JOIN   movie_genres mg ON mg.genre_id = g.genre_id
JOIN   ratings      r  ON r.movie_id  = mg.movie_id
GROUP  BY g.genre_name
ORDER  BY failure_rate_pct DESC;


-- ------------------------------------------------------------
-- Q3 Self join
--   Requirement: compare records within the producer table.
--   Plain question: for each Assignment 4 movie, which other
--   movies share its origin country or release year, and do
--   those look-alikes fail as often?
--
--   movies appears twice: f = the flagged movie, p = a peer.
--   f.movie_id <> p.movie_id stops a movie matching itself.
--   The activity CTE adds each movie's ratings and failure rate,
--   joined to both sides, so similarity and performance sit on
--   one row. LEFT JOIN on the peer side keeps peers with no
--   ratings (they show 0 ratings instead of disappearing).
-- ------------------------------------------------------------
WITH activity AS (
    SELECT movie_id,
           COUNT(*)                                        AS ratings,
           SUM(CASE WHEN rating_status = 'withdrawn'
                    THEN 1 ELSE 0 END)                     AS withdrawn
    FROM   ratings
    GROUP  BY movie_id
)
SELECT f.movie_id                                          AS flagged_movie,
       f.origin_country                                    AS f_country,
       f.release_year                                      AS f_year,
       ROUND(100.0 * fa.withdrawn / fa.ratings, 1)         AS f_fail_pct,
       p.movie_id                                          AS peer_movie,
       p.origin_country                                    AS p_country,
       p.release_year                                      AS p_year,
       CASE WHEN f.origin_country = p.origin_country
             AND f.release_year   = p.release_year THEN 'country + year'
            WHEN f.origin_country = p.origin_country THEN 'country'
            ELSE 'year' END                                AS shared,
       COALESCE(pa.ratings, 0)                             AS p_ratings,
       ROUND(100.0 * pa.withdrawn / pa.ratings, 1)         AS p_fail_pct
FROM   movies   f
JOIN   movies   p  ON  p.movie_id <> f.movie_id
                   AND (p.origin_country = f.origin_country
                        OR p.release_year = f.release_year)
JOIN   activity fa ON fa.movie_id = f.movie_id
LEFT   JOIN activity pa ON pa.movie_id = p.movie_id
WHERE  f.movie_id IN (11, 9, 2)
ORDER  BY f.movie_id DESC, p.movie_id;
