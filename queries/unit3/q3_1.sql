-- ============================================================
-- Task 3.1: Establish what the data contains
-- Theme 2: Movie / TV
-- Database: ex603_data (loaded from the provided movies.sql)
-- Run with: psql -d ex603_data -f q3_1.sql
--
-- WHAT THE QUERIES TOLD ME
--  3.1a Only 7 movies meet the filter, so LIMIT 10 returns 7.
--       Title_03 (2023) is excluded because it is unavailable.
--  3.1b Three statuses, not one: published 156, withdrawn 34,
--       flagged 10 (total 200). Every withdrawn rating has the
--       same placeholder score of 0.5 (min and max are both 0.5).
--  3.1c 70 ratings score 4.0 to 5.0; 44 ratings are withdrawn
--       or flagged. Withdrawal reasons seen: Spam detected,
--       Policy violation, Duplicate rating, User request.
--  3.1d LIKE finds Title_10 to Title_15. 166 ratings have no
--       withdrawn_reason: every published and flagged rating.
--       Flagged ratings carry no reason at all, and no withdrawn
--       rating was ever reviewed.
--  3.1e Labelled view. The withdrawn 0.5 placeholders are
--       labelled "Hated it", so without the second column they
--       would read as genuine terrible reviews and drag down any
--       average that includes them.
-- ============================================================


-- ------------------------------------------------------------
-- 3.1a Active, highly rated producers
--      Theme filter (appendix): is_available = 1 AND release_year > 2015
--      Requirement: SELECT, WHERE, ORDER BY, LIMIT.
--      is_available is BOOLEAN in PostgreSQL, so = TRUE, not = 1.
--      movie_id is a tie-breaker so rows with the same year
--      always come back in the same order.
-- ------------------------------------------------------------
SELECT movie_id, title, release_year, is_available
FROM   movies
WHERE  is_available = TRUE
AND    release_year > 2015
ORDER  BY release_year DESC, movie_id
LIMIT  10;


-- ------------------------------------------------------------
-- 3.1b All possible event statuses
--      First the distinct values, then how many ratings carry each,
--      so the size of each group is visible.
-- ------------------------------------------------------------
SELECT DISTINCT rating_status
FROM   ratings
ORDER  BY rating_status;

SELECT rating_status,
       COUNT(*)                 AS ratings,
       MIN(score)               AS min_score,
       MAX(score)               AS max_score
FROM   ratings
GROUP  BY rating_status
ORDER  BY rating_status;


-- ------------------------------------------------------------
-- 3.1c Filter the events two ways
--      (i)  A numeric range with BETWEEN: high scores, 4.0 to 5.0.
--           BETWEEN is inclusive at both ends.
-- ------------------------------------------------------------
SELECT rating_id, user_id, movie_id, score, rating_status
FROM   ratings
WHERE  score BETWEEN 4.0 AND 5.0
ORDER  BY score DESC, rating_id;

-- ------------------------------------------------------------
--      (ii) An explicit list with IN: every rating that is not a
--           normal published rating.
-- ------------------------------------------------------------
SELECT rating_id, user_id, movie_id, score, rating_status, withdrawn_reason
FROM   ratings
WHERE  rating_status IN ('withdrawn', 'flagged')
ORDER  BY rating_status, rating_id;


-- ------------------------------------------------------------
-- 3.1d Text and missing values
--      (i)  LIKE: movies whose title is Title_10 to Title_19.
--           In LIKE, _ is itself a wildcard (any one character),
--           so the literal underscore is escaped with \_ .
--           Without the escape, 'Title_1%' would also match a title
--           such as 'TitleX1...'.
-- ------------------------------------------------------------
SELECT movie_id, title, release_year
FROM   movies
WHERE  title LIKE 'Title\_1%' ESCAPE '\'
ORDER  BY movie_id;

-- ------------------------------------------------------------
--      (ii) NULL: ratings with no withdrawal reason.
--           = NULL never matches anything; IS NULL is required.
-- ------------------------------------------------------------
SELECT COUNT(*) AS ratings_without_reason
FROM   ratings
WHERE  withdrawn_reason IS NULL;

-- ------------------------------------------------------------
--      (iii) COALESCE: show a readable label instead of a blank,
--            for every rating that is not published.
-- ------------------------------------------------------------
SELECT rating_id,
       rating_status,
       COALESCE(withdrawn_reason, 'No reason provided') AS reason,
       COALESCE(TO_CHAR(reviewed_at, 'YYYY-MM-DD HH24:MI'),
                'Never reviewed')                      AS reviewed
FROM   ratings
WHERE  rating_status <> 'published'
ORDER  BY rating_status, rating_id;


-- ------------------------------------------------------------
-- 3.1e Results a non-SQL reader can follow
--      Computed columns with CASE labels:
--        score_band             the score as a plain-language category
--        counts_toward_average  whether this rating is a real,
--                               published rating
-- ------------------------------------------------------------
SELECT r.rating_id,
       m.title,
       u.user_name,
       r.score,
       CASE
           WHEN r.score >= 4.5 THEN 'Loved it'
           WHEN r.score >= 3.5 THEN 'Liked it'
           WHEN r.score >= 2.5 THEN 'Mixed'
           WHEN r.score >= 1.5 THEN 'Disliked it'
           ELSE                     'Hated it'
       END                                         AS score_band,
       CASE r.rating_status
           WHEN 'published' THEN 'Yes'
           WHEN 'flagged'   THEN 'Under review'
           ELSE                  'No (withdrawn)'
       END                                         AS counts_toward_average
FROM   ratings r
JOIN   movies  m ON m.movie_id = r.movie_id
JOIN   users   u ON u.user_id  = r.user_id
ORDER  BY r.rating_id
LIMIT  20;