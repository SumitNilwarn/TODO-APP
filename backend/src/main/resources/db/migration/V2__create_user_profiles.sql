-- =============================================================================
-- V2: user_profiles — optional profile data, one row per user.
-- =============================================================================
-- Design notes:
--   * user_id        : owning side of the 1:1 User <-> UserProfile. The UNIQUE
--                      constraint enforces "one profile per user" and doubles as
--                      the lookup index for profile reads (user_id is always the
--                      query key).
--   * FK behavior    : ON DELETE CASCADE — when a user row is removed (no
--                      deletion feature yet), its profile goes with it, so no
--                      orphaned profile can exist. Deleting a profile has no
--                      effect on the user.
--   * profile_image_url : a reference (URL/path) to externally managed image
--                      storage, never a BLOB.
--   * timezone        : nullable IANA time zone name (e.g. "Asia/Kolkata").
--                      Nullable because it is not known until the user sets it;
--                      application logic falls back to UTC until then. Business
--                      use of the zone arrives with the profile feature.
--   * firstName/lastName : names.

-- Unique on user_id; no separate non-unique index is needed.
-- =============================================================================

CREATE TABLE user_profiles (
    id                UUID        PRIMARY KEY,
    user_id           UUID        NOT NULL,
    first_name        VARCHAR(50),
    last_name         VARCHAR(50),
    display_name      VARCHAR(100),
    timezone          VARCHAR(64),
    profile_image_url VARCHAR(255),
    version           BIGINT      NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ NOT NULL,
    updated_at        TIMESTAMPTZ NOT NULL,

    CONSTRAINT uk_user_profiles_user UNIQUE (user_id),

    CONSTRAINT fk_user_profiles_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,

    CONSTRAINT ck_user_profiles_timestamps CHECK (updated_at >= created_at)
);