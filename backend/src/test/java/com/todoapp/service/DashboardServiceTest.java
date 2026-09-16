package com.todoapp.service;

import com.todoapp.dto.dashboard.DashboardCounts;
import com.todoapp.dto.dashboard.DashboardResponse;
import com.todoapp.entity.TaskStatus;
import com.todoapp.repository.TaskRepository;
import com.todoapp.security.principal.AuthenticatedUser;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DashboardServiceTest {

    private static final UUID USER_ID = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private static final AuthenticatedUser PRINCIPAL = new AuthenticatedUser(USER_ID, "ada");
    private static final LocalDate TODAY = LocalDate.of(2026, 7, 15);
    private static final Clock CLOCK = Clock.fixed(
            Instant.parse("2026-07-15T10:00:00Z"), ZoneOffset.UTC);

    @Mock
    private TaskRepository taskRepository;

    private DashboardService dashboardService;

    @BeforeEach
    void setUp() {
        dashboardService = new DashboardService(taskRepository, CLOCK);
    }

    @Test
    void dashboardMapsAggregateCountsFromSingleQuery() {
        when(taskRepository.countDashboard(USER_ID, TODAY,
                TaskStatus.TODO, TaskStatus.IN_PROGRESS, TaskStatus.COMPLETED, TaskStatus.CANCELLED))
                .thenReturn(new DashboardCounts(10, 3, 2, 4, 1, 2));

        DashboardResponse response = dashboardService.getDashboard(PRINCIPAL);

        assertThat(response.totalTasks()).isEqualTo(10);
        assertThat(response.todoTasks()).isEqualTo(3);
        assertThat(response.inProgressTasks()).isEqualTo(2);
        assertThat(response.completedTasks()).isEqualTo(4);
        assertThat(response.cancelledTasks()).isEqualTo(1);
        assertThat(response.overdueTasks()).isEqualTo(2);
        verify(taskRepository).countDashboard(USER_ID, TODAY,
                TaskStatus.TODO, TaskStatus.IN_PROGRESS, TaskStatus.COMPLETED, TaskStatus.CANCELLED);
    }

    @Test
    void emptyDashboardReturnsZeroCounts() {
        when(taskRepository.countDashboard(USER_ID, TODAY,
                TaskStatus.TODO, TaskStatus.IN_PROGRESS, TaskStatus.COMPLETED, TaskStatus.CANCELLED))
                .thenReturn(new DashboardCounts(0, 0, 0, 0, 0, 0));

        DashboardResponse response = dashboardService.getDashboard(PRINCIPAL);

        assertThat(response.totalTasks()).isZero();
        assertThat(response.todoTasks()).isZero();
        assertThat(response.inProgressTasks()).isZero();
        assertThat(response.completedTasks()).isZero();
        assertThat(response.cancelledTasks()).isZero();
        assertThat(response.overdueTasks()).isZero();
    }

    @Test
    void dashboardAllCountsSumToTotal() {
        when(taskRepository.countDashboard(USER_ID, TODAY,
                TaskStatus.TODO, TaskStatus.IN_PROGRESS, TaskStatus.COMPLETED, TaskStatus.CANCELLED))
                .thenReturn(new DashboardCounts(12, 4, 3, 3, 2, 5));

        DashboardResponse response = dashboardService.getDashboard(PRINCIPAL);

        long sum = response.todoTasks() + response.inProgressTasks()
                + response.completedTasks() + response.cancelledTasks();
        assertThat(sum).isEqualTo(response.totalTasks());
    }

    @Test
    void dashboardIsAlwaysScopedToThePrincipal() {
        AuthenticatedUser other = new AuthenticatedUser(
                UUID.fromString("00000000-0000-0000-0000-000000000002"), "bob");
        when(taskRepository.countDashboard(other.userId(), TODAY,
                TaskStatus.TODO, TaskStatus.IN_PROGRESS, TaskStatus.COMPLETED, TaskStatus.CANCELLED))
                .thenReturn(new DashboardCounts(7, 7, 0, 0, 0, 0));

        DashboardResponse response = dashboardService.getDashboard(other);

        assertThat(response.totalTasks()).isEqualTo(7);
        verify(taskRepository).countDashboard(other.userId(), TODAY,
                TaskStatus.TODO, TaskStatus.IN_PROGRESS, TaskStatus.COMPLETED, TaskStatus.CANCELLED);
    }
}