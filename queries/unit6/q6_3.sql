-- ============================================================
-- Task 6.3: Build the reporting patterns
-- Theme 2: Movie / TV
-- Database: ex603_data (loaded from the provided movies.sql)
-- Run with: psql -d ex603_data -P pager=off -e -f q6_3.sql
--
-- Roles: producer = movies, event = ratings, metric = score.
-- Failure = rating_status = 'withdrawn'.
-- ============================================================


-- ------------------------------------------------------------
-- Part A1  Top 3 ratings per movie
--   Requirement: a ranking window function partitioned by
--   producer; a CTE that filters to rank <= 3; FIRST_VALUE() or
--   LAST_VALUE() used somewhere; a comment on ties at third place.
--   Plain question: which three ratings should each movie page
--   feature as its "top reviews"?
--
--   Only published ratings are eligible. Withdrawn ratings were
--   removed, and flagged ones are still under review, so neither
--   should be shown publicly as a top review.
--
--   HOW TIES AT THIRD PLACE ARE HANDLED:
--   ROW_NUMBER, so every movie gets exactly three. Ties are
--   common: movie 5 has six published 5.0 ratings, and movies 7,
--   8, 10 and 12 also have more than three ratings tied at or
--   above third place. A movie page has three review slots, and
--   RANK would return four to six for those movies. The tie is
--   broken on purpose, not left to chance:
--     1. score, highest first
--     2. watch_minutes, longest first. Task 6.1 found that
--        ratings from people who watched under 10 minutes are the
--        least reliable, so among equal scores the one from the
--        viewer who watched most is the most credible.
--     3. rated_at, newest first (a fresher review)
--     4. rating_id, so the order is fixed even if all else ties
--   RANK is shown beside it so the ties stay visible, and query
--   A2 lists every rating that tied for a slot but lost it.
--
--   FIRST_VALUE(rating_id) gives each row its movie's #1 review
--   (the featured one). LAST_VALUE(score), with the frame
--   widened to UNBOUNDED FOLLOWING, gives the movie's lowest
--   published score, to show the range a reader is not seeing.
-- ------------------------------------------------------------
WITH ranked AS (
    SELECT r.movie_id,
           r.rating_id,
           r.user_id,
           r.score,
           r.watch_minutes,
           r.rated_at,
           ROW_NUMBER() OVER w                           AS slot,
           RANK()       OVER (PARTITION BY r.movie_id
                              ORDER BY r.score DESC)     AS score_rank,
           FIRST_VALUE(r.rating_id) OVER w               AS featured_rating_id,
           LAST_VALUE(r.score) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING
                                           AND UNBOUNDED FOLLOWING)
                                                         AS movie_lowest_score
    FROM   ratings r
    WHERE  r.rating_status = 'published'
    WINDOW w AS (PARTITION BY r.movie_id
                 ORDER BY r.score DESC, r.watch_minutes DESC,
                          r.rated_at DESC, r.rating_id)
)
SELECT movie_id,
       slot,
       rating_id,
       score,
       score_rank,
       watch_minutes,
       rated_at::date                                    AS rated_on,
       featured_rating_id,
       movie_lowest_score
FROM   ranked
WHERE  slot <= 3
ORDER  BY movie_id, slot;


-- ------------------------------------------------------------
-- Part A2  Who tied for a slot and lost it
--   Plain question: which ratings scored as high as a featured
--   review but were left out by the tie-break, and why?
--   A rating whose RANK is 3 or better but whose ROW_NUMBER is
--   above 3 tied for a top-three score and lost on watch time
--   (or date). Comparing it with the third slot shows the reason.
-- ------------------------------------------------------------
WITH ranked AS (
    SELECT r.movie_id,
           r.rating_id,
           r.score,
           r.watch_minutes,
           ROW_NUMBER() OVER (PARTITION BY r.movie_id
                              ORDER BY r.score DESC, r.watch_minutes DESC,
                                       r.rated_at DESC, r.rating_id) AS slot,
           RANK()       OVER (PARTITION BY r.movie_id
                              ORDER BY r.score DESC)     AS score_rank
    FROM   ratings r
    WHERE  r.rating_status = 'published'
)
SELECT o.movie_id,
       o.rating_id                                       AS left_out_rating,
       o.score,
       o.watch_minutes,
       t.rating_id                                       AS third_slot_rating,
       t.score                                           AS third_slot_score,
       t.watch_minutes                                   AS third_slot_watch
FROM   ranked o
JOIN   ranked t ON t.movie_id = o.movie_id AND t.slot = 3
WHERE  o.score_rank <= 3
  AND  o.slot > 3
ORDER  BY o.movie_id, o.slot;


-- ------------------------------------------------------------
-- Part A3  Why LAST_VALUE needs the wider frame
--   Plain question: what does LAST_VALUE return for movie 11 with
--   the default frame, and why is it wrong?
--   With ORDER BY, the default frame is RANGE BETWEEN UNBOUNDED
--   PRECEDING AND CURRENT ROW: it stops at the current row (and
--   its ties). So "last value" is just the current row's own
--   score, never the movie's lowest. Only the frame running to
--   UNBOUNDED FOLLOWING sees the whole movie.
-- ------------------------------------------------------------
SELECT rating_id,
       score,
       LAST_VALUE(score) OVER (PARTITION BY movie_id ORDER BY score DESC)
                                                         AS last_value_default,
       LAST_VALUE(score) OVER (PARTITION BY movie_id ORDER BY score DESC
                               ROWS BETWEEN UNBOUNDED PRECEDING
                                        AND UNBOUNDED FOLLOWING)
                                                         AS last_value_full_frame
FROM   ratings
WHERE  movie_id = 11
  AND  rating_status = 'published'
