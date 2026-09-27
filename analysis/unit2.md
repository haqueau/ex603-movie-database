# Unit 2 — Reasoning

**Theme:** 2 — Movie / TV  
**Task:** 2.2

`schema.sql` encodes each rule below; this document explains why each rule
has the form it does.

---

## What changed from the Unit 1 design

Implementing the design in PostgreSQL forced or prompted the changes below.
The ERD (`schema/erd.png`) has been updated to match.

| Change | Unit 1 | Unit 2 | Why |
|---|---|---|---|
| `ratings.score` type | `TINYINT` | `SMALLINT` | PostgreSQL has no `TINYINT`; the script failed until this changed. `SMALLINT` is the smallest integer type available, and `chk_ratings_score` still bounds it to 1–5. The course default for scores, `NUMERIC(3,2)`, was rejected because it admits fractions and this platform rates in whole stars. |
| `titles.runtime_min` type | `SMALLINT` | `INTEGER` | The course type mapping specifies `INTEGER` for durations. |
| `users.email` length | `VARCHAR(255)` | `VARCHAR(254)` | 254 characters is the real maximum length of an email address; 255 was an arbitrary default. |
| `genres.parent_genre_id` | absent | added, with `fk_genres_parent` and `chk_genres_no_self_parent` | The Unit 1 diagram had no recursive relationship. Genres form a natural hierarchy (Romantic Comedy under Comedy), making this the one relation in the theme where a self-reference models something real. |
| `CHECK` constraint names | `ck_` prefix | `chk_` prefix | Aligns with the course naming convention (`pk_`, `uq_`, `chk_`, `fk_`). |
| Defaults | none | `joined_at DEFAULT CURRENT_DATE`, `rated_at DEFAULT CURRENT_TIMESTAMP` | Both record when a row was created, so the database can supply them rather than every insert. |

No table, key or relationship from Unit 1 was removed.

---

## The constraints table

| Foreign key | `ON DELETE` | Reason |
|---|---|---|
| `fk_ratings_user` (`ratings.user_id → users`) | `CASCADE` | A rating is personal data belonging to an account, so it leaves with the account. |
| `fk_ratings_title` (`ratings.title_id → titles`) | `CASCADE` | A rating means nothing once the title it scores no longer exists. |
| `fk_title_genres_title` (`title_genres.title_id → titles`) | `CASCADE` | A link row exists only to classify its title, so it has no purpose after the title is gone. |
| `fk_title_genres_genre` (`title_genres.genre_id → genres`) | `RESTRICT` | Deleting a genre in use would silently strip classification from titles, so the delete is refused until the titles are reassigned. |
| `fk_genres_parent` (`genres.parent_genre_id → genres`) | `SET NULL` | Removing a parent genre should promote its subgenres to top level, not delete them. |

### `fk_ratings_user` — a user closes their account

**The event.** A user deletes their account, or an administrator removes it.

**What happens.** Every rating that user submitted is deleted with the
account. The user's scores and written reviews disappear from the platform.
Every title they rated is also affected: its average score is recalculated
without their rating the next time it is queried, and its rating count
drops. Because the average is computed at query time rather than stored,
nothing has to be updated by hand; the next `AVG(score)` is already correct.

**What would go wrong under the alternatives.** With `RESTRICT`, anyone who
had ever rated a title could never delete their account; the platform would
have to delete every rating first, or refuse the request outright, which is
not acceptable for personal data. `SET NULL` is not possible: `user_id` is
`NOT NULL`, and even if it were nullable, anonymous ratings would escape
`uq_ratings_user_title`, since a null user can't be matched against anyone.
It would also leave the departed user's reviews on the site without their
consent.

### `fk_ratings_title` — a title is removed from the catalog

**The event.** A film or series is taken off the platform, for example because
it was added in error, a duplicate was merged, or it lost its licence.

**What happens.** Every rating of that title is deleted. The users who rated
it lose that entry from their rating history, and their personal counts
drop. No other title's average changes.

**What would go wrong under the alternative.** With `RESTRICT`, any title that
had received even one rating could never be removed, so a duplicate entry
that users had already rated would be stuck in the catalog permanently. With
orphans retained instead (which `NOT NULL` already rules out), every
aggregate query would need an extra filter to exclude ratings whose title no
longer exists, and a forgotten filter would report averages for titles
nobody can see.

### `fk_title_genres_title` — a title is removed from the catalog

**The event.** The same title removal as above; this row governs its genre links.

**What happens.** The title's rows in `title_genres` are deleted. Each genre
it belonged to now covers one fewer title. The genres themselves are
untouched.

**What would go wrong under the alternative.** With `RESTRICT`, removing a
title would first require unlinking it from every genre by hand, which adds
work but protects nothing: a link row records only that *this* title is in
*that* genre, so once the title is gone there is nothing left to protect.
`CASCADE` removes rows that have no remaining meaning.

### `fk_title_genres_genre` — an administrator deletes a genre

