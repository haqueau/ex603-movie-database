# ex603-movie-database
**Author:** Auyon Haque  
**Theme:** 2 — Movie / TV

A relational database that records users, movies, and the ratings users give
to movies, with genres inside a catalog.

## Entity roles

| Role | Table | Notes |
|---|---|---|
| actor | `users` | People who watch and rate |
| producer | `movies` | The titles being rated |
| event | `ratings` | One row per user rating a movie |
| catalog | `genres` | Reusable genre list |
| junction | `movie_genres` | Resolves the many-to-many between movies and genres |
| metric | `score` | The numeric measure carried on `ratings` |

## Repository structure

- `/schema` — DDL script, ERD image, and constraint justifications
- `/queries` — the Unit 3 `.sql` files (`q3_1`–`q3_3`), plus one subfolder per later unit (`unit4`, …) holding that assignment's queries
- `/analysis` — written notes and reflections, one markdown file per unit
- `/screenshots` — execution evidence, named to map to the task it supports

## Building the database

Requires PostgreSQL 14 or later.

```
createdb ex603
psql -d ex603 -f schema/schema.sql
```

The script can be run repeatedly. Its reset block drops the tables in
reverse dependency order before recreating them, so a second run succeeds
exactly like the first.

### The analysis dataset (Units 3 onward)

From Unit 3, every query runs against the course's provided dataset rather
than the Unit 2 schema. It uses the appendix table names (`movies`,
`movie_genres`) and holds 30 users, 15 movies and 200 ratings.

```
createdb ex603_data
psql -d ex603_data -f movies.sql
```

Each query file then runs unchanged, for example:

```
psql -d ex603_data -P pager=off -e -f queries/unit4/q4_1.sql
```

`-e` prints each query above its result, and `-P pager=off` prints long
results in full.

## Query catalogue

Every query file starts with a header recording what its queries found. In
Unit 4, a **failure** is a withdrawn rating (`rating_status = 'withdrawn'`) and
a **region** is the country a rating was made from (`ratings.device_country`).

### Unit 3: Establish what the data contains

| File | Query | Business question it answers |
|---|---|---|
| `queries/q3_1.sql` | 3.1a | Which available movies were released after 2015? |
| | 3.1b | What statuses can a rating have, and how many ratings carry each? |
| | 3.1c | Which ratings score 4.0–5.0, and which are withdrawn or flagged? |
| | 3.1d | Which titles match a name pattern, and which ratings have no withdrawal reason? |
| | 3.1e | How would each rating read to someone who doesn't write SQL? |
| `queries/q3_2.sql` | A1–A5 | Why did the dashboard credit only 12 of 30 reviewers, and what are the correct counts? |
| | B1–B3 | Why can't a SELECT alias be used in WHERE, and what are the two ways around it? |
| `queries/q3_3.sql` | Forms 1–3 | Which reviewers have never had a rating withdrawn as spam? |
| | C1–C2 | Do the three forms return identical rows, and when does NOT IN break? |

### Unit 4: From rows to insight

| File | Query | Business question it answers |
|---|---|---|
| `queries/unit4/q4_1.sql` | Q1 | How many ratings are there, what do they total, what is a typical score, and how many reviewers wrote them? |
| | Q1 follow-up | Where does the lowest score come from? (Every withdrawn rating carries a 0.5 placeholder.) |
| | Q2 | Which movies get rated most, and how well? |
| | Q3 | Which movies have enough ratings (10+) for their failure rate to be worth acting on? |
| | Q4 | For each region, how did each movie do there? |
| `queries/unit4/q4_2.sql` | Part A | For each movie, how many ratings did it get, and how many were withdrawn? (one pass) |
| | Part B | What is each region's failure rate, and what is the platform's overall? (ROLLUP subtotals and grand total) |
| | Part C1 | What failure rate is normal for a movie with enough ratings to judge? |
| | Part C2 | Which high-volume movies are well above that normal rate? |

Write-ups: `analysis/unit4.md` (Tasks 4.1 and 4.2, and the reflection) and
`analysis/unit4-finding.md` (the breakdown for leadership).

## Schema

The implemented schema names the producer table `titles` and the junction
`title_genres`, rather than `movies` and `movie_genres`, because the table
holds both films and series, distinguished by `content_type`.

| Table | Role | What it holds |
|---|---|---|
| `users` | actor | Registered accounts, each with a unique username and email |
| `titles` | producer | Films and series in one table, distinguished by `content_type` |
| `genres` | catalog | The controlled list of genres, arranged as a hierarchy of parents and subgenres |
| `title_genres` | junction | Which titles belong to which genres (many-to-many) |
| `ratings` | event | One star rating per user per title, with an optional written review |

Tables are created in dependency order: `users`, `genres`, `titles`,
`title_genres`, `ratings`. The diagram is in `schema/erd.png`
(source: `schema/erd.drawio`).

