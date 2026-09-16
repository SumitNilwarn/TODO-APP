package com.todoapp.dto.dashboard;

/**
 * Dashboard statistics for the authenticated user's tasks.
 *
 * <p>All counters are derived from the caller's task rows at request time — nothing
 * is persisted or cached. {@code overdueTasks} uses the exact derived definition
 * ({@code dueDate} in the past AND status is neither {@code COMPLETED} nor
 * {@code CANCELLED}) evaluated against the application {@code Clock}; completed or
 * cancelled tasks are never counted as overdue even when their due date has
 * passed.</p>
 */
public record DashboardResponse(
        long totalTasks,
        long todoTasks,
        long inProgressTasks,
        long completedTasks,
        long cancelledTasks,
        long overdueTasks) {

    public static DashboardResponse from(DashboardCounts counts) {
        return new DashboardResponse(
                counts.totalTasks(),
                counts.todoTasks(),
                counts.inProgressTasks(),
                counts.completedTasks(),
                counts.cancelledTasks(),
                counts.overdueTasks());
    }
}