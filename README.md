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
