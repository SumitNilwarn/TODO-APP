-- =============================================================================
-- V3: tasks — owned by exactly one user.
-- =============================================================================
-- Design notes:
--   * user_id     : required FK to users. ON DELETE CASCADE — removing a user
--                   removes their tasks (no deletion feature yet; documented for
--                   when it exists). Composite indexes below start with user_id,
--                   so they also serve as the FK lookup index.
--   * status      : persisted lifecycle states only (TODO, IN_PROGRESS,
--                   COMPLETED, CANCELLED). OVERDUE is NOT persisted — it is a
--                   derived state computed by application logic ("due date
--                   passed AND not completed AND not cancelled").
--   * completed_at: UTC instant. The CHECK below ties it to the status
--                   invariant: a task is COMPLETED iff completed_at is set.
--   * due_date    : calendar date (DATE, no time, no timezone). Choosing a date
--                   avoids interpreting the value in the server's timezone;
--                   comparisons against the user's local date are application
--                   concerns addressed in the task-management phase.
--   * version     : optimistic-locking counter (@Version).
--   * created_at / updated_at : audited UTC timestamps.

-- Indexes:
--   * idx_tasks_user_status   : user-scoped status queries ("my TODO tasks").
--                               Leftmost user_id prefix also serves plain
--                               per-user lookups, so no separate user_id index.
--   * idx_tasks_user_due_date : user-scoped due-date ordering/filtering
--                               (overdue derivation). Same leftmost-prefix note.
--   A global "status only" or "due_date only" index is intentionally NOT
--   created: without a user scope those queries are not part of the plan.
-- =============================================================================

CREATE TABLE tasks (
    id           UUID          PRIMARY KEY,
    user_id      UUID          NOT NULL,
    title        VARCHAR(200)  NOT NULL,
    description  VARCHAR(2000),
    status       VARCHAR(20)   NOT NULL DEFAULT 'TODO',
    due_date     DATE,
    completed_at TIMESTAMPTZ,
    version      BIGINT        NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ   NOT NULL,
    updated_at   TIMESTAMPTZ   NOT NULL,

    CONSTRAINT fk_tasks_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,

    CONSTRAINT ck_tasks_status
        CHECK (status IN ('TODO', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    CONSTRAINT ck_tasks_completed_at_status
        CHECK ((status = 'COMPLETED') = (completed_at IS NOT NULL)),
    CONSTRAINT ck_tasks_completed_at_not_before_created
        CHECK (completed_at IS NULL OR completed_at >= created_at),
    CONSTRAINT ck_tasks_timestamps
        CHECK (updated_at >= created_at)
);

CREATE INDEX idx_tasks_user_status   ON tasks (user_id, status);
CREATE INDEX idx_tasks_user_due_date ON tasks (user_id, due_date);