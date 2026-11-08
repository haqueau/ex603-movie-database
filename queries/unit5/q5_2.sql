-- ============================================================
-- Task 5.2: Find records that joins may exclude
-- Theme 2: Movie / TV
-- Database: ex603_data (loaded from the provided movies.sql)
-- Run with: psql -d ex603_data -P pager=off -e -f q5_2.sql
--
-- Relationship examined: producer (movies) to event (ratings).
-- Every count of producers uses COUNT(DISTINCT movie_id), so a
-- movie with many ratings is counted once.
--
-- RESULTS
--  Part A  LEFT JOIN: 15 movies (202 rows). INNER JOIN: 13 movies
--          (200 rows). The inner join drops 2 movies: 14 and 15,
--          the only movies with no ratings.
--  Part B  RIGHT JOIN (tables swapped) returns the same 202 rows as
--          the LEFT JOIN; EXCEPT in both directions returns 0 rows.
--          FULL OUTER JOIN also returns 202 rows: 2 movies with no
--          ratings, and 0 ratings with no movie, because the
--          foreign key fk_ratings_prod makes an orphan rating
--          impossible.
--  Part C  NOT EXISTS and EXCEPT both return movies 14 and 15;
--          EXCEPT in both directions between them returns 0 rows.
-- ============================================================


-- ============================================================
-- Part A: Compare INNER JOIN and LEFT JOIN
-- ============================================================

-- ------------------------------------------------------------
-- A1 LEFT JOIN
--   Requirement: return all producers, including those that have
--   never had an event.
--   Plain question: how many ratings has every movie received,
--   including the movies nobody has rated?
--   movies is the left table, so every movie is kept. A movie with
--   no match gets NULLs on the ratings side; COUNT(r.rating_id)
--   skips NULLs, so it shows 0 rather than 1.
-- ------------------------------------------------------------
SELECT m.movie_id,
       m.title,
       m.is_available,
       COUNT(r.rating_id)                                  AS ratings
FROM   movies  m
LEFT   JOIN ratings r ON r.movie_id = m.movie_id
GROUP  BY m.movie_id, m.title, m.is_available
ORDER  BY ratings, m.movie_id;

-- ------------------------------------------------------------
-- A2 INNER JOIN
--   Requirement: the equivalent query using INNER JOIN.
--   Plain question: the same per-movie count, but with an inner
--   join. Which movies are left out?
--   An inner join keeps a movie only if at least one rating
--   matches it, so unrated movies disappear instead of showing 0.
-- ------------------------------------------------------------
SELECT m.movie_id,
       m.title,
       m.is_available,
       COUNT(r.rating_id)                                  AS ratings
FROM   movies  m
JOIN   ratings r ON r.movie_id = m.movie_id
GROUP  BY m.movie_id, m.title, m.is_available
ORDER  BY ratings, m.movie_id;

-- ------------------------------------------------------------
-- A3 Count of producers excluded by the inner join
--   Requirement: determine how many producers the inner join
--   excludes, counting unique identifiers.
--   Plain question: how many movies does each join return, and
--   how many go missing with the inner join?
--   rows shows why DISTINCT matters: the joins return 202 and 200
--   rows, but those rows hold only 15 and 13 movies.
-- ------------------------------------------------------------
WITH left_join AS (
    SELECT COUNT(*)                                        AS rows_returned,
           COUNT(DISTINCT m.movie_id)                      AS producers
    FROM   movies  m
    LEFT   JOIN ratings r ON r.movie_id = m.movie_id
),
inner_join AS (
    SELECT COUNT(*)                                        AS rows_returned,
           COUNT(DISTINCT m.movie_id)                      AS producers
    FROM   movies  m
    JOIN   ratings r ON r.movie_id = m.movie_id
)
SELECT l.rows_returned                                     AS left_rows,
       i.rows_returned                                     AS inner_rows,
       l.producers                                         AS left_producers,
       i.producers                                         AS inner_producers,
       l.producers - i.producers                           AS excluded_by_inner
FROM   left_join l
CROSS  JOIN inner_join i;


-- ============================================================
-- Part B: Explore RIGHT JOIN and FULL OUTER JOIN
-- ============================================================

-- ------------------------------------------------------------
-- B1 RIGHT JOIN
--   Requirement: a RIGHT JOIN returning the same records as the
--   LEFT JOIN in Part A.
--   Plain question: if the table order is swapped, does keeping
--   every row of the right-hand table give the same answer?
--   ratings RIGHT JOIN movies keeps every movie, exactly as
--   movies LEFT JOIN ratings does. Only the table order changes.
-- ------------------------------------------------------------
SELECT m.movie_id,
       m.title,
       m.is_available,
       COUNT(r.rating_id)                                  AS ratings
FROM   ratings r
RIGHT  JOIN movies m ON m.movie_id = r.movie_id
GROUP  BY m.movie_id, m.title, m.is_available
ORDER  BY ratings, m.movie_id;

