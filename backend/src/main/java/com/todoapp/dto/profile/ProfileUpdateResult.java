package com.todoapp.dto.profile;

/**
 * Result of a full profile update: the persisted profile plus whether the PUT
 * created it (for a 201 CREATED) or replaced an existing one (200 OK).
 */
public record ProfileUpdateResult(boolean created, ProfileResponse profile) {
}