# Integrity Constraints

**Theme:** 2 — Movie / TV  
**Unit:** 1, Task 1.3

This document covers the keys, checks, and referential
actions that make invalid data impossible to store.

---

## Keys and checks

### `users`

| Constraint | Definition | Justification |
|---|---|---|
| `pk_users` | `PRIMARY KEY (user_id)` | Stable surrogate identifier. |
| `uq_users_username` | `UNIQUE (username)` | The handle is how users identify each other. Without this the surrogate key would permit two accounts with the same public name. |
| `uq_users_email` | `UNIQUE (email)` | Prevents one person holding several accounts under one login address, which would distort per-user rating counts. |

### `titles`

| Constraint | Definition | Justification |
|---|---|---|
| `pk_titles` | `PRIMARY KEY (title_id)` | Titles are not uniquely identified by name; distinct works share names across years. |
| `ck_titles_content_type` | `CHECK (content_type IN ('film', 'series'))` | The discriminator drives how the row is interpreted. An unrecognised value would leave the row's meaning undefined, so the set is closed in the schema. |
| `ck_titles_release_year` | `CHECK (release_year BETWEEN 1888 AND 2100)` | 1888 is the earliest surviving film. The upper bound permits announced future releases while rejecting data-entry errors. |
| `ck_titles_runtime_positive` | `CHECK (runtime_min IS NULL OR runtime_min > 0)` | Zero or negative is not a possible duration. |
| `ck_titles_film_has_runtime` | `CHECK (content_type = 'series' OR runtime_min IS NOT NULL)` | `runtime_min` is nullable only because series share the relation. This restores the rule that every film carries a runtime. |

### `genres`

| Constraint | Definition | Justification |
|---|---|---|
| `pk_genres` | `PRIMARY KEY (genre_id)` | Surrogate key, consistent with the other relations. |
| `uq_genres_name` | `UNIQUE (name)` | A controlled vocabulary is only useful if each label appears once. Duplicate rows would silently split a genre's titles across two identifiers. |

### `title_genres`

| Constraint | Definition | Justification |
|---|---|---|
| `pk_title_genres` | `PRIMARY KEY (title_id, genre_id)` | The pair is the fact being recorded. Using it as the key makes a duplicate classification structurally impossible, with no extra unique constraint required. |

### `ratings`

| Constraint | Definition | Justification |
|---|---|---|
| `pk_ratings` | `PRIMARY KEY (rating_id)` | Surrogate key; see `schema-definition.md` for why the composite alternative was not used. |
| `uq_ratings_user_title` | `UNIQUE (user_id, title_id)` | Enforces one rating per user per title — the rule the composite primary key would have provided, preserved so the surrogate key does not weaken the design. Without it one user could rate a title repeatedly and skew its average. |
| `ck_ratings_score` | `CHECK (score BETWEEN 1 AND 5)` | The platform defines a rating as a whole number of stars from one to five. `TINYINT` alone permits values far outside that range. |

---

## Foreign keys and `ON DELETE` behaviour

| Constraint | Definition | `ON DELETE` | Justification |
|---|---|---|---|
| `fk_ratings_user` | `ratings.user_id → users.user_id` | `CASCADE` | A rating is personal data attached to an account, so deleting the account must remove it. The cost is accepted: removing a user changes the average score of every title they rated. `RESTRICT` would make account deletion impossible for anyone who had ever rated anything. `SET NULL` is unavailable because `user_id` is `NOT NULL`, and an anonymous rating could no longer be governed by `uq_ratings_user_title`. |
| `fk_ratings_title` | `ratings.title_id → titles.title_id` | `CASCADE` | A rating has no meaning without the title it refers to. Retaining orphaned ratings would force every aggregate query to exclude them by hand. |
| `fk_title_genres_title` | `title_genres.title_id → titles.title_id` | `CASCADE` | A link row exists only to classify a title. Once the title is gone the row classifies nothing. |
| `fk_title_genres_genre` | `title_genres.genre_id → genres.genre_id` | `RESTRICT` | Deliberately different from the row above. Deleting a genre still in use would silently strip classification from every title carrying it, and that loss would be invisible to whoever performed the delete. `RESTRICT` forces an administrator to reassign or unlink the affected titles first. Genres are a small, slow-changing catalog, so the inconvenience is rare. |

