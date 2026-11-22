# Unit 6: Analytics with Window Functions

**Theme:** 2 — Movie / TV
**Database:** `ex603_data` (the provided `movies.sql`)
**Queries:** `queries/unit6/q6_1.sql`, `queries/unit6/q6_2.sql`, `queries/unit6/q6_3.sql`

## Roles and definitions

The roles are the same as in every earlier unit: actor `users`, producer
`movies`, event `ratings`, catalog `genres`, junction `movie_genres`, metric
`score`.

These definitions carry over from Units 4 and 5:

- **Failure** is a rating with `rating_status = 'withdrawn'`.
- **Withdrawn ratings carry a 0.5 placeholder score**, not a real one. Every
  score average in this unit leaves them out, using
  `AVG(score) FILTER (WHERE rating_status <> 'withdrawn')`. The withdrawn rows
  themselves stay in the output wherever the task asks for every event.
- **Producer reports start from the full catalog** (`movies LEFT JOIN ratings`),
  so movies 14 and 15, which have no ratings, show as 0 instead of
  disappearing (the Unit 5 recommendation).

---

## Task 6.1: Compute across a window without collapsing

### Q1: Each rating next to its movie's average

`AVG(score) OVER (PARTITION BY movie_id)` puts each movie's average score on
every one of its ratings. The result has **200 rows**, one per rating, each
carrying its own score, the movie's average and the difference between them.

The GROUP BY version calculates exactly the same averages (movie 5 is 4.11,
movie 3 is 2.76, and so on) but returns **13 rows**, one per movie that has
ratings. What it loses is everything about the individual rating: its score,
who gave it, when, and its status. A GROUP BY result can tell you that
movie 8 averages 3.41. It cannot tell you that rating 123 gave movie 8 a 0.8,
2.61 points below that average, because rating 123 is no longer a row.

| | Window (`OVER PARTITION BY`) | `GROUP BY` |
|---|---|---|
| Rows returned | **200** | **13** |
| Individual score, user, date, status | Kept | Lost |
| Movie average | On every row | One row per movie |
| Can ask "is this rating unusual?" | Yes | No |

The plan (`EXPLAIN ANALYZE`, screenshot in `/screenshots/`) shows how
PostgreSQL does it, read from the bottom up:

```
WindowAgg (actual rows=200.00 loops=1)
  Window: w1 AS (PARTITION BY movie_id)
  Storage: Memory  Maximum Storage: 18kB
  ->  Sort (actual rows=200.00 loops=1)
        Sort Key: movie_id
        Sort Method: quicksort  Memory: 35kB
        ->  Seq Scan on ratings r (actual rows=200.00 loops=1)
```

1. A **Seq Scan** reads all 200 ratings. There is no `WHERE` clause and no
   index on `ratings.movie_id`, so reading the whole table is the only option.
2. A **Sort** on `movie_id`, the `PARTITION BY` key, done in memory with a
   quicksort (35 kB). The window has to see each movie's ratings next to each
   other, and nothing delivers them in that order already.
3. A **WindowAgg** walks the sorted rows one partition at a time (`w1`), keeps
   the current movie's rows in memory (18 kB at most), computes the average,
   and writes it onto every row. It returns **200 rows, the same number it
   reads**. A GROUP BY plan would end in an aggregate node returning 13.

An index on `ratings.movie_id` would let a larger table skip the sort step.

**What the window revealed.** The follow-up query keeps only ratings at least
2 points away from their movie's average. There are **16**, and **14 of them
are unusually low**. Grouping every remaining rating by how far it sits from
its movie's average shows what those low ratings have in common:

| Position vs. movie average | Ratings | Avg. watch minutes | Range |
|---|---|---|---|
| 2+ points below | 14 | **3.5** | 1.5 – 9.3 |
| Within 2 points | 150 | 15.5 | 3.0 – 27.8 |
| 2+ points above | 2 | 25.4 | 23.7 – 27.2 |