ORDER  BY score DESC, rating_id;


-- ------------------------------------------------------------
-- Part B1  Month over month, the whole platform
--   Requirement: group events into months (DATE_TRUNC); LAG()
--   over the monthly series; a percent-change column that avoids
--   division by zero (NULLIF); a check for missing months.
--   Plain question: is the platform getting better or worse each
--   month? Volume, withdrawals, failure rate and average score,
--   each compared with the month before.
--
--   Missing months: the series starts from a calendar built with
--   generate_series (every month from the first rating to the
--   last), LEFT JOINed to the data, so a month with no ratings
--   would appear as a row of zeros instead of disappearing. LAG
--   then always compares a month with the calendar month before
--   it. months_since_prev double-checks this: it must be 1 on
--   every row after the first.
--
--   Division by zero is real here: April 2023 had 0 withdrawals,
--   so May's percent change in withdrawals divides by 0.
--   NULLIF(prev, 0) turns that into NULL ("no base to compare")
--   instead of an error.
--   Failure rate change is in percentage points (pp), not
--   percent: 23.8% to 19.0% is -4.8 pp.
-- ------------------------------------------------------------
WITH calendar AS (
    SELECT generate_series(DATE_TRUNC('month', MIN(rated_at)),
                           DATE_TRUNC('month', MAX(rated_at)),
                           INTERVAL '1 month')           AS month
    FROM   ratings
),
monthly AS (
    SELECT c.month,
           COUNT(r.rating_id)                            AS ratings,
           COUNT(*) FILTER (WHERE r.rating_status = 'withdrawn')
                                                         AS withdrawn,
           AVG(r.score) FILTER (WHERE r.rating_status <> 'withdrawn')
                                                         AS avg_score
    FROM   calendar c
    LEFT   JOIN ratings r ON DATE_TRUNC('month', r.rated_at) = c.month
    GROUP  BY c.month
),
compared AS (
    SELECT month,
           ratings,
           withdrawn,
           100.0 * withdrawn / NULLIF(ratings, 0)        AS fail_pct,
           avg_score,
           LAG(month)     OVER (ORDER BY month)          AS prev_month,
           LAG(ratings)   OVER (ORDER BY month)          AS prev_ratings,
           LAG(withdrawn) OVER (ORDER BY month)          AS prev_withdrawn,
           LAG(100.0 * withdrawn / NULLIF(ratings, 0))
                          OVER (ORDER BY month)          AS prev_fail_pct
    FROM   monthly
)
SELECT TO_CHAR(month, 'YYYY-MM')                         AS month,
       (EXTRACT(YEAR FROM AGE(month, prev_month)) * 12
        + EXTRACT(MONTH FROM AGE(month, prev_month)))::int
                                                         AS months_since_prev,
       ratings,
       ROUND(100.0 * (ratings - prev_ratings)
             / NULLIF(prev_ratings, 0), 1)               AS ratings_pct_change,
       withdrawn,
       prev_withdrawn,
       ROUND(100.0 * (withdrawn - prev_withdrawn)
             / NULLIF(prev_withdrawn, 0), 1)             AS withdrawn_pct_change,
       ROUND(fail_pct, 1)                                AS fail_pct,
       ROUND(fail_pct - prev_fail_pct, 1)                AS fail_pp_change,
       ROUND(avg_score, 2)                               AS avg_score
FROM   compared
ORDER  BY month;


-- ------------------------------------------------------------
-- Part B2  The missing-month trap, shown on movie 11
--   Plain question: what goes wrong if LAG runs over only the
--   months that have data?
--   The platform has ratings in all 12 months, so B1's check
--   finds nothing missing. Movie 11 does not: it has no ratings
--   in April, May, September or December. Both columns below use
--   LAG; the only difference is whether the calendar was filled
--   in first.
--     naive_prev_month  - LAG over months with data only. June's
--                         "previous month" is March.
--     true_prev_month   - LAG over the full calendar. June is
--                         compared with May, which had 0 ratings.
-- ------------------------------------------------------------
WITH calendar AS (
    SELECT generate_series(DATE '2023-01-01', DATE '2023-12-01',
                           INTERVAL '1 month')           AS month
),
m11 AS (
    SELECT DATE_TRUNC('month', rated_at)                 AS month,
           COUNT(*)                                      AS ratings
    FROM   ratings
    WHERE  movie_id = 11
    GROUP  BY 1
),
naive AS (
    SELECT month,
           ratings,
           LAG(month)   OVER (ORDER BY month)            AS naive_prev_month,
           LAG(ratings) OVER (ORDER BY month)            AS naive_prev_ratings
    FROM   m11
),
filled AS (
    SELECT c.month,
           COALESCE(m.ratings, 0)                        AS ratings,
           LAG(c.month)  OVER (ORDER BY c.month)         AS true_prev_month,
           LAG(COALESCE(m.ratings, 0))
                         OVER (ORDER BY c.month)         AS true_prev_ratings
    FROM   calendar c
    LEFT   JOIN m11 m ON m.month = c.month
)
SELECT TO_CHAR(f.month, 'YYYY-MM')                       AS month,
       f.ratings,
       TO_CHAR(n.naive_prev_month, 'YYYY-MM')            AS naive_prev_month,
       n.naive_prev_ratings,
       TO_CHAR(f.true_prev_month, 'YYYY-MM')             AS true_prev_month,
       f.true_prev_ratings,
       CASE WHEN n.naive_prev_month IS NOT NULL
             AND n.naive_prev_month <> f.true_prev_month
            THEN 'WRONG MONTH' ELSE '' END               AS naive_check
FROM   filled f
LEFT   JOIN naive n ON n.month = f.month
ORDER  BY f.month;
