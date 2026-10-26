# Unit 4: From Rows to Insight

**Theme:** 2 — Movie / TV
**Database:** `ex603_data` (the provided `movies.sql`)
**Queries:** `queries/unit4/q4_1.sql`, `queries/unit4/q4_2.sql`

## Definitions used throughout

The appendix fixes the roles (actor `users`, producer `movies`, event `ratings`)
and the metric (`score`). It does not define "failure" or "region" for this
theme, so I set them and use them consistently in every query.

- **Failure** is a rating with `rating_status = 'withdrawn'`: a rating that was
  removed from the platform. Flagged ratings (10) are still under review, so
  they are not yet failures.
- **Region** is `ratings.device_country`, the country a rating was made from. It
  is the only geography on the event row itself. It is not the reviewer's home
  country: only 37 of the 200 ratings were made from the reviewer's own country.

---

## Task 4.1: Measure the platform

### What the queries showed

**Q1, the baseline.** There are 200 ratings from 30 reviewers across 13 of the
15 movies. The scores total 569.3, and the average is 2.85 on a 0–5 scale, with
a minimum of 0.5 and a maximum of 5.0.

The minimum is a data-quality problem, not a real opinion. Every one of the 34
withdrawn ratings scores exactly 0.5, and no other rating does. The 0.5 is a
placeholder written when a rating is removed. Because the placeholders sit in
the same column as real scores, they pull the platform average down from 3.33
to 2.85. This is the same kind of silent error as the Unit 3 bug: nothing fails,
and the number is simply wrong.

**Q2, per producer.** Activity is uneven. Movie 6 has 21 ratings, movie 4 has 6,
and movies 14 and 15 have none. With placeholders included, averages run from
2.09 (movie 11) to 3.51 (movie 5). With them removed, the range is 2.76 to 4.11.
Removing the placeholders changes some movies far more than others. Movie 2
gains 0.76 points, while movie 10, which has no withdrawals, does not move at
all. A movie's "average score" on the old basis partly measured how many of its
ratings were removed.

**Q3, the volume threshold.** I kept movies with at least 10 ratings. At 10
ratings, one withdrawal already moves the failure rate by 10 points, and below
that a single event dominates. The data also has a natural break: every rated
movie has 11 or more ratings except movie 4, which has 6. Movie 4's 33% failure
rate is the highest on the platform, but it rests on 2 ratings out of 6; one
more withdrawal would make it 50%. The threshold drops movie 4 and keeps 12.
Among those 12, failure rates run from 0% (movie 10) to 31.3% (movie 11).

**Q4, region by producer.** There are 62 region-and-movie combinations, one row
each. Most are too small to judge alone: 26 have fewer than 3 ratings, and the
largest has 8. Rates such as India / movie 1 at 66.7% rest on 2 withdrawals out
of 3 ratings. A regional leader should read this table to see where their
ratings come from, not to rank movies within a single country.

### Who acts on the per-producer breakdown

The **Trust & Safety (moderation) lead**. They own the withdrawal process, so a
movie whose ratings are withdrawn far more often than others tells them where
to look first: a title attracting spam campaigns, or a moderation rule being
applied unevenly.

### What the aggregates hide

**An average conceals its distribution.** The cleaned average of 3.33 suggests
that most reviewers feel lukewarm. They don't. Of the 166 real ratings, 67 score
between 4 and 5, the largest group by far, and 42 score below 2. The ratings are
split between people who liked a movie and people who did not, and 3.33 is the
midpoint of two groups rather than a typical rating. A movie can reach 3.3 either
way, which is why the per-movie average alone cannot say whether a title is
liked.

**A count conceals who is counted.** "34 withdrawn ratings" sounds like one
problem, but they come from 20 different reviewers with four different reasons:
Spam detected (12), Policy violation (8), Duplicate rating (7) and User request
(7). A user deleting their own rating is not a platform failure in the same
sense as spam. The count also hides who is missing: movies 14 and 15 have zero
ratings, and a query that starts from `ratings` instead of `movies` never shows
them at all.

### What I would need to see next

1. **Withdrawals by reason, per movie.** This separates spam and policy removals
   (a moderation problem) from user requests (a normal action). Movie 11's 5
   withdrawals include 2 user requests; movie 2's 4 include 3 spam removals.
2. **Withdrawals per reviewer, per movie.** This checks whether a movie's
   failures come from one account or many. Movie 2's three spam removals came
   from three different accounts, which looks more like a coordinated target
   than one bad actor.
