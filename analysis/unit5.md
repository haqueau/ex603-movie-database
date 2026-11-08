# Unit 5: Connecting the Tables

**Theme:** 2 — Movie / TV
**Database:** `ex603_data` (the provided `movies.sql`)
**Queries:** `queries/unit5/q5_1.sql`, `queries/unit5/q5_2.sql`, `queries/unit5/q5_3.sql`

## Roles and definitions

The appendix fixes the roles for this theme: actor `users`, producer `movies`,
event `ratings`, catalog `genres`, junction `movie_genres`, metric `score`.

The definitions from Unit 4 carry over unchanged:

- **Failure** is a rating with `rating_status = 'withdrawn'`.
- **The Assignment 4 movies** are 11, 9 and 2, the three movies whose failure
  rate was at least 1.5 times the 16.5% baseline (31.3%, 28.6% and 25.0%).

---

## Task 5.1: Connect producers to their data

### What the queries showed

**Q1, the three-table join.** `ratings` sits in the middle: each rating points
to one user and one movie, so two inner joins attach a reviewer name and a
movie title to every rating. The result has 200 rows, the same as the ratings
table. No rating was lost, because the foreign keys guarantee that every
rating has a real user and a real movie to match.

**Q2, the junction traversal.** The catalog holds five genres: Drama, Sci-Fi,
Comedy, Thriller and Documentary. I chose **Comedy** as the tag to test, because
two of the three Assignment 4 movies carry it (11 and 2). Drama also covers two
of them (9 and 2), but 9 of the 12 tagged movies are Drama, so sharing it says
almost nothing.

Five movies are tagged Comedy: 2, 3, 5, 10 and 11. Comedy's failure rate is
18.3%, the second highest after Documentary (23.1%). Thriller is lowest at
11.8%. So the tag lines up with the problem, but it does not explain it on its
own: movie 10 is also Comedy and has no withdrawals at all, and movie 5 sits at
16.7%, almost exactly the baseline. A movie with several genres counts in each
of them, so these genre rates overlap and should not be added together.

One gap showed up: movies 13, 14 and 15 have no genre at all. Any report that
groups by genre leaves them out silently.

**Q3, the self join.** The `movies` table is joined to itself to pair each
Assignment 4 movie with every other movie that shares its origin country or
release year. If a shared trait explained the failures, the look-alikes would
fail just as often. They don't:

| Flagged movie | Failure rate | Closest look-alike | Its failure rate |
|---|---|---|---|
| 11 (Brazil, 2017) | 31.3% | 12 (Brazil, 2017) | 11.8% |
| 9 (US, 2014) | 28.6% | 8 (UK, 2014) / 13 (US, 2016) | 5.0% / 9.1% |
| 2 (Vietnam, 2023) | 25.0% | 6 (Vietnam, 2008) | 19.0% |

Movie 11 and movie 12 share both a country and a year, and are both tagged
Documentary, yet movie 11 fails almost three times as often. Origin and age
do not account for the difference.

Activity level does not explain it either. The three flagged movies have 16,
14 and 16 ratings, in the middle of the range (6 to 21). They are not failing
because they are thinly rated.

One characteristic does set movie 9 apart: it is the only flagged movie that is
no longer available (`is_available = FALSE`). The data cannot say whether the
withdrawals contributed to it being pulled, or whether being pulled changed how
its ratings were handled. That needs a conversation with the catalog team.

### What the data shows and what it doesn't

The joins show **who** and **what**: which reviewers, which genres, which
look-alike movies. They do not show **why**. The reasons recorded in Unit 4
(spam on movie 2, a regional pattern on movie 11) remain the strongest leads,
and the joins rule out the easy explanations: country, release year and volume.

### Write-up questions

**1. What feature or report on the platform could use the three-table join from
Question 1? What information would it display?**

A **moderation review queue** for the Trust & Safety team. Each row would show
the reviewer's name, the movie's title, when the rating was made, and its
current status. Sorted by time and filtered to withdrawn or flagged ratings, it
lets a moderator see at a glance whether one account keeps appearing across
several movies, or whether one movie keeps attracting different accounts. That
is exactly the question Unit 4 left open about movie 2's three spam removals.
The same join powers a user-facing "recent reviews" panel on each movie page,
showing who rated it and when.

