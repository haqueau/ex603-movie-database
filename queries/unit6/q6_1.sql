-- ============================================================
-- Task 6.1: Compute across a window without collapsing
-- Theme 2: Movie / TV
-- Database: ex603_data (loaded from the provided movies.sql)
-- Run with: psql -d ex603_data -P pager=off -e -f q6_1.sql
--
-- Roles: actor = users, producer = movies, event = ratings,
-- metric = ratings.score.
-- Failure = rating_status = 'withdrawn' (as in Units 4 and 5).
-- Withdrawn ratings carry a 0.5 placeholder score, not a real
-- one (found in Unit 4), so they are left out of every score
-- average below. They still appear as rows, with no comparison.
-- ============================================================


-- ------------------------------------------------------------
-- Q1 Each rating next to its movie's average
--   Requirement: return every event with its producer's average
--   metric on the same row, using AVG(...) OVER (PARTITION BY).
--   Plain question: is this rating unusually high or low for the
--   movie it was given to?
--
--   PARTITION BY movie_id makes one window per movie; every
--   rating in that window sees the same movie average. Nothing
--   is collapsed, so all 200 ratings come back.
--   FILTER (WHERE rating_status <> 'withdrawn') keeps the 0.5
--   placeholders out of the average while keeping the withdrawn
--   rows themselves in the output.
-- ------------------------------------------------------------
SELECT r.rating_id,
       r.movie_id,
       r.rated_at,
       r.rating_status,
       r.score,
       ROUND(AVG(r.score) FILTER (WHERE r.rating_status <> 'withdrawn')
             OVER (PARTITION BY r.movie_id), 2)          AS movie_avg_score,
       CASE WHEN r.rating_status = 'withdrawn' THEN NULL
            ELSE ROUND(r.score
                       - AVG(r.score) FILTER (WHERE r.rating_status <> 'withdrawn')
                         OVER (PARTITION BY r.movie_id), 2)
       END                                               AS diff_from_movie_avg
FROM   ratings r
ORDER  BY r.movie_id, r.rated_at;


-- ------------------------------------------------------------
-- Q1 (follow-up) The most unusual ratings
--   Plain question: which individual ratings sit furthest from
--   their own movie's average?
--   The window result can't be filtered in the same query (WHERE
--   runs before the window), so Q1's logic goes in a CTE and the
--   outer query keeps the ratings at least 2 points away.
-- ------------------------------------------------------------
WITH scored AS (
    SELECT r.rating_id,
           r.movie_id,
           r.user_id,
           r.rated_at,
           r.rating_status,
           r.score,
           AVG(r.score) FILTER (WHERE r.rating_status <> 'withdrawn')
               OVER (PARTITION BY r.movie_id)            AS movie_avg
    FROM   ratings r
)
SELECT rating_id,
       movie_id,
       user_id,
       rated_at::date                                    AS rated_on,
       rating_status,
       score,
       ROUND(movie_avg, 2)                               AS movie_avg_score,
       ROUND(score - movie_avg, 2)                       AS diff_from_movie_avg
FROM   scored
WHERE  rating_status <> 'withdrawn'
  AND  ABS(score - movie_avg) >= 2
ORDER  BY ABS(score - movie_avg) DESC, rating_id;


-- ------------------------------------------------------------
-- Q1 (supporting) What do the unusual ratings have in common?
--   Plain question: are the ratings far below their movie's
--   average from people who actually watched the movie?
--   Groups every remaining (non-withdrawn) rating by how far it
--   sits from its own movie's average, then compares watch time.
--   The window runs first in the CTE; the outer GROUP BY then
--   collapses its result, which is the only order that works.
-- ------------------------------------------------------------
WITH scored AS (
    SELECT r.score,
           r.watch_minutes,
           r.rating_status,
           AVG(r.score) FILTER (WHERE r.rating_status <> 'withdrawn')
               OVER (PARTITION BY r.movie_id)            AS movie_avg
    FROM   ratings r
)
SELECT CASE WHEN score - movie_avg <= -2 THEN '1 low outlier (2+ below)'
            WHEN score - movie_avg >=  2 THEN '3 high outlier (2+ above)'
            ELSE '2 within 2 points' END                 AS position_vs_movie_avg,
       COUNT(*)                                          AS ratings,
       ROUND(AVG(watch_minutes), 1)                      AS avg_watch_minutes,
       MIN(watch_minutes)                                AS min_watch,
       MAX(watch_minutes)                                AS max_watch
FROM   scored
WHERE  rating_status <> 'withdrawn'
GROUP  BY 1
ORDER  BY 1;


