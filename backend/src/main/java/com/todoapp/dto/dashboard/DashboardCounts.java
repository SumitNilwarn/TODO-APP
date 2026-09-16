package com.todoapp.dto.dashboard;

/**
 * Internal aggregate projection returned by a single JPQL count query.
 *
 * <p>Computing all six counters in one grouped aggregate query avoids loading any
 * {@code Task} entity into memory. Our {@code tasks} constraints guarantee
 * non-null status/due-date semantics, and the query coalesces empty-result sums to
 * zero, so this record is always fully populated.</p>
 */
public record DashboardCounts(
        long totalTasks,
        long todoTasks,
        long inProgressTasks,
        long completedTasks,
        long cancelledTasks,
        long overdueTasks) {
}