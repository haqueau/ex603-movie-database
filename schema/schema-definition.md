# Schema Definition

**Theme:** 2 — Movie / TV  
**Unit:** 1, Task 1.1

Five relations, one per role. The theme grid names the producer role `movies`
and the junction `movie_genres`; this design uses `titles` and `title_genres`
because the table holds both films and series, distinguished by
`content_type`. Roles map as follows.

| Role | Relation |
|---|---|
| actor | `users` |
| producer | `titles` |
| event | `ratings` |
| catalog | `genres` |
| junction | `title_genres` |
| metric | `score`, an attribute of `ratings` |

Domains are given in standard SQL types

---

## 1. `users` — actor

Registered accounts that rate titles.

| Attribute | Domain | Null | Description |
|---|---|---|---|
| `user_id` | `INTEGER` | No | Surrogate identifier, auto-generated |
| `username` | `VARCHAR(50)` | No | Public handle, unique platform-wide |
| `email` | `VARCHAR(255)` | No | Login address, unique platform-wide |
| `joined_at` | `DATE` | No | Date the account was created |

**Primary key:** `user_id`

---

## 2. `titles` — producer

Films and series available to rate. `content_type` distinguishes the two.

| Attribute | Domain | Null | Description |
|---|---|---|---|
| `title_id` | `INTEGER` | No | Surrogate identifier, auto-generated |
| `name` | `VARCHAR(200)` | No | Title as displayed |
| `content_type` | `VARCHAR(10)` | No | Either `film` or `series` |
| `release_year` | `SMALLINT` | No | Four-digit year of first release |
| `runtime_min` | `SMALLINT` | Yes | Length in minutes; null for series |

**Primary key:** `title_id`

---

## 3. `genres` — catalog

The controlled list of genres a title can belong to.

| Attribute | Domain | Null | Description |
|---|---|---|---|
| `genre_id` | `INTEGER` | No | Surrogate identifier, auto-generated |
| `name` | `VARCHAR(50)` | No | Genre label, unique across the catalog |

**Primary key:** `genre_id`

---

## 4. `title_genres` — junction

Resolves the many-to-many between `titles` and `genres`. A title sits in
several genres; a genre covers many titles.

| Attribute | Domain | Null | Description |
|---|---|---|---|
| `title_id` | `INTEGER` | No | References `titles(title_id)` |
| `genre_id` | `INTEGER` | No | References `genres(genre_id)` |

**Primary key:** `(title_id, genre_id)` — composite

---

## 5. `ratings` — event

One row per rating a user gives a title. `score` is the metric for this theme.

| Attribute | Domain | Null | Description |
|---|---|---|---|
| `rating_id` | `INTEGER` | No | Surrogate identifier, auto-generated |
| `user_id` | `INTEGER` | No | References `users(user_id)` |
| `title_id` | `INTEGER` | No | References `titles(title_id)` |
| `score` | `TINYINT` | No | Whole stars, 1 to 5 |
| `rated_at` | `TIMESTAMP` | No | When the rating was submitted |
| `review_text` | `TEXT` | Yes | Optional written review; a score alone is a valid rating |

**Primary key:** `rating_id`

---

