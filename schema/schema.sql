-- ================================================================
-- EX 603 Assignment 2 - schema.sql
-- Theme:  2 - Movie / TV
-- Author: Auyon Haque
-- Target: PostgreSQL 14+
-- ================================================================
--
-- Creation order (Step 1)
-- Each table is listed with the tables it references (outgoing FKs).
--
--   1. users         -> (none)             actor
--   2. genres        -> genres (self)      catalog
--   3. titles        -> (none)             producer
--   4. title_genres  -> titles, genres     junction
--   5. ratings       -> users, titles      event
--
-- genres' only arrow points at itself, which PostgreSQL resolves
-- inside a single CREATE TABLE, so it still goes early.
-- Tables with no outgoing arrows go first; title_genres and ratings
-- come last because both depend on tables created above them.
-- ================================================================

-- Reset. Reverse creation order, so no dependency blocks a drop.

DROP TABLE IF EXISTS ratings       CASCADE;
DROP TABLE IF EXISTS title_genres  CASCADE;
DROP TABLE IF EXISTS titles        CASCADE;
DROP TABLE IF EXISTS genres        CASCADE;
DROP TABLE IF EXISTS users         CASCADE;

-- ----------------------------------------------------------------
-- 1. users - actor. First: it has no foreign keys, and ratings
--    points at it.
-- ----------------------------------------------------------------
CREATE TABLE users (
    user_id    INTEGER      GENERATED ALWAYS AS IDENTITY,
    username   VARCHAR(50)  NOT NULL,
    email      VARCHAR(254) NOT NULL,
    joined_at  DATE         NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT pk_users          PRIMARY KEY (user_id),
    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT uq_users_email    UNIQUE (email)
);

-- ----------------------------------------------------------------
-- 2. genres - catalog. Early: its only foreign key points at
--    itself, and title_genres points at it. parent_genre_id is the
--    recursive FK: a subgenre (e.g. Romantic Comedy) under its
--    parent (Comedy). Null for top-level genres.
-- ----------------------------------------------------------------
CREATE TABLE genres (
    genre_id         INTEGER     GENERATED ALWAYS AS IDENTITY,
    name             VARCHAR(50) NOT NULL,
    parent_genre_id  INTEGER,
    CONSTRAINT pk_genres      PRIMARY KEY (genre_id),
    CONSTRAINT uq_genres_name UNIQUE (name),
    CONSTRAINT fk_genres_parent
        FOREIGN KEY (parent_genre_id) REFERENCES genres (genre_id)
        ON DELETE SET NULL,
    CONSTRAINT chk_genres_no_self_parent
        CHECK (parent_genre_id IS DISTINCT FROM genre_id)
);

-- ----------------------------------------------------------------
-- 3. titles - producer. Early: it has no foreign keys, and both
--    title_genres and ratings point at it. Holds films and series,
--    distinguished by content_type.
-- ----------------------------------------------------------------
CREATE TABLE titles (
    title_id      INTEGER      GENERATED ALWAYS AS IDENTITY,
    name          VARCHAR(200) NOT NULL,
    content_type  VARCHAR(10)  NOT NULL,
    release_year  SMALLINT     NOT NULL,
    runtime_min   INTEGER,
    CONSTRAINT pk_titles PRIMARY KEY (title_id),
    CONSTRAINT chk_titles_content_type
        CHECK (content_type IN ('film', 'series')),
    CONSTRAINT chk_titles_release_year
        CHECK (release_year BETWEEN 1888 AND 2100),
    CONSTRAINT chk_titles_runtime_positive
        CHECK (runtime_min IS NULL OR runtime_min > 0),
    CONSTRAINT chk_titles_film_has_runtime
        CHECK (content_type = 'series' OR runtime_min IS NOT NULL)
);

-- ----------------------------------------------------------------
-- 4. title_genres - junction. After titles and genres, because it
--    references both. Resolves their M:N; the primary key is the
--    pair of foreign keys.
-- ----------------------------------------------------------------
CREATE TABLE title_genres (
    title_id  INTEGER NOT NULL,
    genre_id  INTEGER NOT NULL,
    CONSTRAINT pk_title_genres PRIMARY KEY (title_id, genre_id),
    CONSTRAINT fk_title_genres_title
        FOREIGN KEY (title_id) REFERENCES titles (title_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_title_genres_genre
        FOREIGN KEY (genre_id) REFERENCES genres (genre_id)
        ON DELETE RESTRICT
);

-- ----------------------------------------------------------------
-- 5. ratings - event. Last, because it references users and
--    titles. One rating per user per title; score is the metric.
-- ----------------------------------------------------------------
CREATE TABLE ratings (
    rating_id    INTEGER   GENERATED ALWAYS AS IDENTITY,
    user_id      INTEGER   NOT NULL,
    title_id     INTEGER   NOT NULL,
    score        SMALLINT  NOT NULL,
    rated_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    review_text  TEXT,
    CONSTRAINT pk_ratings            PRIMARY KEY (rating_id),
    CONSTRAINT uq_ratings_user_title UNIQUE (user_id, title_id),
    CONSTRAINT chk_ratings_score      CHECK (score BETWEEN 1 AND 5),
    CONSTRAINT fk_ratings_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_ratings_title
        FOREIGN KEY (title_id) REFERENCES titles (title_id)
        ON DELETE CASCADE
);