**2. Why is the junction table important for answering Question 2? What would
make this analysis more difficult without it?**

A movie can have several genres and a genre covers many movies, so neither table
can hold the link on its own. `movie_genres` stores one row per movie–genre
pair, and that is the only place the relationship exists. Joining through it is
what lets the query ask "which movies are Comedy?" and get movie 2 back even
though it is also Drama and Thriller.

Without it, the genres would have to live on the movie row: either a single
`genre` column, which forces each movie into one genre and would have hidden
that movie 2 is Comedy at all, or a comma-separated list such as
`'Comedy, Drama, Thriller'`, which can only be searched with `LIKE`, cannot be
checked against the `genres` table by a foreign key, and allows misspellings
that quietly split one genre into two. Counting failures per genre, as in the
supporting Q2 query, would become string parsing instead of a join.

---

## Task 5.2: Find records that joins may exclude

### Part A: INNER JOIN versus LEFT JOIN

Both queries count ratings per movie. The only difference is the join.

| | LEFT JOIN | INNER JOIN |
|---|---|---|
| Rows returned by the join | 202 | 200 |
| Distinct movies | **15** | **13** |
| Movies excluded | | **2** (movies 14 and 15) |

The row counts alone are misleading. 202 against 200 looks like a difference of
two ratings, but it is a difference of two whole movies. Counting
`DISTINCT movie_id`, as the hint says, shows what actually changed: every movie
with a rating is in both results, and the two movies with no ratings appear
only in the left join, with a count of 0.

**Which producers are missing and why.** Movies 14 and 15 are missing because an
inner join keeps a movie only when at least one rating matches it, and nothing
in `ratings` points at either of them. A left join keeps every row from
`movies` whether or not anything matches, and fills the ratings side with
NULLs. `COUNT(r.rating_id)` skips those NULLs, which is why they show 0 rather
than 1.

### Part B: RIGHT JOIN and FULL OUTER JOIN

**RIGHT JOIN.** `ratings RIGHT JOIN movies` keeps every movie, the same as
`movies LEFT JOIN ratings`: a right join is a left join with the tables written
in the other order. I checked that rather than assuming it. Both joins return
202 rows, and subtracting one result from the other with `EXCEPT`, in both
directions and at the level of individual ratings, leaves **0 rows** each way.
They are identical.

**FULL OUTER JOIN.** This also returns 202 rows: 200 matched ratings and 2
unmatched movies (14 and 15). It found **no** ratings without a movie.

That is not luck. The foreign key `fk_ratings_prod` refuses any rating whose
`movie_id` does not exist in `movies`, so on this database the right-hand side
of a full outer join can never produce an unmatched row. Here the full outer
join gives the same answer as the left join, and I would not have known that
without running it.

**What a full outer join can reveal that a left or right join alone cannot.**
A left join shows only one kind of gap: movies with no ratings. A right join
shows only the other: ratings with no movie. A full outer join shows both in
one result, and labels which side each gap is on. That matters wherever the
link is not enforced: ratings loaded from an app's event log before the movie
record was created, a movie deleted with its ratings left behind, or two
systems being reconciled (for example, the catalog against a partner's list of
licensed titles). A left join from the catalog would never show the orphan
ratings, and a right join would never show the unrated movies.

### Part C: NOT EXISTS versus EXCEPT

Both approaches return the same two movies, 14 and 15, and subtracting one
result from the other in both directions leaves 0 rows. They differ in how they
work: `NOT EXISTS` checks each movie row for a matching rating, so it can return
any column of the movie (country, year, date added), while `EXCEPT` subtracts
one list of IDs from another, so it can only return the column the two lists
share, `movie_id`, and needs a further join to say anything else about them.

### Write-up questions

**1. Which producers were excluded by the inner join? Report their identifiers.**

Two movies: **movie 14** (Title_14) and **movie 15** (Title_15).

**2. What does it mean when a producer has no events? What are some possible
explanations?**

It means no user has rated the movie: not a single published, flagged or
withdrawn rating exists for it. It does **not** necessarily mean nobody watched
it. Viewing is recorded only on a rating row (`watch_minutes`), so a movie that
was watched but never rated looks exactly the same as one nobody opened.

What the data shows about the two movies:

