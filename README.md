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
- `/queries` — one subfolder per unit (`unit3`–`unit6`) holding that assignment's `.sql` files
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

| File | Shows |
|---|---|
| `screenshots/01-first-run.png` | First run of `schema/schema.sql` via `psql`: the reset block drops any existing tables, then all five tables are created in dependency order |
| `screenshots/02-second-run.png` | Second consecutive run with no manual cleanup; identical output, showing the script is re-runnable |
| `screenshots/03-table-list.png` | `\dt` listing all five tables, confirming the schema was created |
