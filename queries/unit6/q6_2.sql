-- ============================================================
-- Task 6.2: Compare each row to its neighbors
-- Theme 2: Movie / TV
-- Database: ex603_data (loaded from the provided movies.sql)
-- Run with: psql -d ex603_data -P pager=off -e -f q6_2.sql
--
-- Roles: producer = movies, event = ratings, metric = score.
-- Failure = rating_status = 'withdrawn'. Withdrawn ratings carry
-- a 0.5 placeholder score (Unit 4), so they are kept out of any
-- score comparison.
-- Producer followed in Parts A and C: movie 11, the movie with
-- the highest failure rate in Units 4 and 5 (5 of 16, 31.3%).
-- ============================================================


-- ------------------------------------------------------------
-- Part A  Row to row: movie 11's scores in time order
--   Requirement: LAG() and LEAD() partitioned by producer and
--   ordered by timestamp; a delta column (current minus
--   previous); final output filtered to one producer.
--   Plain question: are movie 11's scores going up or down over
--   the year, and where do they jump?
--
--   The window runs over every movie (PARTITION BY movie_id) and
--   the outer query then keeps movie 11, so the pattern works for
--   any movie by changing one number.
--   Withdrawn ratings are removed in the CTE's WHERE. WHERE runs
--   before the window, so LAG/LEAD step from one real score to
--   the next real score and never land on a 0.5 placeholder.
--   rating_id is added to ORDER BY as a tie-break, so the order
--   is fixed even if two ratings ever share a timestamp.
-- ------------------------------------------------------------
WITH series AS (
    SELECT r.movie_id,
           r.rating_id,
           r.rated_at,
           r.watch_minutes,
           r.score,
           LAG(r.score)    OVER w                        AS prev_score,
           LEAD(r.score)   OVER w                        AS next_score,
           LAG(r.rated_at) OVER w                        AS prev_rated_at
    FROM   ratings r
    WHERE  r.rating_status <> 'withdrawn'
    WINDOW w AS (PARTITION BY r.movie_id ORDER BY r.rated_at, r.rating_id)
)
SELECT rating_id,
       rated_at::date                                    AS rated_on,
       rated_at::date - prev_rated_at::date              AS days_since_prev,
       watch_minutes,
       prev_score,
       score,
       next_score,
       score - prev_score                                AS delta
FROM   series
WHERE  movie_id = 11
ORDER  BY rated_at, rating_id;


-- ------------------------------------------------------------
-- Part A (supporting) How much every movie swings
--   Plain question: is movie 11's biggest drop (-2.8) unusual,
--   or do other movies swing as much from one rating to the
--   next? And are the big drops from people who watched?
--   The deltas come from the window in the CTE; the outer GROUP
--   BY then summarises them per movie. big_drops counts drops of
--   3 points or more; big_drops_short_watch counts how many of
--   those came from a viewer who watched under 10 minutes.
-- ------------------------------------------------------------
WITH series AS (
    SELECT r.movie_id,
           r.watch_minutes,
           r.score - LAG(r.score) OVER (PARTITION BY r.movie_id
                                        ORDER BY r.rated_at, r.rating_id)
                                                         AS delta
    FROM   ratings r
    WHERE  r.rating_status <> 'withdrawn'
)
SELECT movie_id,
       COUNT(delta)                                      AS deltas,
       MIN(delta)                                        AS biggest_drop,
       MAX(delta)                                        AS biggest_rise,
       ROUND(AVG(ABS(delta)), 2)                         AS avg_abs_delta,
       SUM(CASE WHEN delta <= -3 THEN 1 ELSE 0 END)      AS big_drops,
       SUM(CASE WHEN delta <= -3 AND watch_minutes < 10
                THEN 1 ELSE 0 END)                       AS big_drops_short_watch
FROM   series
GROUP  BY movie_id
ORDER  BY avg_abs_delta DESC;


