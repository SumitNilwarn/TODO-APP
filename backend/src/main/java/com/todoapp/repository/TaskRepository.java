package com.todoapp.repository;

import com.todoapp.dto.dashboard.DashboardCounts;
import com.todoapp.entity.Task;
import com.todoapp.entity.TaskStatus;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * Persistence access for {@link Task}.
 *
 * <p>Every task belongs to exactly one user; the ownership-respecting queries
 * ({@code findByUserId}, {@code findByIdAndUserId}, the specifications executed
 * through {@link JpaSpecificationExecutor}, and {@code countDashboard}) keep all
 * task access scoped to a single owner.</p>
 */
public interface TaskRepository extends JpaRepository<Task, UUID>, JpaSpecificationExecutor<Task> {

    List<Task> findByUserId(UUID userId);

    Optional<Task> findByIdAndUserId(UUID id, UUID userId);

    /**
     * Single aggregate query computing every dashboard counter for one user in one
     * round trip on PostgreSQL 16 (no entities are loaded). {@code overdueTasks}
     * uses the exact derived definition: {@code dueDate < :today} and status is
     * neither {@code COMPLETED} nor {@code CANCELLED}, both evaluated in SQL.
     */
    @Query("""
            select new com.todoapp.dto.dashboard.DashboardCounts(
                count(t),
                coalesce(sum(case when t.status = :statusTodo then 1 else 0 end), 0L),
                coalesce(sum(case when t.status = :statusInProgress then 1 else 0 end), 0L),
                coalesce(sum(case when t.status = :statusCompleted then 1 else 0 end), 0L),
                coalesce(sum(case when t.status = :statusCancelled then 1 else 0 end), 0L),
                coalesce(sum(case when t.dueDate is not null
                        and t.dueDate < :today
                        and t.status <> :statusCompleted
                        and t.status <> :statusCancelled
                        then 1 else 0 end), 0L)
            )
            from Task t
            where t.user.id = :userId
            """)
    DashboardCounts countDashboard(@Param("userId") UUID userId,
                                   @Param("today") LocalDate today,
                                   @Param("statusTodo") TaskStatus statusTodo,
                                   @Param("statusInProgress") TaskStatus statusInProgress,
                                   @Param("statusCompleted") TaskStatus statusCompleted,
                                   @Param("statusCancelled") TaskStatus statusCancelled);
}