3. **The score distribution per movie** (counts at each score band, not only the
   average), so a split movie and a mediocre movie can be told apart.
4. **Withdrawals over time** (by month from `rated_at`), to see whether a high
   rate is ongoing or a single past incident.

---

## Task 4.2: Build the breakdown leadership asked for

### Part A: Two numbers in one pass

One query, one scan of the ratings table, answers two questions for every movie
at the same time:

| Question 1 | Question 2 |
|---|---|
| How many ratings did this movie receive? | How many of those ratings were withdrawn? |
| `COUNT(*)` → `total_ratings` | `SUM(CASE WHEN rating_status = 'withdrawn' THEN 1 ELSE 0 END)` → `failed_ratings` |

Dividing the second by the first gives each movie's failure rate. The query
also counts spam withdrawals in the same pass, to show which failures are
spam rather than routine removals.

Across the platform, 34 of 200 ratings were withdrawn (17.0%). The outliers are
at the top of the result: movie 11 (5 of 16, 31.3%), movie 9 (4 of 14, 28.6%)
and movie 2 (4 of 16, 25.0%). Movie 2 stands out for a different reason too: 3 of
its 4 withdrawals were for spam, the most of any movie. Movie 4 tops the list at
33.3%, but on only 6 ratings, below the Task 4.1 threshold, so it is not a
reliable outlier.

### Part B: Subtotals and a grand total

**How to read the output.** The query returns six rows. The five rows labelled
`Regional subtotal` are one per region (Brazil, India, UK, US, Vietnam), each
totalling every rating made from that country. The last row, labelled
`GRAND TOTAL` with region `All regions`, totals all 200 ratings across every
region. The individual region-and-movie detail rows are removed.

**Who needs this.** The **regional director**. They manage the regions, not the
individual titles, so the 62 detail rows from Task 4.1 Q4 are noise for them;
they need one line per region they are responsible for.

**What the grand total supports that the group rows do not.** The grand total is
the platform-wide failure rate, 17.0%. That is the number leadership asked for,
and it supports platform-level decisions: whether withdrawals are a problem for
the whole business and need a platform-wide response (moderation staffing, a
policy change), rather than a fix in one region. It is also the yardstick each
region is judged against. India's 27.5% only means "high" relative to 17.0%, and
the UK's 10.0% only means "low" the same way. No single regional row can say
whether the platform overall is healthy. The grand total also checks the
subtotals: the regions add up to 200 ratings and 34 failures, so no ratings were
dropped, which is exactly the check that would have caught the Unit 3 dashboard
error.

### Part C: A two-step pipeline

**The question it answers:** *What failure rate is normal for a movie with
enough ratings to judge, and which movies are well above that normal?*

Step 1 summarises each movie (ratings and withdrawals). Step 2 keeps only the
movies with 10 or more ratings (the Task 4.1 threshold) and aggregates them a
second time to set the baseline: 32 withdrawals in 194 ratings, a **16.5%**
baseline. The final step compares each movie with it. Three movies are at
least 1.5 times the baseline, meaning half again as many withdrawals as a
normal movie: movie 11 (1.89×), movie 9 (1.73×) and movie 2 (1.52×). These are
the three I name in the finding.

The baseline is pooled (total withdrawals ÷ total ratings), so a movie with 21
ratings counts for more than a movie with 11. The simple average of the twelve
movies' rates is 17.0%, close enough that the choice does not change which
movies stand out.

---

## Reflection: one pass versus two filtered queries

Part A could have been written as two queries: one counting every rating per
movie, and a second with `WHERE rating_status = 'withdrawn'` counting the
failures. Both return correct numbers, but the database reads the ratings table
twice, and I would then have to join the two results on `movie_id` to put them
side by side. Conditional aggregation reads each row once and lets the CASE
expression decide which totals that row adds to, so every column is filled in
the same scan.

At 200 rows the difference is invisible. At a million rows it matters for three
reasons. First, reading the table is the expensive part of the query, so two
scans cost roughly twice as much as one, and every extra metric added as a
separate filtered query costs another full scan. Second, the two queries run at
different moments. On a live platform, ratings arrive and get withdrawn between
them, so the total and the failure count can describe slightly different data,
and a rate built from them is subtly wrong. One pass computes both from the same
rows. Third, the filtered version has to be joined back together, and a movie
with no failures vanishes from the filtered result. Unless the join is written
carefully, that movie drops out entirely, which is the same kind of silent
omission that broke the dashboard in Unit 3. In the single-pass version, movie
10 simply shows zero failures.
