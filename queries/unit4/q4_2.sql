-- ============================================================
-- Task 4.2: Build the breakdown leadership asked for
-- Theme 2: Movie / TV
-- Database: ex603_data (loaded from the provided movies.sql)
-- Run with: psql -d ex603_data -P pager=off -e -f q4_2.sql
--
-- Same definitions as q4_1.sql:
--   Failure = rating_status = 'withdrawn'
--   Region  = ratings.device_country
--
-- RESULTS
--  Part A 13 rated movies, one row each. Platform: 34 failures
--         in 200 ratings (17.0%). Highest rates: movie 4 33.3%
--         (only 6 ratings), movie 11 31.3%, movie 9 28.6%,
--         movie 2 25.0%. Movie 2 has the most spam removals (3).
--         Movie 10 has none.
--  Part B 5 regional subtotal rows + 1 grand total row, no detail
--         rows. India is highest: 11 failures in 40 ratings
--         (27.5%). UK is lowest: 4 in 40 (10.0%). Grand total:
--         34 in 200 (17.0%), matching Part A.
--  Part C Baseline over the 12 movies with 10+ ratings:
--         32 failures in 194 ratings = 16.5% (pooled); per-movie
--         rates range 0.0% to 31.3%. Movies 11, 9 and 2 are at
--         1.5x the baseline or more.
-- ============================================================


-- ------------------------------------------------------------
-- Part A: Two numbers in one pass
--   Requirement: per producer, total events and failure events
--   in a single pass over the event table, with no WHERE clause.
--   CASE inside the aggregate decides, row by row, whether each
--   rating counts toward a column, so one scan fills all of them.
--   Plain question: for each movie, how many ratings did it get,
--   and how many of those were withdrawn?
--   spam_withdrawals uses the COUNT(CASE ... END) form: a CASE
--   with no ELSE returns NULL, and COUNT skips NULLs.
-- ------------------------------------------------------------
SELECT movie_id,
       COUNT(*)                                             AS total_ratings,
       SUM(CASE WHEN rating_status = 'withdrawn'
                THEN 1 ELSE 0 END)                          AS failed_ratings,
       COUNT(CASE WHEN withdrawn_reason = 'Spam detected'
                  THEN 1 END)                               AS spam_withdrawals,
       ROUND(100.0 * SUM(CASE WHEN rating_status = 'withdrawn'
                              THEN 1 ELSE 0 END)
                   / COUNT(*), 1)                           AS failure_rate_pct
FROM   ratings
GROUP  BY movie_id
ORDER  BY failure_rate_pct DESC, movie_id;


-- ------------------------------------------------------------
-- Part B: Regional subtotals and a platform grand total
--   Requirement: subtotals per region and a grand total, with no
--   detail rows.
--   Plain question: how does each region perform overall, and
--   what is the whole platform's figure?
--
--   ROLLUP (device_country, movie_id) produces three levels:
--     region + movie  -> detail rows (one per combination)
--     region only     -> one subtotal per region
--     ()              -> one grand total for the platform
--   GROUPING(col) returns 1 when that column has been rolled up
--   on the row. HAVING GROUPING(movie_id) = 1 drops the detail
--   level and keeps only the subtotals and the grand total.
--   (Equivalent: GROUP BY GROUPING SETS ((device_country), ()).)
--
--   HOW TO READ THE OUTPUT
--     row_type = 'Regional subtotal' -> one row per region (5)
--     row_type = 'GRAND TOTAL'       -> the last row: all 200
--                                       ratings, every region
-- ------------------------------------------------------------
SELECT CASE WHEN GROUPING(device_country) = 1
            THEN 'GRAND TOTAL'
            ELSE 'Regional subtotal' END                    AS row_type,
       CASE WHEN GROUPING(device_country) = 1
            THEN 'All regions'
            ELSE device_country END                         AS region,
       COUNT(*)                                             AS total_ratings,
       SUM(CASE WHEN rating_status = 'withdrawn'
                THEN 1 ELSE 0 END)                          AS failed_ratings,
       ROUND(100.0 * SUM(CASE WHEN rating_status = 'withdrawn'
                              THEN 1 ELSE 0 END)
                   / COUNT(*), 1)                           AS failure_rate_pct,
       ROUND(AVG(CASE WHEN rating_status <> 'withdrawn'
                      THEN score END), 2)                   AS avg_score_excl_withdrawn
