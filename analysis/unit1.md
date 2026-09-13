## Modelling justification
The decision with the largest effect on the rest of the design was how to hold
films and series. At first I was thinking of having two separate tables, but a
single `titles` relation with a `content_type` discriminator turned out to be
much easier to handle. Two tables would have meant two junctions and a
`ratings` relation with nowhere single to point, since a foreign key targets
one table. The cost of the single table is that `runtime_min` must be nullable,
because series have no runtime, which loses the guarantee that every film
carries one. I recovered that with `ck_titles_film_has_runtime`, a check that
allows a null runtime only when `content_type` is `series`. A smaller
assumption sits alongside it: a rating is a whole number of stars from one to
five rather than a partial-star scale.

For primary keys I chose a surrogate id on `users`, `titles` and `genres`
rather than a natural attribute such as a name, because names can repeat and
change. Two films can share a title across different release years, and a user
can change their username at any time. A distinct id stays fixed while those
descriptive attributes move, which means foreign keys pointing at it never have
to change either. `title_genres` is the exception: its primary key is the
composite `(title_id, genre_id)`, because that pair is the entire fact being
recorded and both values are already stable, so a surrogate would add a column
doing no work. `ratings` uses a surrogate, with a unique constraint on
`(user_id, title_id)` preserving the one-rating-per-title rule that a composite
key would otherwise have enforced.

The delete behaviours differ by how visible the damage would be. Removing a
title is routine, and the ratings and genre links attached to it describe
nothing once it is gone, so both cascade. Genres are the opposite case:
cascading a genre deletion would silently strip classification from every title
carrying it, and that loss would be invisible to whoever performed the delete,
so `title_genres` restricts on the genre side. The same relation therefore
cascades toward `titles` and restricts toward `genres`, which is deliberate.
The hardest choice was `ratings.user_id`, which cascades. Deleting an account
destroys that user's rating history and shifts the average score of every title
they rated, but ratings are personal data attached to an account, and
restricting would make account deletion impossible for anyone who had ever
rated anything.

For schema versus application, the rule I applied is that constraints defining
what the data *means* belong in the schema, while constraints about external
validity belong in the application. `content_type` is closed to `film` and
`series` because an unrecognised value would leave the row's meaning undefined,
and `score` is checked between one and five because `TINYINT` alone would
accept values the platform has no interpretation for. These are hard stops I
needed in place now rather than later. Email format is the contrast: the schema
guarantees an address is present and unique, but it cannot know whether one is
deliverable, so validation stays in the application.


## Reflection

A choice another designer could reasonably have made differently is the rating
scale. I chose whole stars from one to five, stored as a `TINYINT` and
constrained by a range check. Half stars were the obvious alternative, and the
decision changes how the platform's data looks at every level.

The write pattern favours whole stars. `ratings` is the highest-volume relation
in the design, since every user interaction adds a row, and a one-byte integer
with a simple range check is the cheapest thing to insert. Half stars would
mean a wider `DECIMAL(2,1)` column and a check that has to accept 2.5 while
rejecting 2.3, which is more expensive to validate on every write.

The read pattern is the stronger argument. The heaviest query the platform will
face is averaging scores per title, and integers aggregate exactly where
decimals force a rounding decision at every aggregation. A five-point scale
also makes a star distribution a clean grouping over five buckets rather than
ten, which is what a title page needs to display.

The cost is real, though. Five buckets are coarse, so a user who thinks a film
sits between three and four stars has nowhere to put that, and ratings cluster
around the middle. That makes titles harder to separate at the top of a
leaderboard, which is exactly where the platform most needs to tell them apart.
Half stars would have bought that resolution at the price of a heavier write
path and messier aggregates.