The unusually low ratings come from people who watched about **3.5 minutes on
average**, less than a quarter of the normal 15.5. Every one of them was under
10 minutes. None of them was withdrawn (13 are published, 1 is still under
review), so they currently count toward each movie's score. This suggests a different quality problem
from the withdrawals in Units 4 and 5: ratings that are not removed, but come
from viewers who barely started the movie.

### Q2: Ranking movies three ways

| Movie | Ratings | ROW_NUMBER | RANK | DENSE_RANK |
|---|---|---|---|---|
| 6 | 21 | 1 | 1 | 1 |
| 8 | 20 | 2 | 2 | 2 |
| 10 | 19 | 3 | 3 | 3 |
| **5** | **18** | **4** | **4** | **4** |
| **7** | **18** | **5** | **4** | **4** |
| 12 | 17 | 6 | **6** | **5** |
| 2 | 16 | 7 | 7 | 6 |
| 11 | 16 | 8 | 7 | 6 |
| 9 | 14 | 9 | 9 | 7 |
| 3 | 13 | 10 | 10 | 8 |
| 13 | 11 | 11 | 11 | 9 |
| 1 | 11 | 12 | 11 | 9 |
| 4 | 6 | 13 | 13 | 10 |
| 14 | 0 | 14 | 14 | 11 |
| 15 | 0 | 15 | 14 | 11 |

There are four ties: 5 and 7 (18 ratings), 2 and 11 (16), 1 and 13 (11), and
14 and 15 (0). All three functions use the same `ORDER BY`, so every
difference between the columns comes only from how each one handles ties:

- **ROW_NUMBER** never ties. It gave movie 5 fourth place and movie 7 fifth,
  with nothing in the data to justify it. It also put movie 13 above movie 1,
  out of `movie_id` order, which shows the tie-break is arbitrary: PostgreSQL
  does not promise the same order next time.
- **RANK** gives tied movies the same place, then skips. Movies 5 and 7 are
  both 4th, and movie 12 is **6th**, because five movies are ahead of it.
- **DENSE_RANK** gives tied movies the same place without skipping. Movie 12
  is **5th**, because there are four distinct counts above it.

The difference changes who makes a "top 5" list. `RANK <= 5` returns five
movies (6, 8, 10, 5, 7). `DENSE_RANK <= 5` returns six, adding movie 12.
`ROW_NUMBER <= 5` returns five, but would drop movie 7 instead of movie 5 if
the arbitrary tie-break went the other way.

### Q3: Four activity bands with NTILE(4)

`NTILE(4)` dealt the 15 movies into bands of 4, 4, 4 and 3 by row position:

| Band | Movies (ratings) |
|---|---|
| 1 | 6 (21), 8 (20), 10 (19), **5 (18)** |
| 2 | **7 (18)**, 12 (17), 2 (16), 11 (16) |
| 3 | 9 (14), 3 (13), 13 (11), 1 (11) |
| 4 | 4 (6), 14 (0), 15 (0) |

**Movies 5 and 7 both have 18 ratings, but 5 is in band 1 and 7 is in band 2.**
The check query confirms this is the only tie split across a boundary. NTILE
counts rows, not values: the fourth slot of band 1 had to go to one of the two,
and the choice between them is as arbitrary as ROW_NUMBER's. If bands drove a
decision, such as which titles get featured, two equally rated movies would be
treated differently for no reason in the data. Either the boundary has to be
moved to a value (for example, "18 or more ratings"), or the band report must
say that ties at a boundary were split.

### Write-up questions

**1. Write a question that needs each row shown next to its group's average.
Explain why the group average alone (GROUP BY) cannot answer it.**

*"Which individual ratings are far below the average for the movie they were
given to, and what do those ratings have in common?"*

Answering it needs two things on the same row: one rating's own score (and its
watch time, user and date), and the average of all the ratings for that movie.
GROUP BY can produce the second only by collapsing the first: once the ratings
are grouped by movie, the individual ratings are gone, and there is nothing
left to compare against the average. You could work around it by grouping in a
subquery and joining the result back to `ratings`, but that is two passes over
the table to rebuild what one window function returns directly.

