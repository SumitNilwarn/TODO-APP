package com.todoapp.service;

import com.todoapp.dto.dashboard.DashboardCounts;
import com.todoapp.dto.dashboard.DashboardResponse;
import com.todoapp.entity.TaskStatus;
import com.todoapp.repository.TaskRepository;
import com.todoapp.security.principal.AuthenticatedUser;
import java.time.Clock;
import java.time.LocalDate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Dashboard statistics for the authenticated user.
 *
 * <p>All counters come from a single user-scoped aggregate query against
 * {@code tasks} (nothing is loaded into memory and nothing is persisted or
 * cached). The queried owner is always the {@link AuthenticatedUser} principal —
 * no client-supplied identity is ever accepted — so User A can never observe
 * User B's counts.</p>
 *
 * <p>{@code overdueTasks} is evaluated in the database using the exact derived
 * definition ({@code dueDate < today} with status neither {@code COMPLETED} nor
 * {@code CANCELLED}) where {@code today} comes from the shared application
 * {@link Clock}, keeping it consistent with the response-level {@code overdue}
 * flag and the {@code overdue} list filter.</p>
 */
@Service
public class DashboardService {

    private final TaskRepository taskRepository;
    private final Clock clock;

    public DashboardService(TaskRepository taskRepository, Clock clock) {
        this.taskRepository = taskRepository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public DashboardResponse getDashboard(AuthenticatedUser principal) {
        DashboardCounts counts = taskRepository.countDashboard(
                principal.userId(),
                LocalDate.now(clock),
                TaskStatus.TODO,
                TaskStatus.IN_PROGRESS,
                TaskStatus.COMPLETED,
                TaskStatus.CANCELLED);
        return DashboardResponse.from(counts);
    }
}