FROM   ratings
GROUP  BY ROLLUP (device_country, movie_id)
HAVING GROUPING(movie_id) = 1
ORDER  BY GROUPING(device_country), device_country;


-- ------------------------------------------------------------
-- Part C: A two-step pipeline
--   Requirement: a WITH clause producing a per-producer
--   intermediate aggregate, then a second aggregation or filter
--   on it to calculate a baseline for high-volume producers.
--   Plain question: what failure rate is normal for a movie with
--   enough ratings to judge, and which movies are well above it?
--
--   Step 1 (per_movie): one row per movie, as in Part A.
--   Step 2 (baseline):  filter to high-volume movies (10+ ratings,
--                       the Task 4.1 threshold) and aggregate
--                       again. pooled_rate_pct is total failures /
--                       total ratings across those movies, so a
--                       larger movie counts for more. mean_rate_pct
--                       averages the per-movie rates, where every
--                       movie counts equally; the two are shown
--                       side by side.
--   Final:              each high-volume movie against the
--                       baseline. 'Well above' = at least 1.5x the
--                       baseline, i.e. half again as many
--                       withdrawals as a normal movie.
-- ------------------------------------------------------------

-- C1: the baseline itself
WITH per_movie AS (
    SELECT movie_id,
           COUNT(*)                                         AS total_ratings,
           SUM(CASE WHEN rating_status = 'withdrawn'
                    THEN 1 ELSE 0 END)                      AS failed_ratings
    FROM   ratings
    GROUP  BY movie_id
)
SELECT COUNT(*)                                             AS high_volume_movies,
       SUM(total_ratings)                                   AS total_ratings,
       SUM(failed_ratings)                                  AS failed_ratings,
       ROUND(100.0 * SUM(failed_ratings)
                   / SUM(total_ratings), 1)                 AS pooled_rate_pct,
       ROUND(AVG(100.0 * failed_ratings / total_ratings), 1) AS mean_rate_pct,
       ROUND(MIN(100.0 * failed_ratings / total_ratings), 1) AS min_rate_pct,
       ROUND(MAX(100.0 * failed_ratings / total_ratings), 1) AS max_rate_pct
FROM   per_movie
WHERE  total_ratings >= 10;

-- C2: each high-volume movie compared with that baseline
WITH per_movie AS (
    SELECT movie_id,
           COUNT(*)                                         AS total_ratings,
           SUM(CASE WHEN rating_status = 'withdrawn'
                    THEN 1 ELSE 0 END)                      AS failed_ratings
    FROM   ratings
    GROUP  BY movie_id
),
high_volume AS (
    SELECT *
    FROM   per_movie
    WHERE  total_ratings >= 10
),
baseline AS (
    SELECT 100.0 * SUM(failed_ratings) / SUM(total_ratings) AS rate_pct
    FROM   high_volume
)
SELECT h.movie_id,
       h.total_ratings,
       h.failed_ratings,
       ROUND(100.0 * h.failed_ratings / h.total_ratings, 1) AS failure_rate_pct,
       ROUND(b.rate_pct, 1)                                 AS baseline_pct,
       ROUND((100.0 * h.failed_ratings / h.total_ratings)
             / b.rate_pct, 2)                               AS times_baseline,
       CASE
           WHEN 100.0 * h.failed_ratings / h.total_ratings
                >= 1.5 * b.rate_pct                         THEN 'Well above baseline'
           WHEN 100.0 * h.failed_ratings / h.total_ratings
                >  b.rate_pct                               THEN 'Above baseline'
           ELSE                                                  'At or below baseline'
       END                                                  AS assessment
FROM   high_volume h
CROSS  JOIN baseline b
ORDER  BY times_baseline DESC, h.movie_id;
