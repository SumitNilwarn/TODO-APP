package com.todoapp.controller;

import com.todoapp.dto.ApiResponse;
import com.todoapp.dto.dashboard.DashboardResponse;
import com.todoapp.security.principal.AuthenticatedUser;
import com.todoapp.service.DashboardService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Authenticated task dashboard statistics (Phase 7).
 *
 * <p>All counters are scoped strictly to the authenticated principal; no
 * client-supplied user id is accepted anywhere, so a user can only ever see
 * their own task summary.</p>
 */
@RestController
@RequestMapping(ApiPaths.DASHBOARD)
@Tag(name = "Dashboard",
        description = "Authenticated task statistics (Phase 7): counts for the caller's tasks.")
public class DashboardController {

    private final DashboardService dashboardService;

    public DashboardController(DashboardService dashboardService) {
        this.dashboardService = dashboardService;
    }

    @GetMapping
    @Operation(summary = "Task dashboard statistics",
            description = "Returns the authenticated user's task counts: totalTasks, todoTasks, "
                    + "inProgressTasks, completedTasks, cancelledTasks and overdueTasks. overdueTasks "
                    + "uses the derived definition (dueDate before today and status not COMPLETED/"
                    + "CANCELLED) evaluated against the server clock. Counts are computed live from "
                    + "the database; nothing is persisted or cached. The response never exposes "
                    + "another user's data.")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "Dashboard statistics returned"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "Missing/invalid access token"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "500", description = "Unexpected server error")
    })
    ResponseEntity<ApiResponse<DashboardResponse>> getDashboard(
            @AuthenticationPrincipal AuthenticatedUser principal) {
        return ResponseEntity.ok(ApiResponse.success(dashboardService.getDashboard(principal)));
    }
}