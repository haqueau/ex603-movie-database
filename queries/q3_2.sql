-- ============================================================
-- Task 3.2: Find the bug
-- Theme 2: Movie / TV
-- Database: ex603_data (loaded from the provided movies.sql)
-- Run with: psql -d ex603_data -e -f q3_2.sql
--
-- Note: query B1 fails ON PURPOSE (that is the bug being
-- reproduced). psql reports the error and carries on with the
-- rest of the file, so the file still runs without editing.
--
-- RESULTS
--  A1 200 ratings; 34 have a withdrawn_reason, 166 are NULL.
--  A2 Broken query returns 22.
--  A3 22 (not spam) + 12 (spam) = 34, but the table holds 200.
--     The 166 NULL rows were dropped silently.
--  A4 Repaired query returns 188 (= 200 - 12 spam).
--  A5 Broken filter credits only 12 of 30 reviewers; repaired
--     filter credits all 30. 20 reviewers have no spam
--     withdrawals, 10 have at least one. User_13: 0 eligible
--     ratings under the broken filter, 11 when repaired.
--  B1 ERROR: column "score_band" does not exist
--  B2 and B3 both return the same 54 'Loved it' ratings.
-- ============================================================


-- ============================================================
-- PART A: The rows that vanished
-- ============================================================

-- ------------------------------------------------------------
-- A1 The nullable column: ratings.withdrawn_reason
--    The dataset already contains NULLs here, so none were
--    inserted. A reason is only recorded when a rating is
--    withdrawn; published and flagged ratings have NULL.
-- ------------------------------------------------------------
SELECT COUNT(*)                      AS total_ratings,
       COUNT(withdrawn_reason)       AS with_reason,
       COUNT(*) - COUNT(withdrawn_reason) AS reason_is_null
FROM   ratings;


-- ------------------------------------------------------------
-- A2 The broken query
--    Intent: every rating that was NOT withdrawn as spam, i.e.
--    the ratings that should stay eligible for reviewer payouts.
--    For a NULL reason, NULL <> 'Spam detected' is UNKNOWN, not
--    TRUE, so WHERE throws those rows away with no warning.
-- ------------------------------------------------------------
SELECT COUNT(*) AS not_spam_broken
FROM   ratings
WHERE  withdrawn_reason <> 'Spam detected';


-- ------------------------------------------------------------
-- A3 The rows A2 silently omitted
--    A2 and its opposite (= 'Spam detected') look like they
--    should cover every row between them. They do not: the
--    NULL rows match neither, so the two counts fall short of
--    the table total by exactly the number of NULLs.
-- ------------------------------------------------------------
SELECT COUNT(*) FILTER (WHERE withdrawn_reason <> 'Spam detected') AS a2_not_spam,
       COUNT(*) FILTER (WHERE withdrawn_reason =  'Spam detected') AS spam,
       COUNT(*) FILTER (WHERE withdrawn_reason <> 'Spam detected')
     + COUNT(*) FILTER (WHERE withdrawn_reason =  'Spam detected') AS sum_of_both,
       COUNT(*)                                                    AS table_total,
       COUNT(*) FILTER (WHERE withdrawn_reason IS NULL)            AS silently_omitted
FROM   ratings;


-- ------------------------------------------------------------
-- A4 The repair
--    State the NULL case explicitly with IS NULL, so a rating
--    with no reason counts as "not spam", which is what was
--    intended. Equivalent alternative:
--      WHERE COALESCE(withdrawn_reason, '') <> 'Spam detected'
-- ------------------------------------------------------------
SELECT COUNT(*) AS not_spam_fixed
FROM   ratings
WHERE  withdrawn_reason <> 'Spam detected'
   OR  withdrawn_reason IS NULL;


