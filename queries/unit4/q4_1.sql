-- ============================================================
-- Task 4.1: Measure the platform
-- Theme 2: Movie / TV
-- Database: ex603_data (loaded from the provided movies.sql)
-- Run with: psql -d ex603_data -e -f q4_1.sql
--
-- Roles (theme appendix): actor = users, producer = movies,
-- event = ratings, metric = score.
--
-- DEFINITIONS USED IN UNIT 4
--   Failure = a rating with rating_status = 'withdrawn'.
--     The appendix does not define failure for this theme.
--     Withdrawn is the only status that means the rating was
--     removed from the platform. Flagged ratings are still under
--     review, so they are not counted as failures yet.
--   Region  = ratings.device_country, the country the rating was
--     made from. It is the only geography stored on the event row
--     itself. (Only 37 of 200 ratings come from the reviewer's
--     home country, so users.country would tell a different story.)
--
-- RESULTS
--  Q1 200 ratings, total score 569.3, average 2.85, min 0.5,
--     max 5.0, 30 distinct reviewers, 13 of 15 movies rated.
--     Data-quality issue: the minimum (0.5) belongs only to the
--     34 withdrawn ratings, and every withdrawn rating carries
--     exactly 0.5. It is a placeholder, not a real opinion.
--     Excluding them, the average rises from 2.85 to 3.33 and
--     the real minimum is 0.8.
--  Q2 Activity ranges from 21 ratings (movie 6) to 6 (movie 4);
--     movies 14 and 15 have none. Average score with the
--     placeholders ranges 2.09 to 3.51; without them 2.76 to 4.11.
--     Movie 11 has the lowest average with or without them.
--  Q3 Threshold: at least 10 ratings. Keeps 12 of 13 rated
--     movies; drops only movie 4 (6 ratings, 2 withdrawn = 33%).
--     Failure rates of the remaining 12: 0% (movie 10) to
--     31.3% (movie 11).
--  Q4 62 region x movie combinations. Many are thin: 26 have
--     fewer than 3 ratings, and the largest has 8.
-- ============================================================


-- ------------------------------------------------------------
-- Q1 Platform baseline
--    Requirement: count, total, average, minimum and maximum of
--    the metric across the whole event table, plus how many
--    distinct actors appear.
--    Plain question: how many ratings are there, what do they
--    add up to, what is a typical score, and how many people
--    wrote them?
-- ------------------------------------------------------------
SELECT COUNT(*)                 AS ratings,
       COUNT(score)             AS ratings_with_score,
       SUM(score)               AS total_score,
       ROUND(AVG(score), 2)     AS avg_score,
       MIN(score)               AS min_score,
       MAX(score)               AS max_score,
       COUNT(DISTINCT user_id)  AS distinct_reviewers,
       COUNT(DISTINCT movie_id) AS distinct_movies_rated
FROM   ratings;

-- ------------------------------------------------------------
-- Q1 follow-up: investigate the minimum
--    Plain question: where does the lowest score come from?
--    Every withdrawn rating scores exactly 0.5, and no other
--    rating does, so 0.5 is a placeholder written on removal.
-- ------------------------------------------------------------
SELECT rating_status,
       COUNT(*)                         AS ratings,
       MIN(score)                       AS min_score,
       MAX(score)                       AS max_score,
       COUNT(*) FILTER (WHERE score = 0.5) AS scored_exactly_0_5
FROM   ratings
GROUP  BY rating_status
ORDER  BY rating_status;


-- ------------------------------------------------------------
-- Q2 Event count and average metric per producer
--    Requirement: events and average metric for each producer,
--    sorted from most events to fewest.
--    Plain question: which movies get rated most, and how well?
--    LEFT JOIN from movies so titles with no ratings still
--    appear (with 0), instead of silently dropping out.
--    avg_score_excl_withdrawn removes the 0.5 placeholders found
--    in Q1.
-- ------------------------------------------------------------
SELECT m.movie_id,
       COUNT(r.rating_id)                                   AS ratings,
       ROUND(AVG(r.score), 2)                               AS avg_score,
       ROUND(AVG(CASE WHEN r.rating_status <> 'withdrawn'
                      THEN r.score END), 2)                 AS avg_score_excl_withdrawn
FROM   movies  m
LEFT   JOIN ratings r ON r.movie_id = m.movie_id
GROUP  BY m.movie_id
ORDER  BY ratings DESC, m.movie_id;


-- ------------------------------------------------------------
-- Q3 Producers with enough volume for their rate to mean anything
--    Requirement: a minimum event-count threshold applied with
--    HAVING.
--    Plain question: which movies have enough ratings that their
--    failure rate is worth acting on?
--
--    Why 10: with 10 ratings, one withdrawal moves the rate by
--    10 points, which is already coarse; below that a single
--    event swings it further (movie 4: 1 more withdrawal would
--    take it from 33% to 50%). The data also has a natural gap:
--    every rated movie has 11 or more ratings except movie 4,
--    which has 6. So 10 excludes the one outlier without
--    discarding any movie of normal volume.
-- ------------------------------------------------------------
SELECT movie_id,
       COUNT(*)                                             AS ratings,
       SUM(CASE WHEN rating_status = 'withdrawn'
                THEN 1 ELSE 0 END)                          AS withdrawn,
       ROUND(100.0 * SUM(CASE WHEN rating_status = 'withdrawn'
                              THEN 1 ELSE 0 END)
                   / COUNT(*), 1)                           AS failure_rate_pct
FROM   ratings
GROUP  BY movie_id
HAVING COUNT(*) >= 10
ORDER  BY failure_rate_pct DESC, movie_id;


-- ------------------------------------------------------------
-- Q4 Two dimensions at once: region x producer
--    Requirement: group by two dimensions, one of them region,
--    one row per combination.
--    Plain question: for each region, how did each movie do
--    there?  A regional leader filters to their own country.
-- ------------------------------------------------------------
SELECT device_country                                       AS region,
       movie_id,
       COUNT(*)                                             AS ratings,
       SUM(CASE WHEN rating_status = 'withdrawn'
                THEN 1 ELSE 0 END)                          AS withdrawn,
       ROUND(100.0 * SUM(CASE WHEN rating_status = 'withdrawn'
                              THEN 1 ELSE 0 END)
                   / COUNT(*), 1)                           AS failure_rate_pct,
       ROUND(AVG(CASE WHEN rating_status <> 'withdrawn'
                      THEN score END), 2)                   AS avg_score_excl_withdrawn
FROM   ratings
GROUP  BY device_country, movie_id
ORDER  BY region, movie_id;