The answer was worth having. The 14 unusually low ratings came from people who
watched 3.5 minutes on average, against 15.5 for everyone else. A movie's
average alone could not have shown that; it only shows that a movie's average
is lower than another's.

**2. Name a platform feature that would use your ranking, and explain which of
the three functions it should use and why.**

**A public "Most rated this year" chart** on the home page, showing each title's
position.

It should use **RANK**. Movies 5 and 7 each received 18 ratings. Showing one at
#4 and the other at #5, as ROW_NUMBER does, publishes a difference that does
not exist, and in a chart the studios and viewers both see, that is unfair to
whichever title loses the coin toss. RANK shows both at #4, and the jump to #6
for movie 12 is honest: five titles really are ahead of it. DENSE_RANK would
show movie 12 at #5, which reads as "four titles ahead" when there are five,
and lets a "top 5" chart quietly grow to six titles.

ROW_NUMBER does have a place: a **home-page carousel with exactly five fixed
slots**, where some title must take the fifth slot. Even then it must be given a
stated, defensible tie-break in the `ORDER BY` (for example, the lower failure
rate, or the more recent rating), so the same title wins every time and the
reason can be explained. A ranking that silently decides a tie is still a
decision, just one nobody made on purpose.

---

## Task 6.2: Compare each row to its neighbors

### Part A: Movie 11, rating to rating

Movie 11 is followed here because it had the highest failure rate in Units 4
and 5 (5 of 16 ratings withdrawn). `LAG` and `LEAD` run over every movie,
partitioned by `movie_id` and ordered by `rated_at`. The outer query then keeps
movie 11. Withdrawn ratings are removed before the window runs, so each step
goes from one real score to the next and never lands on a 0.5 placeholder.

| Rating | Date | Days since prev. | Watched (min) | Prev. | Score | Next | Delta |
|---|---|---|---|---|---|---|---|
| 169 | 8 Jan | | 19.8 | | 3.2 | 5.0 | |
| 164 | 9 Feb | 32 | 23.7 | 3.2 | 5.0 | 2.2 | +1.8 |
| 167 | 15 Feb | 6 | 10.1 | 5.0 | 2.2 | 2.3 | **−2.8** |
| 170 | 24 Feb | 9 | 12.5 | 2.2 | 2.3 | 3.7 | +0.1 |
| 172 | 24 Feb | 0 | 11.8 | 2.3 | 3.7 | 2.5 | +1.4 |
| 160 | 10 Jul | **136** | 13.3 | 3.7 | 2.5 | 1.4 | −1.2 |
| 161 | 17 Aug | 38 | 5.7 | 2.5 | 1.4 | 1.0 | −1.1 |
| 159 | 23 Aug | 6 | 4.4 | 1.4 | 1.0 | 3.3 | −0.4 |
| 158 | 14 Oct | 52 | 17.8 | 1.0 | 3.3 | 3.5 | **+2.3** |
| 166 | 17 Oct | 3 | 16.2 | 3.3 | 3.5 | 2.9 | +0.2 |
| 157 | 11 Nov | 25 | 11.3 | 3.5 | 2.9 | | −0.6 |

**The trend.** Movie 11's scores slide from February to August: three drops in
a row take it from 3.7 to 1.0. Then they recover to around 3 from October.
The two lowest scores in that slide (1.4 and 1.0) came from viewers who watched
about 5 minutes. The recovery came from viewers who watched 16 to 18 minutes.

**Is movie 11 unusual?** The supporting query summarises every movie's deltas.
Movie 11 is one of the *steadiest* movies on score. Its average swing between
consecutive ratings is 1.19 points, the second lowest of 13 movies, and it has
no drop of 3 points or more. Movie 6 swings 2.32 on average. So movie 11's
problem is what happens to its ratings (withdrawals), not the scores
themselves.

Across the platform, 13 consecutive drops were 3 points or more, and **12 of
the 13 came from a viewer who watched under 10 minutes**. This is the same
pattern Task 6.1 found from a different angle. The sharpest falls in a movie's
score usually come from people who barely watched it.

### Part B: Running total and moving average