-- ------------------------------------------------------------
-- A5 Impact on reviewers (supports the Task 3.4 memo)
--    The same broken and repaired filters, counted per reviewer.
--    First a summary, then the per-reviewer detail.
-- ------------------------------------------------------------
WITH per_reviewer AS (
    SELECT u.user_id,
           u.user_name,
           COUNT(*) FILTER (WHERE r.withdrawn_reason <> 'Spam detected')     AS eligible_broken,
           COUNT(*) FILTER (WHERE r.withdrawn_reason <> 'Spam detected'
                               OR r.withdrawn_reason IS NULL)                AS eligible_fixed,
           COUNT(*) FILTER (WHERE r.withdrawn_reason =  'Spam detected')     AS spam_withdrawals
    FROM   users   u
    JOIN   ratings r ON r.user_id = u.user_id
    GROUP  BY u.user_id, u.user_name
)
SELECT COUNT(*) FILTER (WHERE eligible_broken  > 0) AS reviewers_credited_broken,
       COUNT(*) FILTER (WHERE eligible_fixed   > 0) AS reviewers_credited_fixed,
       COUNT(*) FILTER (WHERE spam_withdrawals = 0) AS reviewers_no_spam,
       COUNT(*) FILTER (WHERE spam_withdrawals > 0) AS reviewers_with_spam
FROM   per_reviewer;

SELECT u.user_name,
       COUNT(*) FILTER (WHERE r.withdrawn_reason <> 'Spam detected')     AS eligible_broken,
       COUNT(*) FILTER (WHERE r.withdrawn_reason <> 'Spam detected'
                           OR r.withdrawn_reason IS NULL)                AS eligible_fixed,
       COUNT(*) FILTER (WHERE r.withdrawn_reason =  'Spam detected')     AS spam_withdrawals
FROM   users   u
JOIN   ratings r ON r.user_id = u.user_id
GROUP  BY u.user_id, u.user_name
ORDER  BY eligible_fixed DESC, u.user_id;


-- ============================================================
-- PART B: The alias that did not exist yet
-- SQL is written SELECT ... FROM ... WHERE, but evaluated
-- FROM -> WHERE -> SELECT -> ORDER BY. WHERE runs before SELECT,
-- so an alias defined in SELECT does not exist yet in WHERE.
-- ============================================================

-- ------------------------------------------------------------
-- B1 The failing query. Error captured verbatim from psql 18.6:
--
--    ERROR:  column "score_band" does not exist
--    LINE 11: WHERE  score_band = 'Loved it';
--                    ^
-- ------------------------------------------------------------
SELECT rating_id,
       score,
       CASE
           WHEN score >= 4.5 THEN 'Loved it'
           WHEN score >= 3.5 THEN 'Liked it'
           WHEN score >= 2.5 THEN 'Mixed'
           WHEN score >= 1.5 THEN 'Disliked it'
           ELSE                   'Hated it'
       END AS score_band
FROM   ratings
WHERE  score_band = 'Loved it';


-- ------------------------------------------------------------
-- B2 Rewrite 1: repeat the expression in WHERE
--    Works, but the CASE now lives in two places and the two
--    copies can drift apart if one is edited later.
-- ------------------------------------------------------------
SELECT rating_id,
       score,
       CASE
           WHEN score >= 4.5 THEN 'Loved it'
           WHEN score >= 3.5 THEN 'Liked it'
           WHEN score >= 2.5 THEN 'Mixed'
           WHEN score >= 1.5 THEN 'Disliked it'
           ELSE                   'Hated it'
       END AS score_band
FROM   ratings
WHERE  CASE
           WHEN score >= 4.5 THEN 'Loved it'
           WHEN score >= 3.5 THEN 'Liked it'
           WHEN score >= 2.5 THEN 'Mixed'
           WHEN score >= 1.5 THEN 'Disliked it'
           ELSE                   'Hated it'
       END = 'Loved it'
ORDER  BY rating_id;


-- ------------------------------------------------------------
-- B3 Rewrite 2: wrap the query in a CTE
--    Inside the CTE, score_band is computed once. The outer
--    query reads it as an ordinary column, so WHERE can use it.
-- ------------------------------------------------------------
WITH banded AS (
    SELECT rating_id,
           score,
           CASE
               WHEN score >= 4.5 THEN 'Loved it'
               WHEN score >= 3.5 THEN 'Liked it'
               WHEN score >= 2.5 THEN 'Mixed'
               WHEN score >= 1.5 THEN 'Disliked it'
               ELSE                   'Hated it'
           END AS score_band
    FROM   ratings
)
SELECT rating_id, score, score_band
FROM   banded
WHERE  score_band = 'Loved it'
ORDER  BY rating_id;