### Design decisions worth noticing

- **Films and series share one table.** `content_type` distinguishes them.
  `runtime_min` is nullable because series have no single runtime, and
  `chk_titles_film_has_runtime` restores the rule that every film has one.
- **One rating per user per title.** `ratings` uses a surrogate key, and
  `uq_ratings_user_title` enforces the uniqueness a composite key would have
  given, so no user can rate a title twice and skew its average.
- **Scores are whole stars.** `score` is `SMALLINT` bounded to 1–5 by
  `chk_ratings_score`, not the fractional `NUMERIC(3,2)`.
- **Average scores are not stored.** They are computed at query time with
  `AVG(score)`, so they are never stale after a new rating or a deleted
  account.
- **Genres form a hierarchy.** `parent_genre_id` is a recursive foreign key
  (Romantic Comedy → Comedy). Deleting a parent sets its subgenres' parent to
  null rather than deleting them.
- **Deletes are deliberate, not uniform.** Removing a user or a title
  cascades to the ratings and genre links that depend on it, but deleting a
  genre still attached to any title is refused (`RESTRICT`), so
  classification is never lost silently. The reasoning for every choice is
  in `analysis/unit2.md`.
- **Every constraint is named** with a `pk_`, `uq_`, `chk_` or `fk_` prefix,
  so an error message identifies the rule that was broken.

## Screenshots

### Unit 2

| File | Shows |
|---|---|
| `screenshots/First_run.pdf` | First run of `schema/schema.sql` via `psql`: the reset block drops any existing tables, then all five tables are created in dependency order |
| `screenshots/Second_run.pdf` | Second consecutive run with no manual cleanup; identical output, showing the script is re-runnable |
| `screenshots/Table_list.pdf` | `\dt` listing all five tables, confirming the schema was created |

### Unit 3

| File | Shows |
|---|---|
| `screenshots/3_1a_available_movies.pdf` | 3.1a: available movies released after 2015 |
| `screenshots/3_1b_distinct_statuses.pdf` | 3.1b: the distinct rating statuses and their counts |
| `screenshots/3_1c_score_range.pdf` | 3.1c: ratings scoring 4.0–5.0 (BETWEEN) |
| `screenshots/3_1c_status_in_list.pdf` | 3.1c: withdrawn and flagged ratings (IN) |
| `screenshots/3_1d_like_titles.pdf` | 3.1d: titles matched with LIKE |
| `screenshots/3_1d_null_coalesce.pdf` | 3.1d: NULL withdrawal reasons, labelled with COALESCE |
| `screenshots/3_1e_score_labels.pdf` | 3.1e: CASE labels for non-SQL readers |
| `screenshots/3_2a_counts_dont_sum.pdf` | A3: the two filters fail to cover all 200 rows |
| `screenshots/3_2a_repaired.pdf` | A4: the repaired not-spam count |
| `screenshots/3_2a_reviewer_impact.pdf` | A5: broken vs repaired credit per reviewer |
| `screenshots/3_2b_alias_error.pdf` | B1: the alias-in-WHERE error |
| `screenshots/3_2b_rewrite_repeat.pdf` | B2: rewrite by repeating the expression |
| `screenshots/3_2b_rewrite_cte.pdf` | B3: rewrite with a CTE |
| `screenshots/3_3_form1_not_in.pdf` | Form 1: NOT IN subquery |
| `screenshots/3_3_form2_cte.pdf` | Form 2: CTE with LEFT JOIN |
| `screenshots/3_3_form3_except.pdf` | Form 3: EXCEPT |
| `screenshots/3_3_identity_proof.pdf` | C1: proof the three forms return identical rows |
| `screenshots/3_3_null_breaks_not_in.pdf` | C2: a NULL makes NOT IN return nothing |

### Unit 4

| File | Shows |
|---|---|
| `screenshots/4_1_q1_q2_baseline_per_movie.pdf` | `q4_1.sql` Q1 baseline, the Q1 placeholder check, and Q2 per-movie counts and averages |
| `screenshots/4_1_q3_having.pdf` | `q4_1.sql` Q3: movies with 10+ ratings (HAVING) and their failure rates |
| `screenshots/4_1_q4_region_movie.pdf` | `q4_1.sql` Q4: all 62 region × movie rows |
| `screenshots/4_2_a_b_conditional_aggregation_rollup.pdf` | `q4_2.sql` Part A (one-pass totals and failures per movie) and Part B (ROLLUP: five `Regional subtotal` rows, then the `GRAND TOTAL` row) |
| `screenshots/4_2_c1_baseline.pdf` | `q4_2.sql` Part C1: the 16.5% high-volume baseline |
| `screenshots/4_2_c2_vs_baseline.pdf` | `q4_2.sql` Part C2: each high-volume movie compared with the baseline |