| | Movie 14 | Movie 15 |
|---|---|---|
| Available | Yes | Yes |
| Added to catalog | 21 Feb 2022 | 11 Apr 2022 |
| Origin, release year | India, 2013 | UK, 2008 |
| Genre tags | **None** | **None** |

Both were available for the whole of 2023, the year every rating in the data
was made. So they are not new arrivals, and they were not withdrawn from the
catalog.

Possible explanations, and how far the data supports each:

- **They are hard to find.** Neither has a genre tag, so neither appears on any
  genre page or in genre-based recommendations. The data supports this as a
  lead but not as the whole answer: movie 13 has no genre either, and still
  received 11 ratings.
- **They are older titles.** This does not hold up. Movies 6 and 7 are also from
  2008 and received 21 and 18 ratings.
- **They are available in the catalog but not actually playable**, for example
  restricted by region or licence. Nothing in this database records that, so it
  needs checking with the content team.
- **People watch them but do not rate them.** The database cannot tell, because
  it has no record of viewing separate from rating.

**3. How could a report based only on an inner join give leadership an incomplete
picture of the platform?**

An inner-join report counts only movies that have activity, so it reports
13 movies when the catalog holds 15. Every per-movie figure built on it, such
as "the average movie gets 15.4 ratings" or "every title has been rated", is
calculated without the two titles that have none, and looks healthier than the
platform is. Worse, nothing in the report signals that anything is missing.
This is the same kind of silent omission as the Unit 3 dashboard error and the
missing-movie trap in the Unit 4 reflection: the query runs, the numbers are
correct for what they include, and the problem is what they leave out.

**4. Why might leadership want to identify producers that have never been
active?**

Because every title on the platform costs something to hold (licensing,
storage, catalog upkeep) and earns nothing if nobody engages with it. A title
with zero ratings after nearly two years is either a wasted cost or a
discovery problem, and both are fixable. They are also a different problem from
the Unit 4 movies: those have engagement that is being removed, while these
have no engagement at all, so they need a different owner and a different fix.

**5. What action could leadership take based on these findings?**

1. **Tag the untagged titles.** Assign genres to movies 13, 14 and 15. It is
   cheap, and it puts 14 and 15 on browse pages for the first time.
2. **Confirm they are actually playable.** Ask the content team whether 14 and
   15 can be streamed in every region where they appear as available.
3. **Re-check after a fixed period**, for example 90 days after tagging. If they
   are still unrated, review whether to keep licensing them.
4. **Build reports from the catalog outward.** Any report on movie performance
   should start from `movies` with a left join, so inactive titles show as 0
   instead of disappearing.

The data shows that these two movies have no ratings and no genres. It does not
show why nobody rated them; steps 1 and 2 are how to find out.

---

## Task 5.3: Join performance and execution plans

### Part A: CROSS JOIN

I crossed `genres` (5 rows) with `movies` (15 rows), both small enough to read in
full. A cross join has no join condition, so every genre is paired with every
movie.

| genres rows | movies rows | 5 × 15 | CROSS JOIN rows |
|---|---|---|---|
| 5 | 15 | 75 | **75** |

The result matches the multiplication exactly. The sample of the first 10 rows
shows why: movie 1 appears once with each of the 5 genres, then movie 2 does the
same, whether or not the movie is actually tagged with that genre.

**When a Cartesian product is useful.** Query A3 uses it on purpose. The cross
join builds all 75 *possible* movie–genre pairs, and a left join to
`movie_genres` then marks which of them really exist. Only 25 are tagged; 50 are
not. A normal join to `movie_genres` could only ever show the 25 that exist. To
find what is *missing*, you first need the full grid of what *could* exist, and
generating that grid is exactly what a cross join is for.

**When it indicates a query error.** A cross join written by accident is usually
a join with a missing or wrong `ON` condition, for example joining `ratings` to
`users` without `ON u.user_id = r.user_id`. That would pair every rating with
every user: 200 × 30 = 6,000 rows instead of 200, and every total built on it
would be inflated 30 times. The warning sign is a row count close to the product
of two table sizes. At platform scale it is also dangerous: a million ratings
crossed with 100,000 users is 100 billion rows.

### Part B: The execution plan

The query is the three-table join from Task 5.1 Q1 (`ratings`, `users`,
`movies`, sorted by `rated_at`). The full plan returned by `EXPLAIN`
(PostgreSQL on my machine; screenshot in `/screenshots/`):