Every rating is one row, ordered by `rated_at`. `is_withdrawn` is 1 for a
failure and 0 otherwise, so a running `SUM` counts failures so far, and an
`AVG` over a frame is the failure rate inside that frame.

**Month-end snapshot** (the last row of each month from the full series):

| Month end | Ratings so far | Withdrawn so far | Running failure rate | Last 20 ratings |
|---|---|---|---|---|
| Jan | 21 | 5 | 23.8% | 20.0% |
| Feb | 42 | 9 | 21.4% | 15.0% |
| Mar | 53 | 12 | 22.6% | 20.0% |
| Apr | 64 | 12 | 18.8% | 10.0% |
| May | 81 | 14 | 17.3% | 10.0% |
| Jun | 101 | 19 | 18.8% | **25.0%** |
| Jul | 118 | 21 | 17.8% | 15.0% |
| Aug | 136 | 24 | 17.6% | 20.0% |
| Sep | 152 | 27 | 17.8% | 15.0% |
| Oct | 170 | 29 | 17.1% | 15.0% |
| Nov | 184 | 31 | 16.8% | 10.0% |
| Dec | 200 | 34 | **17.0%** | 15.0% |

**Where things stand and how they got there.** The year started badly: 12 of
the first 53 ratings (22.6%) were withdrawn by the end of March. From April the
running rate falls and then levels off near 17%. The moving rate over the
last 20 ratings shows what the running rate smooths away. It moves between 10%
and 25%, with one bad stretch in June (5 of the last 20 withdrawn). By
quarter, the failure rate was 22.6% in Q1 and then 14.6%, 15.7% and 14.6%.

**The target.** I set a target of **46 kept ratings** (not withdrawn) for Q4
2023. That is 10% above the Q1–Q3 average of 41.7 (41, 41 and 43). The
running total, restarted each quarter with `PARTITION BY` quarter, reached
**41 by 28 December: 89.1% of the target, 5 short**. Q4 received 48 ratings in
total, and the 7 withdrawn ones are more than the shortfall. Had Q4 lost
ratings at the 10% rate of the best 20-rating stretches, instead of 14.6%,
it would have kept about 43.

**ROWS versus RANGE.** With `ROWS`, the frame ends at the current row, so two
rows with the same `ORDER BY` value get different running totals, in an order
PostgreSQL picks. With `RANGE`, the frame includes all of the current row's
peers, so every tied row gets the same total, the one for the end of the
group. Ordered by date, the three ratings on 8 January get 4, 5 and 6 with
`ROWS` and 6, 6 and 6 with `RANGE` (query B4).

### Part C: Where the series stops

The gap query uses `LAG(rated_at)` per movie in a CTE, a second CTE adds each
movie's average gap as a window, and the outer `WHERE` keeps gaps of 60 days or
more. That filter cannot go in the first query, because `WHERE` runs before
the window is computed.

Movie 11 has two gaps, depending on what is counted:

| Counting | Silent from | To | Days | Times its usual gap |
|---|---|---|---|---|
| **All ratings** | 7 Mar | 4 Jun | **89** | 4.3× |
| **Ratings that stayed visible** | 24 Feb | 10 Jul | **136** | the longest of any movie |

The 136-day gap is not empty. Four ratings arrived inside it, and **all four
were withdrawn**: 165 (policy violation, 4 Mar), 163 (spam, 7 Mar), 162 (user
request, 4 Jun) and 168 (user request, 10 Jun). From a viewer's side, movie 11
received no new visible rating for four and a half months.

**Did the platform lose the data during the 89 days?** No. During that window
the rest of the platform recorded **40 ratings on 11 different movies**, at
13.5 ratings per 30 days against 17.4 for the rest of the year. That is a
little slower than average, but nowhere near the silence a broken feed would
cause. Long silences are also normal for a title rated about once every three
weeks: movies 9, 12 and 5 each had a longer one (113, 107 and 93 days, also 4
to 5 times their usual gap).

### Write-up questions

**1. What would a large delta tell someone about your platform, and what should
they do about it?**

