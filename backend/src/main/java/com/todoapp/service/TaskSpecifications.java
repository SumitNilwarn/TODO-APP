package com.todoapp.service;

import com.todoapp.dto.task.TaskQueryFilters;
import com.todoapp.entity.Task;
import com.todoapp.entity.TaskStatus;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.springframework.data.jpa.domain.Specification;

/**
 * User-scoped JPA query specifications for {@link Task}.
 *
 * <p>Ownership is a mandatory conjunct in every specification: the owner column is
 * always bound to the authenticated principal's id, so a spec can never return a
 * task belonging to another user — matching the IDOR-safe conventions of Phases
 * 5/6. Filters ({@code status}, due-date range, {@code overdue}, case-insensitive
 * partial search over title/description) are each optional and combined with
 * {@code AND}.</p>
 *
 * <p>{@code overdue} is evaluated against the caller-supplied {@code today} (the
 * application {@code Clock} date) rather than a hard-coded "now", keeping the
 * list query and the response-level {@code overdue} flag consistent. The LIKE
 * search escapes {@code %}, {@code _} and {@code \} so user input is treated as a
 * literal substring.</p>
 */
public final class TaskSpecifications {

    private static final char LIKE_ESCAPE = '\\';

    private TaskSpecifications() {
    }

    public static Specification<Task> forUserAndFilters(UUID userId, TaskQueryFilters filters, LocalDate today) {
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.equal(root.get("user").get("id"), userId));
            if (filters.status() != null) {
                predicates.add(cb.equal(root.get("status"), filters.status()));
            }
            if (filters.dueDateFrom() != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("dueDate"), filters.dueDateFrom()));
            }
            if (filters.dueDateTo() != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("dueDate"), filters.dueDateTo()));
            }
            if (filters.overdue() != null) {
                Predicate overdue = overduePredicate(root, cb, today);
                predicates.add(filters.overdue() ? overdue : cb.not(overdue));
            }
            if (filters.search() != null) {
                String pattern = "%" + escapeLike(filters.search()).toLowerCase(Locale.ROOT) + "%";
                Predicate titleMatch = cb.like(cb.lower(root.get("title")), pattern, LIKE_ESCAPE);
                Predicate descriptionMatch = cb.like(cb.lower(root.get("description")), pattern, LIKE_ESCAPE);
                predicates.add(cb.or(titleMatch, descriptionMatch));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
    }

    private static Predicate overduePredicate(Root<Task> root, CriteriaBuilder cb, LocalDate today) {
        return cb.and(
                cb.isNotNull(root.get("dueDate")),
                cb.lessThan(root.get("dueDate"), today),
                cb.notEqual(root.get("status"), TaskStatus.COMPLETED),
                cb.notEqual(root.get("status"), TaskStatus.CANCELLED));
    }

    private static String escapeLike(String value) {
        return value
                .replace("\\", "\\\\")
                .replace("%", "\\%")
                .replace("_", "\\_");
    }
}