-- ============================================================
-- Task 5.3: Join performance and execution plans
-- Theme 2: Movie / TV
-- Database: ex603_data (loaded from the provided movies.sql)
-- Run with: psql -d ex603_data -P pager=off -e -f q5_3.sql
--
-- RESULTS
--  Part A  genres has 5 rows, movies has 15. The CROSS JOIN
--          returns 75 rows = 5 x 15. Only 25 of the 75 possible
--          movie-genre pairs are actually tagged; 50 are not.
--  Part B  EXPLAIN / EXPLAIN ANALYZE of the Task 5.1 Q1
--          three-table join (ratings, users, movies). See
--          analysis/unit5.md for the reading of the plan.
-- ============================================================


-- ============================================================
-- Part A: Explore CROSS JOIN
-- ============================================================

-- ------------------------------------------------------------
-- A1 Row counts and the Cartesian product, in one result
--   Requirement: count the rows in each source table, run the
--   CROSS JOIN and count its rows, and show the result equals the
--   product of the two counts.
--   Plain question: if every genre is paired with every movie, how
--   many pairs are there, and is it exactly genres x movies?
--   Tables chosen: genres (5 rows) and movies (15 rows), small
--   enough to read in full. A CROSS JOIN has no ON condition:
--   every row of one table is paired with every row of the other.
-- ------------------------------------------------------------
SELECT (SELECT COUNT(*) FROM genres)                       AS genres_rows,
       (SELECT COUNT(*) FROM movies)                       AS movies_rows,
       (SELECT COUNT(*) FROM genres)
     * (SELECT COUNT(*) FROM movies)                       AS expected_product,
       (SELECT COUNT(*)
        FROM   genres
        CROSS  JOIN movies)                                AS cross_join_rows;

-- ------------------------------------------------------------
-- A2 What the CROSS JOIN rows look like
--   Requirement: run the CROSS JOIN and show its rows.
--   Plain question: what does one pairing look like?
--   The first 10 of the 75 pairs: movie 1 against all 5 genres,
--   then movie 2 against all 5. Each movie appears once per genre
--   whether or not it is tagged with it.
-- ------------------------------------------------------------
SELECT m.movie_id,
       m.title,
       g.genre_id,
       g.genre_name
FROM   movies m
CROSS  JOIN genres g
ORDER  BY m.movie_id, g.genre_id
LIMIT  10;

-- ------------------------------------------------------------
-- A3 A useful Cartesian product: the genre coverage grid
--   Requirement: show when a Cartesian product is useful.
--   Plain question: of all the genre tags each movie COULD have,
--   which does it have, and how many movies are missing from each
--   genre?
--   The CROSS JOIN builds every possible (movie, genre) pair; the
--   LEFT JOIN to movie_genres then marks which pairs really exist.
--   A plain join to movie_genres could only show the 25 tags that
--   exist; the grid also shows the 50 that do not, including the
--   three movies (13, 14, 15) with no genre at all.
-- ------------------------------------------------------------
SELECT g.genre_name,
       COUNT(*)                                            AS possible_pairs,
       COUNT(mg.movie_id)                                  AS tagged,
       COUNT(*) - COUNT(mg.movie_id)                       AS not_tagged
FROM   movies m
CROSS  JOIN genres g
LEFT   JOIN movie_genres mg ON  mg.movie_id = m.movie_id
                            AND mg.genre_id = g.genre_id
GROUP  BY ROLLUP (g.genre_name)
ORDER  BY GROUPING(g.genre_name), g.genre_name;


-- ============================================================
-- Part B: Examine a query execution plan
-- ============================================================

-- ------------------------------------------------------------
-- B1 EXPLAIN
--   Requirement: show how PostgreSQL plans to execute the
--   three-table join from Task 5.1 (Q1).
--   Plain question: in what order, and with which join method,
--   will the database put ratings, users and movies together?
--   EXPLAIN only plans the query; it does not run it. The query
--   below is identical to q5_1.sql Q1.
-- ------------------------------------------------------------
EXPLAIN
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
-- B2 EXPLAIN ANALYZE
--   Requirement (optional): measure actual execution behaviour.
--   Plain question: when the query actually runs, how many rows
--   does each step produce, and how long does it take?
--   EXPLAIN ANALYZE runs the query, so it is used here only
--   because this is a read-only SELECT. Comparing "rows=" in the
--   estimate with "actual ... rows=" shows how accurate the
--   planner's guesses were.
-- ------------------------------------------------------------
EXPLAIN ANALYZE
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
-- B3 What the planner had to work with
--   Requirement: explain the join algorithms by the table sizes
--   and indexes available to the planner (two queries).
--   Plain question: which indexes exist on the three tables, and
--   does the database have up-to-date row counts for them?
--   pg_indexes lists every index. ratings has only its primary
--   key: there is no index on ratings.user_id or ratings.movie_id
--   (PostgreSQL does not create one for a foreign key).
--   pg_class.reltuples is the row count the planner believes; -1
--   means the table has never been analyzed.
-- ------------------------------------------------------------
SELECT tablename,
       indexname,
       indexdef
FROM   pg_indexes
WHERE  tablename IN ('ratings', 'users', 'movies')
ORDER  BY tablename, indexname;

-- B3 (second query) Requirement: as above, table sizes.
--   Plain question: how many rows does the planner believe each
--   table has, and when was each last analyzed?
SELECT c.relname                                           AS table_name,
       c.reltuples::bigint                                 AS planner_row_estimate,
       s.last_analyze,
       s.last_autoanalyze
FROM   pg_class c
JOIN   pg_stat_user_tables s ON s.relid = c.oid
WHERE  c.relname IN ('ratings', 'users', 'movies')
ORDER  BY c.relname;
