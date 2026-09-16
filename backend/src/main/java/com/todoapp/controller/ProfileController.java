package com.todoapp.controller;

import com.todoapp.dto.ApiResponse;
import com.todoapp.dto.profile.ProfilePatchRequest;
import com.todoapp.dto.profile.ProfileResponse;
import com.todoapp.dto.profile.ProfileUpdateRequest;
import com.todoapp.dto.profile.ProfileUpdateResult;
import com.todoapp.security.principal.AuthenticatedUser;
import com.todoapp.service.ProfileService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(ApiPaths.PROFILE)
public class ProfileController {

    private final ProfileService profileService;

    public ProfileController(ProfileService profileService) {
        this.profileService = profileService;
    }

    @GetMapping
    ResponseEntity<ApiResponse<ProfileResponse>> getProfile(
            @AuthenticationPrincipal AuthenticatedUser principal) {
        return ResponseEntity.ok(ApiResponse.success(profileService.getProfile(principal)));
    }

    @PutMapping
    ResponseEntity<ApiResponse<ProfileResponse>> updateProfile(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @Valid @RequestBody ProfileUpdateRequest request) {
        ProfileUpdateResult result = profileService.updateProfile(principal, request);
        HttpStatus status = result.created() ? HttpStatus.CREATED : HttpStatus.OK;
        String message = result.created() ? "Profile created" : "Profile updated";
        return ResponseEntity.status(status)
                .body(new ApiResponse<>(true, result.profile(), message));
    }

    @PatchMapping
    ResponseEntity<ApiResponse<ProfileResponse>> patchProfile(
            @AuthenticationPrincipal AuthenticatedUser principal,
            @RequestBody ProfilePatchRequest request) {
        return ResponseEntity.ok(ApiResponse.success(profileService.patchProfile(principal, request)));
    }
}