-- ------------------------------------------------------------
-- Part B1  Running total and moving average, rating by rating
--   Requirement: SUM(...) OVER (ORDER BY ... ROWS BETWEEN
--   UNBOUNDED PRECEDING AND CURRENT ROW) for a running total;
--   AVG(...) OVER (... ROWS BETWEEN n PRECEDING AND CURRENT ROW)
--   for a moving average.
--   Plain question: how many ratings has the platform received
--   and lost so far, and what share of recent ratings is being
--   withdrawn?
--
--   is_withdrawn is 1 for a failure and 0 otherwise, so:
--     SUM(is_withdrawn) running   = failures so far
--     AVG(is_withdrawn) moving    = failure rate of the last n
--   Two moving windows are shown side by side: the last 7
--   ratings and the last 20. 20 is the one used in the write-up:
--   it is about one month of ratings (200 a year, ~17 a month),
--   and at a 17% failure rate holds 3 to 4 failures, so one
--   rating cannot swing it by more than 5 points. A 7-row window
--   moves 14 points on a single rating.
--   ROWS counts ratings, not days: 7 rows can cover anything from
--   2 days to a few weeks, depending on how busy the period was.
-- ------------------------------------------------------------
WITH events AS (
    SELECT rating_id,
           rated_at,
           CASE WHEN rating_status = 'withdrawn' THEN 1 ELSE 0 END
                                                         AS is_withdrawn
    FROM   ratings
)
SELECT rating_id,
       rated_at,
       is_withdrawn,
       COUNT(*) OVER (ORDER BY rated_at, rating_id
                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                         AS running_ratings,
       SUM(is_withdrawn) OVER (ORDER BY rated_at, rating_id
                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                         AS running_withdrawn,
       ROUND(100.0 * AVG(is_withdrawn) OVER (ORDER BY rated_at, rating_id
                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 1)
                                                         AS running_fail_pct,
       ROUND(100.0 * AVG(is_withdrawn) OVER (ORDER BY rated_at, rating_id
                      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1)
                                                         AS last7_fail_pct,
       ROUND(100.0 * AVG(is_withdrawn) OVER (ORDER BY rated_at, rating_id
                      ROWS BETWEEN 19 PRECEDING AND CURRENT ROW), 1)
                                                         AS last20_fail_pct
FROM   events
ORDER  BY rated_at, rating_id;


-- ------------------------------------------------------------
-- Part B2  Month-end snapshot of B1
--   Plain question: where did the platform stand at the end of
--   each month: total so far, failure rate so far, and failure
--   rate over the most recent 20 ratings?
--   Same windows as B1, computed over all 200 ratings first; the
--   outer query then keeps the last rating of each month
--   (ROW_NUMBER = 1 when numbered newest first within a month).
--   The windows must run before the filter, or each month would
--   only see its own ratings.
-- ------------------------------------------------------------
WITH events AS (
    SELECT rating_id,
           rated_at,
           CASE WHEN rating_status = 'withdrawn' THEN 1 ELSE 0 END
                                                         AS is_withdrawn
    FROM   ratings
),
running AS (
    SELECT rated_at,
           COUNT(*) OVER (ORDER BY rated_at, rating_id
                          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                         AS running_ratings,
           SUM(is_withdrawn) OVER (ORDER BY rated_at, rating_id
                          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                         AS running_withdrawn,
           AVG(is_withdrawn) OVER (ORDER BY rated_at, rating_id
                          ROWS BETWEEN 19 PRECEDING AND CURRENT ROW)
                                                         AS last20_fail,
           ROW_NUMBER() OVER (PARTITION BY DATE_TRUNC('month', rated_at)
                              ORDER BY rated_at DESC, rating_id DESC)
                                                         AS newest_in_month
    FROM   events
)
SELECT TO_CHAR(rated_at, 'YYYY-MM')                      AS month_end,
       running_ratings,
       running_withdrawn,
       ROUND(100.0 * running_withdrawn / running_ratings, 1)
                                                         AS running_fail_pct,
       ROUND(100.0 * last20_fail, 1)                     AS last20_fail_pct
FROM   running
WHERE  newest_in_month = 1
ORDER  BY rated_at;


-- ------------------------------------------------------------
-- Part B3  Running total against a quarterly target
--   Requirement: choose a target, state it, and show how close
--   the running total gets.
--   Target: 46 ratings kept on the platform (not withdrawn) in
--   Q4 2023, 10% above the Q1-Q3 average of 41.7 kept ratings
--   a quarter (41, 41 and 43).
--   Plain question: did Q4 reach 46 kept ratings, and how far
--   short was it?
--
--   PARTITION BY quarter restarts the running total at the start
--   of each quarter. The outer query shows Q4 only.
-- ------------------------------------------------------------
WITH quarterly AS (
    SELECT rating_id,
           rated_at,
           rating_status,
           EXTRACT(QUARTER FROM rated_at)                AS quarter,
           SUM(CASE WHEN rating_status <> 'withdrawn' THEN 1 ELSE 0 END)
               OVER (PARTITION BY EXTRACT(QUARTER FROM rated_at)
                     ORDER BY rated_at, rating_id
                     ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                         AS kept_so_far
    FROM   ratings
)
SELECT rating_id,
       rated_at,
       rating_status,
       kept_so_far,
       46                                                AS q4_target,
       46 - kept_so_far                                  AS still_needed,
       ROUND(100.0 * kept_so_far / 46, 1)                AS pct_of_target
FROM   quarterly
WHERE  quarter = 4
ORDER  BY rated_at, rating_id;


-- ------------------------------------------------------------
-- Part B4  ROWS versus RANGE when ORDER BY values tie
--   Plain question: what does a running total do when two
--   ratings fall on the same day?
--   Ordering by the date alone creates ties (42 days in 2023 have
--   two or more ratings). Shown for the first two weeks of
--   January, which include two such days.
--   ROWS adds one row at a time, so tied rows get different
--   totals, in an order PostgreSQL picks. RANGE treats every row
--   with the same date as one peer group, so all of them get the
--   total for the end of that day.
--   The filter is applied after the window (outer query), so the
--   totals are the true year-to-date figures.
-- ------------------------------------------------------------
WITH daily AS (
    SELECT rating_id,
           rated_at::date                                AS rated_on,
           COUNT(*) OVER (ORDER BY rated_at::date
                          ROWS  BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                         AS running_rows,
           COUNT(*) OVER (ORDER BY rated_at::date
                          RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                         AS running_range
    FROM   ratings
)
SELECT rated_on,
       rating_id,
       running_rows,
       running_range
FROM   daily
WHERE  rated_on < DATE '2023-01-15'
ORDER  BY rated_on, running_rows;


-- ------------------------------------------------------------
-- Part C1  Where each movie's series stops
--   Requirement: LAG() comparing adjacent rows; a CTE that
--   computes the gap, and a WHERE in the outer query that keeps
--   only the gaps. (A window result cannot be filtered with
--   WHERE or HAVING in the same query: both run before the
--   window is computed.)
--   Plain question: which movies went 60 days or more without a
--   single rating, and how unusual is that for each movie?
--
--   gaps: days between each rating and the movie's previous one.
--   typical: each movie's average gap, as a window over gaps, so
--   every gap can be shown as a multiple of its own movie's norm.
--   60 days is about three times the typical gap (most movies get
--   a rating every 20 to 30 days).
-- ------------------------------------------------------------
WITH gaps AS (
    SELECT movie_id,
           rating_id,
           LAG(rated_at) OVER (PARTITION BY movie_id
                               ORDER BY rated_at, rating_id) AS prev_rated_at,
           rated_at
    FROM   ratings
),
typical AS (
    SELECT movie_id,
           prev_rated_at,
           rated_at,
           rated_at::date - prev_rated_at::date          AS gap_days,
           AVG(rated_at::date - prev_rated_at::date)
               OVER (PARTITION BY movie_id)              AS avg_gap_days
    FROM   gaps
    WHERE  prev_rated_at IS NOT NULL
)
SELECT movie_id,
       prev_rated_at::date                               AS last_before_gap,
       rated_at::date                                    AS resumed_on,
       gap_days,
       ROUND(avg_gap_days, 1)                            AS movie_avg_gap,
       ROUND(gap_days / avg_gap_days, 1)                 AS times_typical
FROM   typical
WHERE  gap_days >= 60
ORDER  BY gap_days DESC;


-- ------------------------------------------------------------
-- Part C2  Movie 11's gap in ratings that stayed visible
--   Plain question: counting only ratings that were not
--   withdrawn (the ones viewers could see), how long did movie 11
--   go without a new rating, and what happened in between?
--   Same LAG pattern as C1, but over kept ratings only. The
--   correlated subquery then counts every rating, withdrawn or
--   not, that arrived inside each gap.
-- ------------------------------------------------------------
WITH kept AS (
    SELECT movie_id,
           rated_at,
           LAG(rated_at) OVER (PARTITION BY movie_id
                               ORDER BY rated_at, rating_id) AS prev_rated_at
    FROM   ratings
    WHERE  rating_status <> 'withdrawn'
)
SELECT k.movie_id,
       k.prev_rated_at::date                             AS last_visible_before,
       k.rated_at::date                                  AS next_visible,
       k.rated_at::date - k.prev_rated_at::date          AS gap_days,
       (SELECT COUNT(*)
        FROM   ratings r
        WHERE  r.movie_id = k.movie_id
          AND  r.rated_at > k.prev_rated_at
          AND  r.rated_at < k.rated_at)                  AS ratings_inside_gap,
       (SELECT STRING_AGG(r.rating_id || ' ' || r.rated_at::date || ' '
                          || r.withdrawn_reason, '; ' ORDER BY r.rated_at)
        FROM   ratings r
        WHERE  r.movie_id = k.movie_id
          AND  r.rated_at > k.prev_rated_at
          AND  r.rated_at < k.rated_at)                  AS withdrawn_inside_gap
FROM   kept k
WHERE  k.movie_id = 11
  AND  k.rated_at::date - k.prev_rated_at::date >= 60;


-- ------------------------------------------------------------
-- Part C3  Was the platform still recording during the gap?
--   Plain question: while movie 11 received nothing (7 March to
--   4 June 2023), did the rest of the platform keep producing
--   ratings normally?
--   If the data feed had stopped, every movie would be silent in
--   the same window. Compares the 89-day window with the rest of
--   the year, as ratings per 30 days so the two lengths compare.
--   The gap's edges are the two movie 11 ratings either side of
--   it (163 on 7 March, 162 on 4 June), taken from the data.
-- ------------------------------------------------------------
WITH gap AS (
    SELECT (SELECT rated_at FROM ratings WHERE rating_id = 163) AS gap_start,
           (SELECT rated_at FROM ratings WHERE rating_id = 162) AS gap_end
),
periods AS (
    SELECT 'inside movie 11 gap'                         AS period,
           gap_start, gap_end,
           gap_end::date - gap_start::date               AS days
    FROM   gap
    UNION ALL
    SELECT 'rest of 2023', gap_start, gap_end,
           365 - (gap_end::date - gap_start::date)
    FROM   gap
)
SELECT p.period,
       p.days,
       COUNT(r.rating_id)                                AS ratings,
       COUNT(DISTINCT r.movie_id)                        AS movies_rated,
       SUM(CASE WHEN r.movie_id = 11 THEN 1 ELSE 0 END)  AS movie_11_ratings,
       ROUND(30.0 * COUNT(r.rating_id) / p.days, 1)      AS ratings_per_30_days
FROM   periods p
JOIN   ratings r
  ON   (p.period = 'inside movie 11 gap'
        AND r.rated_at >  p.gap_start AND r.rated_at <  p.gap_end)
   OR  (p.period = 'rest of 2023'
        AND (r.rated_at <= p.gap_start OR r.rated_at >= p.gap_end))
GROUP  BY p.period, p.days
ORDER  BY p.period;