```
 Sort  (cost=35.98..36.48 rows=200 width=549)
   Sort Key: r.rated_at, r.rating_id
   ->  Nested Loop  (cost=12.40..28.34 rows=200 width=549)
         ->  Hash Join  (cost=12.25..17.80 rows=200 width=291)
               Hash Cond: (r.user_id = u.user_id)
               ->  Seq Scan on ratings r  (cost=0.00..5.00 rows=200 width=33)
               ->  Hash  (cost=11.00..11.00 rows=100 width=262)
                     ->  Seq Scan on users u  (cost=0.00..11.00 rows=100 width=262)
         ->  Memoize  (cost=0.15..0.41 rows=1 width=262)
               Cache Key: r.movie_id
               Cache Mode: logical
               ->  Index Scan using movies_pkey on movies m  (cost=0.14..0.40 rows=1 width=262)
                     Index Cond: (movie_id = r.movie_id)
(13 rows)
```

My reading of it, from the bottom up:

```
Sort  (rows=200)                                        4. sort by rated_at, rating_id
  -> Nested Loop  (rows=200)                            3. attach the movie, one rating at a time
       -> Hash Join  (r.user_id = u.user_id)            2. attach the user
            -> Seq Scan on ratings r   (rows=200)       1. read every rating
            -> Hash
                 -> Seq Scan on users u  (est. 100, actual 30)
       -> Memoize  (Cache Key: r.movie_id)                 remember movies already looked up
            -> Index Scan using movies_pkey on movies m
                 Index Cond: (movie_id = r.movie_id)
```

1. PostgreSQL reads all of `users` and builds a hash table of it in memory, keyed
   on `user_id` (10 kB, one batch).
2. It reads every rating once and looks each one's `user_id` up in that hash
   table: a **Hash Join**.
3. For each of the 200 joined rows it then fetches the matching movie through the
   primary-key index `movies_pkey`: a **Nested Loop**. A **Memoize** node sits
   in front of the index and caches each movie once it has been fetched.
4. It sorts the 200 rows in memory (quicksort, 40 kB).

`EXPLAIN ANALYZE` shows what the cache achieved: **13 misses and 187 hits**. Only
13 distinct movies have ratings, so the index was searched just 13 times
(`Index Searches: 13`, `loops=13`), and the other 187 lookups were answered from
the cache. The whole query ran in 0.434 ms.

The estimates were not all correct. The planner expected 200 ratings and got 200,
but it expected **100 users and found 30**.

### Write-up questions

**1. Give an example of when a Cartesian product could be useful on your
platform, or explain why you would not need one.**

A **genre coverage grid** for the catalog team: every movie against every genre,
marked tagged or not tagged (query A3). It shows that 50 of the 75 possible
pairs are untagged and that movies 13, 14 and 15 have no genre at all, which is
how unrated movies 14 and 15 slip out of genre browsing (Task 5.2). The same
pattern would build a reporting calendar: every movie crossed with every month,
left-joined to ratings, so a month with no ratings shows as 0 instead of
disappearing from a trend chart.

**2. Which join algorithms did PostgreSQL choose for your query?**

Two different ones:

- a **Hash Join** to join `ratings` to `users` on `user_id`, built on sequential
  scans of both tables;
- a **Nested Loop** to join that result to `movies`, looking each movie up through
  the `movies_pkey` index, with a **Memoize** cache in front of the lookup.

The result is then sorted in memory with a quicksort.

**3. What information in the execution plan helps explain those choices?**

- **Row estimates, and where they came from.** The last query in q5_3.sql shows
  what the planner knew. `ratings` was analyzed by autovacuum (estimate: 200,
  correct). `users` and `movies` show `-1`: **they have never been analyzed**, so
  the planner had no row counts for them and fell back on a default guess. The
  plan shows the result: `Seq Scan on users ... rows=100`, against `rows=30`
  actually found.
- **Why a hash join for users.** Every rating needs its user, and there is no
  `WHERE` clause, so all of both tables is read anyway. Reading `users` once into
  a small hash table (`Batches: 1`, 10 kB) and probing it 200 times is cheaper
  than 200 separate index lookups.
