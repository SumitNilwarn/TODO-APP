package com.todoapp.controller;

/**
 * Central API path constants.
 * <p>
 * Every controller maps under {@link #V1} to keep versioning consistent.
 */
public final class ApiPaths {

    public static final String V1 = "/api/v1";
    public static final String AUTH = V1 + "/auth";
    public static final String PROFILE = V1 + "/profile";
    public static final String TASKS = V1 + "/tasks";
    public static final String DASHBOARD = V1 + "/dashboard";
    public static final String HEALTH = V1 + "/health";

    private ApiPaths() {
    }
}