A large delta means one rating landed far from the one before it, for example
movie 11 falling from 5.0 to 2.2. On its own it says little: across all
movies, drops of 3 points or more happen 13 times in a year. What matters is *who*
gave the second rating. 12 of the 13 big drops came from viewers who watched
under 10 minutes. A large drop is therefore usually a sign of a rating from
someone who barely started the movie, not of a movie getting worse.

What to do: a large drop should send the rating to a check of its watch time
before it moves the movie's public average. Ratings under a minimum watch time
could be held, shown separately, or given less weight (`ratings.weight`
already exists for this). Product analytics, not moderation, should own the
rule, because these ratings are not abusive, only uninformed.

**2. Why does a running total answer a question that a plain SUM cannot?**

A plain `SUM` gives one number for the whole period: 34 withdrawals in 2023.
A running total gives that number *as it stood at every point in the year*,
which answers "were we on track?" and "when did it change?". The Q4 target is
the clearest case. `SUM` says Q4 kept 41 ratings and missed 46. The running
total shows the gap at every point: at 6.5% of target after the first four
days of October, 56.5% by 22 November, and only reaching 89% at the very end.
A manager watching it in November would have known the target was out of reach
in time to act, which a year-end `SUM` can never tell them.

**3. Why did you pick your moving-average window size? A different size tells
a different story.**

I used **20 ratings**, which is about one month of activity (200 ratings a
year, about 17 a month). At the platform's 17% failure rate, 20 ratings hold 3
or 4 failures, so a single rating moves the rate by 5 points.

The 7-row window, shown beside it, tells a noisier story. One withdrawal moves
it by 14 points, so once it has 7 ratings it ranges from 0% to 57% over the year and looks like a
crisis every few weeks. The running rate (all rows so far) goes the other way: by
December it is so anchored by the earlier ratings that June's bad stretch
barely moves it (17.3% to 18.8%), while the 20-row window shows it plainly
(10% to 25%). Twenty is the shortest window that does not react to single
ratings. Also, `ROWS` counts ratings, not days: in a quiet stretch, 20 ratings
can span six weeks.

**4. What does a gap mean in your platform: a data quality problem, a real stop
in activity, or a side effect of how events were recorded?**

Movie 11 shows two of the three, and they need different responses.

- **The 89-day silence (7 March to 4 June) is a real stop in activity, not a
  data problem.** The platform kept recording during it: 40 ratings on 11 other
  movies. Three other movies had silences as long or longer. For a title rated
  about every three weeks, a quiet spell like this is normal variation. The
  response is to watch it, not fix it. What the data cannot rule out is that
  the movie was hard to reach or unplayable for a while, because viewing is
  only recorded when someone rates.
- **The 136-day gap in visible ratings is a side effect of how ratings are
  recorded and moderated.** Ratings did arrive, but every one was withdrawn,
  so the movie page showed nothing new from February to July. Two of the four
  were withdrawn at the user's own request, and two by moderation (policy and
  spam). This is the one that needs a response. Trust & Safety should check
  whether the two moderation removals were correct, as already recommended in
  Unit 5. Product should ask why two viewers withdrew their own ratings within
  a week of each other in June.

---

## Task 6.3: Build the reporting patterns

### Part A: Top 3 ratings per movie

`ROW_NUMBER()` partitioned by `movie_id` numbers each movie's published
ratings from best to worst. A CTE then keeps slots 1 to 3. The result is
**39 rows: exactly three for each of the 13 rated movies.** Movies 14 and 15
have no ratings, so there is nothing to feature (Unit 5).

Only **published** ratings are eligible. Withdrawn ratings were removed, and
flagged ones are still under review, so neither belongs on a public page.

**How ties at third place are handled.** Ties are not rare here. Five movies
have more ratings tied at or above third place than there are slots. Movie 5
has six published 5.0 ratings, and movie 10 has six. `RANK() <= 3` would
return four to six "top three" reviews for those movies. I used `ROW_NUMBER`
so every page gets exactly three, and broke the ties with a stated rule
instead of leaving them to chance:

