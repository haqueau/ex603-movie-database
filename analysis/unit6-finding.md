# Unit 6 Finding: Is the Platform Getting Better, and What Next Quarter Should Do

**To:** Leadership team
**From:** Auyon Haque
**Re:** The failure trend across 2023, and four actions for next quarter

Four weeks ago the question was whether a dashboard's failure rate could be
trusted. The corrected rate is 17%, one rating in six withdrawn (Unit 4). This
memo answers the last two questions: **is it getting better or worse, and
what should we do next?**

## The short answer

1. **Better early in the year, then flat.** The share of ratings withdrawn fell
   from 22.6% in the first quarter to about 15% and stayed there for the rest
   of the year. It has not improved since April.
2. **The bad months are concentrated.** March and June were the two worst
   months, and half of their withdrawals came from one movie, movie 11, the
   title already flagged in Units 4 and 5.
3. **A second problem sits outside the failure rate.** A third of the ratings we
   *keep* come from viewers who watched less than 10 minutes. They score
   movies far lower than everyone else, they pull the platform's average score
   down from 4.12 to 3.33, and their share was the highest of the year in the
   last quarter.

## 1. Is the failure problem getting better or worse?

**By quarter** (Q6.3, quarter-over-quarter query):

| Quarter | Ratings | Withdrawn | Failure rate | Change |
|---|---|---|---|---|
| Q1 2023 | 53 | 12 | **22.6%** | |
| Q2 2023 | 48 | 7 | 14.6% | −8.1 points |
| Q3 2023 | 51 | 8 | 15.7% | +1.1 points |
| Q4 2023 | 48 | 7 | 14.6% | −1.1 points |

The improvement happened once, between the first and second quarters, and has
held since. The running failure rate across the year confirms it. It was 22.6%
at the end of March, fell to 17.3% by the end of May, and then stayed between
16.8% and 18.8% until December, ending at 17.0% (Q6.2, month-end snapshot).

**By month, two months stand out** (Q6.3, month-over-month query): **March
(27.3%)** and **June (25.0%)**. Together they had 8 withdrawals, and **4 of the 8
were on movie 11** (2 for policy violation and spam in March, 2 at the user's
own request in June). Movie 11 also went 136 days, from 24 February to 10
July, without a single rating that stayed on its page. Every rating it
received in that time was withdrawn (Q6.2, gap query).

**One caution about monthly numbers.** The platform receives 11 to 21 ratings a
month, so a single withdrawal moves a month's failure rate by 5 to 9 points.
April's 0% did not mean the problem was solved. Quarterly figures and the
rolling rate over the last 20 ratings (Q6.2) are the ones to manage by.

**We missed the fourth-quarter target.** I set a target of 46 kept ratings for
Q4, 10% above the average of the first three quarters. Q4 kept 41, which is
89% of the target. The 7 ratings withdrawn in Q4 are more than the shortfall
of 5 (Q6.2, quarterly target query).

## 2. What the failure rate does not show

The failure rate only counts ratings we remove. Looking at each rating next to
its own movie's average (Q6.1) found a problem among the ratings we keep:

- **55 of the 166 kept ratings (33%) came from viewers who watched less than
  10 minutes.** They come from 25 different users, so this is how people use
  the product, not a few bad accounts.
- **They average 1.73 out of 5. Everyone else averages 4.12.** Including them
  lowers the platform average to 3.33 (Q6.1, short-watch impact query).
- **They cause almost all of the sharp drops.** Of the 14 ratings at least 2
  points below their movie's average, the viewers watched 3.5 minutes on
  average, against 15.5 minutes for normal ratings. Of the 13 times a movie's
  score fell 3 points or more from one rating to the next, 12 came from a
  viewer who watched under 10 minutes (Q6.1, Q6.2).
- **They hit some titles hard.** Movie 13's average is 3.05 with them and 4.80
  without them, and four other movies move by about a full point (Q6.1).
- **Their share rose in the last quarter**, to 43.9% of kept ratings, from
  23.3% in Q3 (Q6.3, quarter-over-quarter query). One quarter is not yet a
  trend, but it is the highest of the year.

This matters because the average score is what viewers see on every movie page
and what recommendations are built on. Right now a third of it comes from
people who barely started the movie.

## 3. What the team should do next quarter

