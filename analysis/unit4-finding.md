# Unit 4 Finding: The True Failure Rate

**To:** Leadership team
**From:** Auyon Haque
**Re:** Actual rating failure rate, and which movies to investigate

In this report, a "failure" is a rating that was withdrawn from the platform.
Ratings still under review are not counted.

## The true failure rate is 17%

Of the 200 ratings on the platform, 34 were withdrawn: a failure rate of
**17.0%**, roughly one rating in six. The five regions' totals add up exactly
to this figure, so no ratings are missing from the count.

One correction comes with it. Every withdrawn rating is stored with a
placeholder score of 0.5, and those placeholders have been counted as real
scores. They pull the platform's average score down from 3.33 to 2.85. Any
report of average scores should leave withdrawn ratings out.

## It varies widely across movies

Among the 12 movies with enough ratings to judge (10 or more), the failure rate
runs from **0%** (movie 10, none of 19 ratings withdrawn) to **31%** (movie 11,
5 of 16 withdrawn). A typical movie loses about **16.5%** of its ratings, so
that is the normal level to compare against. Movie 4 shows a 33% rate, but it
has only 6 ratings, so one or two withdrawals swing it too far to read anything
into.

The rate also differs by region: 27.5% of ratings made from India were
withdrawn, against 10.0% from the UK.

## The three movies I would investigate

| Movie | Ratings | Withdrawn | Failure rate | Compared with normal |
|---|---|---|---|---|
| **11** | 16 | 5 | 31.3% | 1.9 times |
| **9** | 14 | 4 | 28.6% | 1.7 times |
| **2** | 16 | 4 | 25.0% | 1.5 times |

Each has at least half again as many withdrawals as a normal movie, and each
for a different apparent reason:

- **Movie 11** has the highest rate, and 4 of its 5 withdrawals came from
  ratings made in India. That points to a regional cause, either a local spam
  source or moderation rules being applied more strictly there. It also accounts
  for a large part of India's high regional rate.
- **Movie 9** has its withdrawals spread across three regions and several
  reasons, with only one for spam. The question here is whether its ratings
  are being removed for a common cause, such as unclear policy, or for
  unrelated ones.
- **Movie 2** has 3 spam removals, the most of any movie, from three different
  accounts. Several separate accounts posting spam on one title looks like a
  coordinated target rather than one bad actor.

## Recommended next steps

1. Ask the moderation team to review the withdrawn ratings for movies 11, 9 and
   2, starting with movie 2's spam accounts.
2. Check how withdrawals are handled for ratings made from India.
3. Remove the 0.5 placeholder from average-score reporting, so score averages
   are based only on ratings that remain on the platform.

These figures come from a small sample of 200 ratings, so a movie's rate can
move noticeably with each new rating. They show where to look first, not a
final verdict on any title.