1. **score**, highest first;
2. **watch_minutes**, longest first. Tasks 6.1 and 6.2 showed that ratings from
   viewers who watched under 10 minutes are the least reliable, so among equal
   scores, the viewer who watched most has earned the slot;
3. **rated_at**, newest first;
4. **rating_id**, so the order can never change between runs.

`RANK` is shown beside `ROW_NUMBER` so the ties stay visible. Query A2 lists
the **10 ratings** that tied for a top-three score but lost the slot. In
all 10, the reason is watch time. For movie 12, rating 177 (4.5,
13.1 minutes watched) loses third place to rating 173 (4.5, 26.2 minutes).
For movie 10, ratings 153 and 154 tie on both score (5.0) and watch time
(27.32 minutes), so the third step, the date, decides between slots 1
and 2: 153 is newer and takes slot 1.

**FIRST_VALUE and LAST_VALUE.** `FIRST_VALUE(rating_id)` puts each movie's #1
review (its featured review) on all three rows. `LAST_VALUE(score)` gives the
movie's **lowest** published score. It only does that because the frame is
widened to `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`. Query
A3 shows what happens without it, on movie 11. With an `ORDER BY`, the default
frame stops at the current row, so the "last value" is just each row's own
score (5.0, 3.7, 3.5 ...). The full frame returns 1.0 on every row, the
movie's real lowest score.

The lowest score is there for a reason. Movie 11's featured review is a 5.0
(rating 164), on a movie whose published ratings average 2.82 and go as low as
1.0. Three top reviews on their own would oversell it.

### Part B: Month over month

Ratings are grouped by `DATE_TRUNC('month', rated_at)`, and each month is
compared with the one before using `LAG`.

| Month | Ratings | Change | Withdrawn | Change | Failure rate | Change (pp) | Avg. score |
|---|---|---|---|---|---|---|---|
| Jan | 21 | | 5 | | 23.8% | | 3.08 |
| Feb | 21 | 0.0% | 4 | −20.0% | 19.0% | −4.8 | 4.02 |
| Mar | 11 | −47.6% | 3 | −25.0% | **27.3%** | +8.2 | 2.83 |
| Apr | 11 | 0.0% | **0** | −100.0% | 0.0% | −27.3 | 3.47 |
| May | 17 | +54.5% | 2 | **(none)** | 11.8% | +11.8 | 3.20 |
| Jun | 20 | +17.6% | 5 | +150.0% | **25.0%** | +13.2 | 3.21 |
| Jul | 17 | −15.0% | 2 | −60.0% | 11.8% | −13.2 | 3.25 |
| Aug | 18 | +5.9% | 3 | +50.0% | 16.7% | +4.9 | 3.22 |
| Sep | 16 | −11.1% | 3 | 0.0% | 18.8% | +2.1 | 4.20 |
| Oct | 18 | +12.5% | 2 | −33.3% | 11.1% | −7.6 | 3.14 |
| Nov | 14 | −22.2% | 2 | 0.0% | 14.3% | +3.2 | 2.93 |
| Dec | 16 | +14.3% | 3 | +50.0% | 18.8% | +4.5 | 3.13 |

**Division by zero is real here.** April had no withdrawals, so May's percent
change in withdrawals divides by zero. `NULLIF(prev_withdrawn, 0)` turns the
divisor into NULL, and the result is NULL ("no base to compare") instead of an
error or a misleading number.

**Percent change on small counts misleads.** Withdrawals go −100% in April and
+150% in June. Those are real changes from 3 to 0 and from 2 to 5, but at 11
to 21 ratings a month, one withdrawal moves the monthly failure rate by 5 to
9 points. The failure rate's change in **percentage points** is the more
honest comparison, and it is what the write-up below uses.

**Missing months.** The monthly series is built from a calendar
(`generate_series`, January to December) left-joined to the ratings, so a month
with no ratings would appear as zeros instead of disappearing.
`months_since_prev` checks that `LAG` really compared consecutive months: it
is 1 on every row. The platform as a whole has ratings in all 12 months, so
the check finds nothing missing.