-- ------------------------------------------------------------
-- B2 Verify that RIGHT JOIN and LEFT JOIN match
--   Requirement: compare the results to confirm they match,
--   rather than assuming it.
--   Plain question: is there any row in one result that is not in
--   the other?
--   EXCEPT is checked in both directions, at the row level
--   (movie and rating), so a missing or extra rating would show.
--   Both counts must be 0, and the row totals must be equal.
-- ------------------------------------------------------------
WITH left_rows AS (
    SELECT m.movie_id, r.rating_id
    FROM   movies m LEFT JOIN ratings r ON r.movie_id = m.movie_id
),
right_rows AS (
    SELECT m.movie_id, r.rating_id
    FROM   ratings r RIGHT JOIN movies m ON m.movie_id = r.movie_id
)
SELECT (SELECT COUNT(*) FROM left_rows)                    AS left_join_rows,
       (SELECT COUNT(*) FROM right_rows)                   AS right_join_rows,
       (SELECT COUNT(*) FROM (SELECT * FROM left_rows
                              EXCEPT
                              SELECT * FROM right_rows) x) AS in_left_not_right,
       (SELECT COUNT(*) FROM (SELECT * FROM right_rows
                              EXCEPT
                              SELECT * FROM left_rows) y)  AS in_right_not_left;

-- ------------------------------------------------------------
-- B3 FULL OUTER JOIN
--   Requirement: include matching and unmatched records from both
--   tables.
--   Plain question: are there movies with no ratings AND ratings
--   with no movie?
--   match_type labels each row by which side is missing:
--     'movie, no ratings'  -> movie side present, rating side NULL
--     'rating, no movie'   -> rating side present, movie side NULL
--     'matched'            -> both present
-- ------------------------------------------------------------
SELECT CASE WHEN r.rating_id IS NULL THEN 'movie, no ratings'
            WHEN m.movie_id  IS NULL THEN 'rating, no movie'
            ELSE 'matched' END                             AS match_type,
       COUNT(*)                                            AS rows_returned,
       COUNT(DISTINCT m.movie_id)                          AS movies,
       COUNT(r.rating_id)                                  AS ratings,
       STRING_AGG(DISTINCT CASE WHEN r.rating_id IS NULL
                                THEN m.movie_id::text END,
                  ', ')                                    AS unmatched_movie_ids
FROM   movies  m
FULL   OUTER JOIN ratings r ON r.movie_id = m.movie_id
GROUP  BY 1
ORDER  BY 1;

-- ------------------------------------------------------------
-- B3 (detail) The unmatched rows themselves
--   Requirement: show the unmatched records from both tables that
--   the full outer join returns.
--   Plain question: which movies have no ratings, and which
--   ratings have no movie?
--   A NULL on the movie side would mean an orphan rating; a NULL
--   on the rating side means an unrated movie. On this dataset
--   only the movie side has any.
-- ------------------------------------------------------------
SELECT m.movie_id,
       m.title,
       r.rating_id,
       r.movie_id                                          AS rating_movie_id
FROM   movies  m
FULL   OUTER JOIN ratings r ON r.movie_id = m.movie_id
WHERE  m.movie_id IS NULL
   OR  r.rating_id IS NULL
ORDER  BY m.movie_id, r.rating_id;


-- ============================================================
-- Part C: Find producers with no events using two approaches
-- ============================================================

-- ------------------------------------------------------------
-- C1 NOT EXISTS
--   Requirement: identify producers that have never had an event.
--   Plain question: which movies have never been rated, and what
--   do we know about them?
--   For each movie, the subquery looks for any rating with its
--   movie_id; the movie is kept only when none exists. Because it
--   works row by row on movies, every movie column is available.
-- ------------------------------------------------------------
SELECT m.movie_id,
       m.title,
       m.origin_country,
       m.release_year,
       m.added_on,
       m.is_available
FROM   movies m
WHERE  NOT EXISTS (
           SELECT 1
           FROM   ratings r
           WHERE  r.movie_id = m.movie_id
       )
ORDER  BY m.movie_id;

-- ------------------------------------------------------------
-- C2 EXCEPT
--   Requirement: the same question with EXCEPT.
--   Plain question: which movie IDs are in the catalog but never
--   appear in the ratings table?
--   EXCEPT subtracts one set of IDs from another, so it can only
--   return the column both sides share: movie_id. It also removes
--   duplicates, which is why the ratings side needs no DISTINCT.
-- ------------------------------------------------------------
SELECT movie_id FROM movies
EXCEPT
SELECT movie_id FROM ratings
ORDER  BY movie_id;

-- ------------------------------------------------------------
-- C3 Verify the two approaches agree
--   Requirement: compare the results of both queries.
--   Plain question: do NOT EXISTS and EXCEPT pick out exactly the
--   same movies?
--   Each set is subtracted from the other; both differences must
--   be empty, and both sets must have the same size.
-- ------------------------------------------------------------
WITH via_not_exists AS (
    SELECT m.movie_id
    FROM   movies m
    WHERE  NOT EXISTS (SELECT 1 FROM ratings r
                       WHERE  r.movie_id = m.movie_id)
),
via_except AS (
    SELECT movie_id FROM movies
    EXCEPT
    SELECT movie_id FROM ratings
)
SELECT (SELECT COUNT(*) FROM via_not_exists)               AS not_exists_count,
       (SELECT COUNT(*) FROM via_except)                   AS except_count,
       (SELECT COUNT(*) FROM (SELECT movie_id FROM via_not_exists
                              EXCEPT
                              SELECT movie_id FROM via_except) a)
                                                           AS only_in_not_exists,
       (SELECT COUNT(*) FROM (SELECT movie_id FROM via_except
                              EXCEPT
                              SELECT movie_id FROM via_not_exists) b)
                                                           AS only_in_except;