- **Why a nested loop for movies.** `movies` has a primary-key index on exactly
  the join column (`Index Cond: (movie_id = r.movie_id)`), so each lookup is
  cheap, and the planner expected heavy repetition: 200 ratings pointing at only
  a handful of movies. Memoize turns that repetition into cache hits, which is
  why the planner judged index lookups plus a cache cheaper than hashing a table
  whose size it did not know.
- **The choice depends on the statistics.** I ran the same query on a copy of
  the database after `ANALYZE` had given the planner true row counts (30 users,
  15 movies). It then chose **two Hash Joins** with sequential scans, because a
  15-row table is cheaper to read once than to search 200 times. Same data, same
  query, different plan, purely because of what the planner knew.

**4. Why is it useful to understand the selected join algorithms?**

Because the algorithm decides how the query's cost grows. A hash join reads both
tables once, which is excellent when most rows are needed and poor when only a
few are. A nested loop is excellent for a handful of rows found through an index
and very poor when it has to scan a large table for each outer row. Knowing which
one a query uses tells you whether a slow report needs an index, a filter,
fresher statistics, or more memory, rather than guessing. It also exposes silent
problems: a plan that says "Nested Loop" with no join condition is a Cartesian
product, and wildly wrong row estimates mean the planner is choosing blind.

**5. What changes to the data or database might make another join algorithm more
appropriate?**

- **Filtering to a few rows plus an index on the foreign key.** A moderation page
  that shows one reviewer's ratings needs a handful of rows from a large table.
  With an index on `ratings.user_id`, a **Nested Loop** using that index becomes
  the right choice. I tested this on a temporary copy with 200,000 ratings: with
  no index the one-user query still had to scan the whole ratings table (cost
  about 4,800); with the index, it became a Nested Loop over a bitmap index scan
  (cost about 120), roughly 40 times cheaper.
- **Both sides already sorted on the join key.** If both inputs come from indexes
  ordered by the join column, or the query needs output in that order, a
  **Merge Join** can join them in one pass without building any hash table.
- **A build side too large for memory.** If `users` grew to tens of millions of
  rows, its hash table would no longer fit in `work_mem`; the hash join would
  spill to disk in several batches, and a merge join could win.
- **Running `ANALYZE`.** My own plan used a Nested Loop for `movies` because
  `movies` and `users` had never been analyzed. With statistics in place, the
  same query switched to two Hash Joins. Missing or stale statistics change the
  algorithm with no change to the data at all.

**Which part becomes less efficient as the dataset grows.** At 200,000 ratings
(same temporary test) the plan kept both hash joins, and the most expensive step
became the **sort**: its cost rose to about 30,000, against about 6,000 for both
joins together. Sorting every rating by `rated_at` grows faster than the joins
do, and once it no longer fits in memory it spills to disk. Because this query
returns every rating, the sequential scan of `ratings` also grows in direct
proportion to the table. In practice this report would need a filter (a date
range or one movie) and paging, and an index on `rated_at` would let PostgreSQL
read rows already in order instead of sorting them.

---

## Reflection: what would make PostgreSQL choose a different join algorithm?

My plan used a Hash Join for users and a Nested Loop with Memoize for movies,
and the reason was the planner's information, not the data. `users` and
`movies` had never been analyzed, so it guessed 100 users instead of 30. On a
copy with fresh statistics, the same query used two Hash Joins. Simply running
`ANALYZE` changes the algorithm.

The number of matching records matters too. Memoize paid off because 200
ratings pointed at only 13 movies: 187 of 200 lookups were cache hits. If most
ratings referred to different movies, the cache would rarely hit, and hashing
the whole table once would be cheaper.

Filters and indexes push the other way. One reviewer's ratings are a handful
of rows. On a test copy with 200,000 ratings, that query had to
scan the entire ratings table, because PostgreSQL does not index foreign keys
automatically. Adding an index on `ratings.user_id` produced a Nested Loop with
an index scan and cut the estimated cost from about 4,800 to 120.

Growth matters too. At 200,000 ratings the hash joins held, but the sort
became the most expensive step.
If a hash table outgrew memory, it would spill to disk, and a Merge Join over
inputs already sorted by an index could win.

No algorithm is best; the right one depends on how many rows are needed,
whether an index can find them, and how accurately the planner knows the data.
