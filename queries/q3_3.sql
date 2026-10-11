-- ============================================================
-- Task 3.3: Hand the team a corrected query
-- Theme 2: Movie / TV
-- Database: ex603_data (loaded from the provided movies.sql)
-- Run with: psql -d ex603_data -e -f q3_3.sql
--
-- THE QUESTION (two steps)
--   Which users have NEVER had a rating withdrawn as spam?
--   These are the reviewers who stay eligible for payouts.
--   Step 1: find the users with a spam-withdrawn rating.
--   Step 2: return every user who is not in that group.
--
-- RESULTS
--   Step 1 finds 10 users (1, 4, 6, 7, 15, 17, 19, 21, 27, 29).
--   All three forms return the same 20 users.
--   Check C1: every pairwise difference is 0 rows.
--   Check C2: a NULL in the subquery makes Form 1 return an
--             EMPTY result (0 rows) while Forms 2 and 3 still
--             return 20.
-- ============================================================


-- ------------------------------------------------------------
-- Form 1: subquery with NOT IN
--   The inner query is step 1; NOT IN keeps everyone else.
-- ------------------------------------------------------------
SELECT user_id, user_name
FROM   users
WHERE  user_id NOT IN (
           SELECT user_id
           FROM   ratings
           WHERE  withdrawn_reason = 'Spam detected'
       )
ORDER  BY user_id;


-- ------------------------------------------------------------
-- Form 2: Common Table Expression with WITH
--   Step 1 becomes a named result, spam_users. A LEFT JOIN
--   keeps every user; users with no match in spam_users get
--   NULL on the right side, and those are the ones we want.
-- ------------------------------------------------------------
WITH spam_users AS (
    SELECT DISTINCT user_id
    FROM   ratings
    WHERE  withdrawn_reason = 'Spam detected'
)
SELECT u.user_id, u.user_name
FROM   users u
LEFT   JOIN spam_users s ON s.user_id = u.user_id
WHERE  s.user_id IS NULL
ORDER  BY u.user_id;


-- ------------------------------------------------------------
-- Form 3: set-based, with EXCEPT
--   All users, minus the set of users with a spam withdrawal.
--   EXCEPT compares whole rows and does not guarantee order,
--   so ORDER BY is applied to the final result.
-- ------------------------------------------------------------
SELECT user_id, user_name
FROM   users
EXCEPT
SELECT u.user_id, u.user_name
FROM   users   u
JOIN   ratings r ON r.user_id = u.user_id
WHERE  r.withdrawn_reason = 'Spam detected'
ORDER  BY user_id;


-- ------------------------------------------------------------
-- C1 Proof that the three result sets are identical
--   Matching counts are not enough, so each pair is compared
--   row by row in both directions. A EXCEPT B lists rows in A
--   that are missing from B. If every difference is 0 rows
--   and the counts match, the sets contain exactly the same
--   rows. (user_id is a primary key, so no form can contain
--   duplicate rows that EXCEPT would hide.)
-- ------------------------------------------------------------
WITH
form1 AS (
    SELECT user_id, user_name
    FROM   users
    WHERE  user_id NOT IN (SELECT user_id FROM ratings
                           WHERE withdrawn_reason = 'Spam detected')
),
form2 AS (
    SELECT u.user_id, u.user_name
    FROM   users u
    LEFT   JOIN (SELECT DISTINCT user_id FROM ratings
                 WHERE withdrawn_reason = 'Spam detected') s
           ON s.user_id = u.user_id
    WHERE  s.user_id IS NULL
),
form3 AS (
    SELECT user_id, user_name FROM users
    EXCEPT
    SELECT u.user_id, u.user_name
    FROM   users u JOIN ratings r ON r.user_id = u.user_id
    WHERE  r.withdrawn_reason = 'Spam detected'
)
SELECT (SELECT COUNT(*) FROM form1)                                    AS form1_rows,
       (SELECT COUNT(*) FROM form2)                                    AS form2_rows,
       (SELECT COUNT(*) FROM form3)                                    AS form3_rows,
       (SELECT COUNT(*) FROM (SELECT * FROM form1 EXCEPT SELECT * FROM form2) d) AS in1_not2,
       (SELECT COUNT(*) FROM (SELECT * FROM form2 EXCEPT SELECT * FROM form1) d) AS in2_not1,
       (SELECT COUNT(*) FROM (SELECT * FROM form1 EXCEPT SELECT * FROM form3) d) AS in1_not3,
       (SELECT COUNT(*) FROM (SELECT * FROM form3 EXCEPT SELECT * FROM form1) d) AS in3_not1;


-- ------------------------------------------------------------
-- C2 When the three are NOT equivalent: the empty result
--   If the step-1 list ever contains a NULL, Form 1 returns an
--   EMPTY result. "x NOT IN (1, 4, NULL)" means
--   "x <> 1 AND x <> 4 AND x <> NULL", and x <> NULL is
--   UNKNOWN, so the condition is never TRUE for any user.
--   Forms 2 and 3 are unaffected: the LEFT JOIN never matches
--   a NULL, and EXCEPT only removes rows that are present.
--
--   ratings.user_id is NOT NULL in this dataset, so the NULL is
--   simulated with UNION ALL SELECT NULL rather than inserted.
--   It would arise for real if the subquery read a nullable
--   column, for example users.invited_by.
--
--   (By contrast, an EMPTY step-1 list does not break
--   equivalence: with no spam ratings, all three forms
--   correctly return all 30 users.)
-- ------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM users
     WHERE user_id NOT IN (SELECT user_id FROM ratings
                           WHERE withdrawn_reason = 'Spam detected'
                           UNION ALL SELECT NULL))             AS form1_not_in,
    (SELECT COUNT(*) FROM users u
     LEFT JOIN (SELECT user_id FROM ratings
                WHERE withdrawn_reason = 'Spam detected'
                UNION ALL SELECT NULL) s
            ON s.user_id = u.user_id
     WHERE s.user_id IS NULL)                                  AS form2_cte_join,
    (SELECT COUNT(*) FROM (
        SELECT user_id FROM users
        EXCEPT
        (SELECT user_id FROM ratings
         WHERE withdrawn_reason = 'Spam detected'
         UNION ALL SELECT NULL)) x)                            AS form3_except;