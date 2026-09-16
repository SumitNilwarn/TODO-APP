package com.todoapp.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.ForeignKey;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;

/**
 * A task owned by exactly one {@link User}.
 *
 * <p>{@code dueDate} is a calendar date ({@link LocalDate}) with no time
 * component, which avoids silently interpreting the value in the server's
 * timezone. {@code completedAt} is an exact UTC instant, populated whenever the
 * task becomes {@link TaskStatus#COMPLETED}; a database {@code CHECK} keeps the
 * two consistent (completed iff completedAt is present).</p>
 *
 * <p>The relationship is unidirectional {@code Task -> User} (lazy); there is no
 * inverse collection on {@code User} and ownership is always expressed through
 * the {@code user_id} column.</p>
 */
@Entity
@Table(name = "tasks")
public class Task extends BaseEntity {

    public static final int TITLE_MAX_LENGTH = 200;
    public static final int DESCRIPTION_MAX_LENGTH = 2000;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false,
            foreignKey = @ForeignKey(name = "fk_tasks_user"))
    private User user;

    @Column(name = "title", nullable = false, length = TITLE_MAX_LENGTH)
    private String title;

    @Column(name = "description", length = DESCRIPTION_MAX_LENGTH)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private TaskStatus status = TaskStatus.TODO;

    @Column(name = "due_date")
    private LocalDate dueDate;

    @Column(name = "completed_at")
    private Instant completedAt;

    protected Task() {
    }

    public Task(User user, String title) {
        this.user = user;
        this.title = title;
    }

    public Task(User user, String title, String description) {
        this.user = user;
        this.title = title;
        this.description = description;
    }

    public User getUser() {
        return user;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public TaskStatus getStatus() {
        return status;
    }

    public void setStatus(TaskStatus status) {
        this.status = status;
    }

    public LocalDate getDueDate() {
        return dueDate;
    }

    public void setDueDate(LocalDate dueDate) {
        this.dueDate = dueDate;
    }

    public Instant getCompletedAt() {
        return completedAt;
    }

    public void setCompletedAt(Instant completedAt) {
        this.completedAt = completedAt;
    }

    /**
     * Aligns {@code completedAt} with {@code createdAt} on first persist. Spring
     * Data auditing stamps {@code createdAt} from its own clock moments before the
     * INSERT, which can be a few microseconds later than the service clock used
     * for {@code completedAt}; the database CHECK requires {@code completed_at >=
     * created_at}, so any completion instant that would precede it is raised to
     * the creation instant. This entity-listener callback runs after the auditing
     * listener but still before the INSERT.
     */
    @PrePersist
    void reconcileCompletionTimestampWithCreation() {
        if (getCompletedAt() != null && getCreatedAt() != null
                && getCompletedAt().isBefore(getCreatedAt())) {
            setCompletedAt(getCreatedAt());
        }
    }
}