-- ------------------------------------------------------------
-- Q1 (comparison) The GROUP BY version
--   Plain question: what is each movie's average score?
--   Same average, but GROUP BY collapses each movie's ratings
--   into one row: 13 rows instead of 200. The individual score,
--   who gave it and when are gone, so "is this rating unusual?"
--   can no longer be asked.
-- ------------------------------------------------------------
SELECT movie_id,
       COUNT(*)                                          AS ratings,
       ROUND(AVG(score) FILTER (WHERE rating_status <> 'withdrawn'), 2)
                                                         AS movie_avg_score
FROM   ratings
GROUP  BY movie_id
ORDER  BY movie_id;


-- ------------------------------------------------------------
-- Q1 (plan) How PostgreSQL computes the window
--   Plain question: what does the database actually do to put a
--   movie average on every row?
--   Expect: Seq Scan on ratings -> Sort by movie_id -> WindowAgg.
--   The window needs each movie's rows next to each other, so the
--   planner sorts on the PARTITION BY key first, then WindowAgg
--   walks the sorted rows one partition at a time. There is no
--   index on ratings.movie_id, so the sort is explicit.
-- ------------------------------------------------------------
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF)
SELECT r.rating_id,
       r.movie_id,
       r.score,
       AVG(r.score) FILTER (WHERE r.rating_status <> 'withdrawn')
           OVER (PARTITION BY r.movie_id)                AS movie_avg_score
FROM   ratings r;


-- ------------------------------------------------------------
-- Q2 Rank movies three ways
--   Requirement: rank producers by number of events with
--   ROW_NUMBER(), RANK() and DENSE_RANK() side by side; the
--   output must show at least one tie.
--   Plain question: if we published a "most-rated movies"
--   leaderboard, where would each movie appear, and how does the
--   choice of function treat movies with the same count?
--
--   Starts from movies (LEFT JOIN), as recommended in Unit 5, so
--   movies 14 and 15 appear with 0 ratings instead of vanishing.
--   COUNT(r.rating_id) counts only matched ratings, giving 0.
--   All three functions use the same ORDER BY, so any difference
--   between the columns comes only from how each treats ties:
--     ROW_NUMBER  - never ties; breaks them arbitrarily
--     RANK        - ties share a rank, then skips (4, 4, 6)
--     DENSE_RANK  - ties share a rank, no skip   (4, 4, 5)
--   Ties in this data: 5 & 7 (18), 2 & 11 (16), 1 & 13 (11),
--   14 & 15 (0).
-- ------------------------------------------------------------
SELECT m.movie_id,
       COUNT(r.rating_id)                                AS ratings,
       ROW_NUMBER() OVER (ORDER BY COUNT(r.rating_id) DESC) AS row_number,
       RANK()       OVER (ORDER BY COUNT(r.rating_id) DESC) AS rank,
       DENSE_RANK() OVER (ORDER BY COUNT(r.rating_id) DESC) AS dense_rank
FROM   movies  m
LEFT   JOIN ratings r ON r.movie_id = m.movie_id
GROUP  BY m.movie_id
ORDER  BY ratings DESC, row_number;


-- ------------------------------------------------------------
-- Q3 Sort movies into four bands
--   Requirement: NTILE(4) by number of events; look at tied
--   producers on both sides of a band boundary.
--   Plain question: which quarter of the catalog does each movie
--   fall into by how often it is rated?
--
--   NTILE(4) deals 15 movies into bands of 4, 4, 4 and 3 by row
--   position, not by value. It does not look at ties, so two
--   movies with the same count can land in different bands.
-- ------------------------------------------------------------
SELECT m.movie_id,
       COUNT(r.rating_id)                                AS ratings,
       NTILE(4) OVER (ORDER BY COUNT(r.rating_id) DESC)  AS activity_band
FROM   movies  m
LEFT   JOIN ratings r ON r.movie_id = m.movie_id
GROUP  BY m.movie_id
ORDER  BY ratings DESC, activity_band;


-- ------------------------------------------------------------
-- Q3 (check) Which tied counts were split across bands?
--   Plain question: did NTILE put two movies with the same number
--   of ratings into different bands?
--   Any row returned is a tie that straddles a band boundary.
-- ------------------------------------------------------------
WITH banded AS (
    SELECT m.movie_id,
           COUNT(r.rating_id)                            AS ratings,
           NTILE(4) OVER (ORDER BY COUNT(r.rating_id) DESC) AS activity_band
    FROM   movies  m
    LEFT   JOIN ratings r ON r.movie_id = m.movie_id
    GROUP  BY m.movie_id
)
SELECT ratings,
       STRING_AGG(movie_id || ' (band ' || activity_band || ')', ', '
                  ORDER BY activity_band, movie_id)      AS movies_and_bands
FROM   banded
GROUP  BY ratings
HAVING COUNT(DISTINCT activity_band) > 1;
