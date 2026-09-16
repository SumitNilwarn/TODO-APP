package com.todoapp.dto.task;

import com.todoapp.entity.TaskStatus;
import java.time.LocalDate;
import org.springframework.data.domain.Sort;

/**
 * Parsed and validated task-list filters.
 *
 * <p>Produced by {@link com.todoapp.service.TaskService} from a raw
 * {@link TaskListQuery}. {@code null}/{@code 0}/{@code "createdAt"} markers mean
 * "no filter / default" and never form part of the resulting JPA query. The
 * {@code sortField} is guaranteed to belong to the documented allowlist and
 * {@code dueDateFrom <= dueDateTo} holds when both are present.</p>
 */
public record TaskQueryFilters(
        int page,
        int size,
        String sortField,
        Sort.Direction direction,
        TaskStatus status,
        LocalDate dueDateFrom,
        LocalDate dueDateTo,
        Boolean overdue,
        String search) {
}