| # | Action | Owner | Why | How we'll know it worked |
|---|---|---|---|---|
| 1 | **Finish the targeted moderation review, starting with movie 11.** Check whether its March removals (policy, spam) were correct. Find out why two viewers withdrew their own ratings within a week in June. Then continue with movies 9 and 2 as set out in Unit 5. | Trust & Safety | Movie 11 holds half the withdrawals in the two worst months, and went four and a half months with no visible rating. | Movie 11's failure rate back near the 16.5% normal for a movie; no month at 25% or more. |
| 2 | **Test a minimum-watch rule for ratings, without deleting anything.** For one quarter, calculate every movie's average both ways (all ratings, and ratings after 10+ minutes) and compare. Options to test: label short-watch ratings ("rated after 4 minutes"), hold them out of the public average, or give them less weight. The database already has a `weight` column for this. | Product, with Analytics | A third of kept ratings, a 0.79-point drag on the platform average, and 12 of 13 sharp drops. | A decision by the end of the quarter, based on both averages side by side and on whether viewers rate differently when the label is shown. |
| 3 | **Replace the dashboard's failure figure with a monthly health report** that cannot repeat the original mistake. It should cover every calendar month, including empty ones, so none disappears. It should show change in points, not percent, the rolling rate over the last 20 ratings, and the short-watch share. Agree in advance what triggers action: a month at 25% or more, or two months in a row above 17%. | Analytics | Monthly numbers swing 5 to 9 points on one rating, and percent changes on small counts read as −100% or +150%. | Every trigger leads to a breakdown by movie, reason and region within a week, and each is either acted on or recorded as noise. |
| 4 | **Close out the never-rated titles** (movies 14 and 15, Unit 5): tag their genres, confirm they can be played, then decide whether to keep licensing them. | Content / catalog | Still unrated across all of 2023. | Either rated within 90 days of tagging, or a licensing decision made. |

**Targets for next quarter:** a failure rate at or below 15%, no month at 25% or
more, and 46 kept ratings, the Q4 target we missed.

## Limits of this data

- **It is small and covers one year.** 200 ratings across 15 movies, all in
  2023. One rating changes a month by 5 to 9 points, so this memo leans on
  quarters and rolling rates. One year also cannot separate a seasonal pattern
  from a real trend. We will not know whether March and June are bad every
  year until we have a second year.
- **Watch time is not the same as interest.** Someone who stops after 4 minutes
  because they dislike the movie is giving honest feedback. The data cannot
  tell that viewer apart from someone rating carelessly, and it does not
  record how long each movie is, so "10 minutes" is a fixed threshold, not a
  share of the movie. That is why action 2 is a test, not a rule.
- **Viewing is only recorded when someone rates.** A quiet spell, like movie
  11's 89 days with no ratings, cannot be told apart from a period when the
  movie was hard to find or would not play. I checked that the platform kept
  recording other movies during that spell (40 ratings on 11 movies), so the
  data was not lost. Why viewers stayed away is a different question that the
  data cannot answer.
- **The withdrawal reason is one label.** It says *what* the moderator decided,
  not *why* that title attracted it. Action 1 has to answer that by reviewing
  the ratings themselves.

## Where each figure comes from

| Claim | Query |
|---|---|
| Quarterly failure rate; short-watch share by quarter | `queries/unit6/q6_3.sql`, Part B1 (supporting): quarter over quarter |
| Monthly failure rate, March and June, April's zero | `q6_3.sql`, Part B1: month over month |
| Running failure rate at each month end | `q6_2.sql`, Part B2 |
| Q4 target of 46 kept ratings, reached 41 | `q6_2.sql`, Part B3 |
| Movie 11's 136-day gap, the four withdrawals inside it, and the 89-day silence | `q6_2.sql`, Parts C1–C3 |
| 4 of 8 spike-month withdrawals on movie 11 | `q6_2.sql`, Part C2 (reasons and dates), against `q6_3.sql` Part B1 |
| Ratings 2+ points below their movie's average, and their watch time | `q6_1.sql`, Q1 follow-up and supporting query |
| 55 short-watch ratings, 1.73 vs 4.12, effect per movie | `q6_1.sql`, Q1 supporting: short-watch impact |
| 12 of 13 sharp score drops from short-watch viewers | `q6_2.sql`, Part A supporting |
| 16.5% normal failure rate for a movie; movies 9 and 2 | Unit 4 (`queries/unit4/`) |
| Movies 14 and 15 never rated | Unit 5 (`queries/unit5/q5_2.sql`) |