**The event.** An administrator removes a genre from the controlled
vocabulary, for example retiring "Film Noir" or merging two overlapping
labels.

**What happens.** If any title is still classified under that genre, the
delete is refused with an error naming `fk_title_genres_genre`. The
administrator must first move those titles to another genre or unlink them,
then delete. Only an unused genre can be removed.

**What would go wrong under the alternative.** With `CASCADE`, the delete
would succeed and quietly remove the genre from every title carrying it.
A title that had only that one genre would become unclassified and vanish
from every genre browse page, and the administrator who ran the delete would
receive no warning that anything beyond the genre row had changed. This is
the opposite choice from `fk_title_genres_title` on purpose: removing a
title makes its links meaningless, but removing a genre discards information
that is still true about the titles.

### `fk_genres_parent` — a parent genre is deleted

**The event.** An administrator deletes a genre that has subgenres, for example
deleting "Comedy" while "Romantic Comedy" and "Dark Comedy" point at it.

**What happens.** The subgenres survive, and their `parent_genre_id` becomes
null, making them top-level genres. The titles classified under those
subgenres keep their classification. Note that `fk_title_genres_genre` still
applies first: if "Comedy" itself is attached to any title, the delete is
refused before `SET NULL` is ever reached.

**What would go wrong under the alternatives.** With `CASCADE`, deleting
"Comedy" would delete every subgenre beneath it, and every sub-subgenre
beneath those, removing a whole branch of the catalog in one statement; in
practice the `RESTRICT` on `title_genres` would usually block this, but any
unused subgenre in the branch would vanish silently. With `RESTRICT`, a
parent could not be retired until every child had been re-parented by hand,
even when promoting them to top level is exactly what the administrator
wants.

---

## The CHECK constraints

### `chk_titles_content_type` — `content_type IN ('film', 'series')`

**The state it makes unstorable:** a title whose type is neither film nor
series, and whose meaning is therefore undefined. `chk_titles_film_has_runtime`
depends on the type, and the rule that series have no runtime depends on it
too.

**How it could otherwise arise:** an import from a source that uses its own
vocabulary (`'movie'`, `'tv'`, `'TV Series'`), or inconsistent capitalisation
from a form (`'Film'`). `VARCHAR(10)` accepts all of these. Without the check,
a query filtering `WHERE content_type = 'film'` would silently miss every
row stored as `'movie'`.

### `chk_titles_release_year` — `release_year BETWEEN 1888 AND 2100`

**The state it makes unstorable:** a release year that could not be real,
either before the earliest surviving film or implausibly far in the future.

**How it could otherwise arise:** data-entry errors that `SMALLINT` happily
stores: a two-digit year (`99` instead of `1999`), an extra keystroke
(`20015`), or a placeholder `0` for "unknown". Each of these would corrupt
any sort or filter by decade.

### `chk_titles_runtime_positive` — `runtime_min IS NULL OR runtime_min > 0`

**The state it makes unstorable:** a title with a runtime of zero or fewer
minutes.

**How it could otherwise arise:** an import that writes `0` to mean "unknown",
or a sign error in a conversion from seconds or hours. The `IS NULL` branch
is needed so the check does not reject series, whose runtime is null by
design.

### `chk_titles_film_has_runtime` — `content_type = 'series' OR runtime_min IS NOT NULL`

**The state it makes unstorable:** a film with no runtime.

**How it could otherwise arise:** `runtime_min` has to be nullable because
series share the table, so the column definition alone cannot require a value
for films. A film could be inserted with the runtime left blank, or a
series could be re-labelled as a film by an `UPDATE` that changes only
`content_type` and leaves `runtime_min` null. This check restores, at row
level, the rule the nullable column had to give up.

### `chk_genres_no_self_parent` — `parent_genre_id IS DISTINCT FROM genre_id`

**The state it makes unstorable:** a genre that is its own parent, which
would make any query walking up the hierarchy loop forever.

**How it could otherwise arise:** an administrator editing a genre selects
the genre itself in a "parent" dropdown, or an `UPDATE` uses the wrong id.
`IS DISTINCT FROM` is used instead of `<>` because `<>` returns null when
`parent_genre_id` is null, and a check that evaluates to null passes; using
`IS DISTINCT FROM` makes the intent explicit for top-level genres. A
limitation: the check only catches a genre pointing directly at itself.
A longer cycle (A → B → A) spans two rows, and a `CHECK` can see only one
row, so preventing that would need a trigger.

### `chk_ratings_score` — `score BETWEEN 1 AND 5`

**The state it makes unstorable:** a rating outside the platform's one-to-five
star scale.

**How it could otherwise arise:** `SMALLINT` accepts anything from −32,768 to
32,767. A client might send `0` to mean "not rated", an import from a
ten-point site might bring in `8`, or a bug might send a negative number.
A single score of `50` would drag a title's average far out of range, so
the check protects every average computed from this table.