Movie 11 shows why the check matters (query B2). It has no ratings in April,
May, September or December. Run `LAG` over only the months that have data,
and June is compared with **March** and October with **August**: two wrong
comparisons out of eight. Filling the calendar first compares June with May
(0 ratings) and October with September (0), which is the truth.

**What the months say.** Two months stand out: **March (27.3%)** and **June
(25.0%)**. Together they hold 8 withdrawals, and **4 of the 8 are movie 11**.
That is the same movie flagged in Units 4 and 5. Outside those months, only
January (23.8%) comes close; the other nine stay between 0% and 19%.

### Write-up questions

**1. Name the feature in your platform that top-N would power. Explain why three
is the right number, rather than one or ten.**

**"Top reviews" on each movie page**: three review cards under the title,
before the full list.

- **One is too few.** A single review is one person's opinion, and it is often
  an outlier. Movie 11's best review is a 5.0 on a movie averaging 2.82. One
  card would present that as the movie's verdict. Three show a spread (5.0,
  3.7, 3.5 for movie 11) and let readers see whether reviewers agree.
- **Ten is too many.** Ten is not a summary any more. It is the review list.
  Most movies here have 11 to 21 ratings, so ten would be most of them. For a
  thinly rated movie it would mean showing weak reviews to fill slots (movie 4
  has only 4 published ratings, and its third best is a 2.4).
- **Three fits the screen and the data.** It is a row of cards on a phone
  without scrolling, and every rated movie can fill it. Ties do decide who gets
  in, which is why the tie-break rule is part of the feature, not an
  afterthought.

**2. What would a large month-over-month change mean in your domain, and what
should someone do about it?**

A large rise in the monthly **failure rate** means more ratings than usual are
being removed. In this platform that has meant one of three things, each with a
different owner: a spam or abuse wave (Trust & Safety), a moderation rule
applied more strictly in one place (Trust & Safety plus policy), or one title
attracting trouble (catalog and moderation together).

But at this volume, a single month's change is mostly noise. One withdrawal
moves a month by 5 to 9 points. April's 0% did not mean the problem was solved,
and June's +13.2 points did not mean it was getting worse. So the rule should
be about what someone does when it happens, not just about the number:

- **Trigger:** a month at **25% or more** (the level of March and June), or two
  months in a row above the 17% annual rate.
- **First action, same week:** break that month's withdrawals down by movie,
  reason and region (the Unit 4 queries). Both trigger months in 2023 would
  have pointed at movie 11 straight away (4 of the 8 withdrawals).
- **Then:** if one title or region dominates, hand it to Trust & Safety with
  the list of ratings. If nothing dominates, record it as noise and check the
  20-rating moving rate from Task 6.2 before reacting again.

A large drop deserves the same check. A sudden fall to 0% may mean moderation
stopped working, not that users improved.

---

## Reflection: what a window function can do that GROUP BY cannot

A reporting question from this project: **"How long did each movie go between
visible ratings, and which silence was the longest?"** Answering it showed
that movie 11 went 136 days, from February to July, without a rating that
stayed on the page.

With a window function this is one step. `LAG(rated_at) OVER (PARTITION BY
movie_id ORDER BY rated_at)` puts each rating's previous rating on the same
row. The gap is a subtraction, and an outer query keeps the long ones.

GROUP BY cannot do it, because the question is about the relationship between
neighbouring rows, and GROUP BY destroys the rows. Grouping by movie returns
one row per movie: a count, a first date, a last date. Those show that movie
11 was rated from January to November, but nothing about what happened in
between. There is no aggregate for "the difference from the previous row".
The only workaround is a self-join or correlated subquery that finds, for every
rating, the latest earlier rating of the same movie (`MAX(rated_at) WHERE
rated_at < this one`). That is harder to read, easy to get wrong on ties, and
reads the table again for every row.

The same is true of the running total, the moving failure rate and the
comparison with last month. Each needs a value from other rows placed next to
the current one. A window keeps the detail and adds the context; GROUP BY keeps
only the context.
