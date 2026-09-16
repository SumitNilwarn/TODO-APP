package com.todoapp;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.todoapp.dto.auth.LoginRequest;
import com.todoapp.dto.auth.RegisterRequest;
import com.todoapp.dto.auth.TokenResponse;
import com.todoapp.entity.AccountStatus;
import com.todoapp.entity.RefreshToken;
import com.todoapp.entity.User;
import com.todoapp.repository.RefreshTokenRepository;
import com.todoapp.repository.UserRepository;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.Date;
import java.util.HexFormat;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.core.env.Environment;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * End-to-end authentication tests over the real security filter chain and a
 * real PostgreSQL container (Flyway schema + Hibernate validate). Each test is
 * transactional: the HTTP request joins the test transaction, so rows written by
 * one test never leak into another.
 */
@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class AuthIntegrationIT {

    private static final String PASSWORD = "S3cure-pass-42!";

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private Environment environment;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    private MvcResult register(RegisterRequest request) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andReturn();
    }

    private TokenResponse login(String identifier) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new LoginRequest(identifier, PASSWORD))))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode data = objectMapper.readTree(result.getResponse().getContentAsString()).path("data");
        return objectMapper.treeToValue(data, TokenResponse.class);
    }

    private static void setStatus(User user, AccountStatus status) {
        user.setAccountStatus(status);
    }

    private String forgedExpiredToken() {
        String secret = environment.getRequiredProperty("app.security.jwt.secret");
        String issuer = environment.getRequiredProperty("app.security.jwt.issuer");
        return Jwts.builder()
                .subject(UUID.randomUUID().toString())
                .issuer(issuer)
                .claim("username", "ghost")
                .issuedAt(Date.from(Instant.now().minusSeconds(3600)))
                .expiration(Date.from(Instant.now().minusSeconds(1800)))
                .signWith(Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8)))
                .compact();
    }

    private String forgedTokenWithWrongKey() {
        return Jwts.builder()
                .subject(UUID.randomUUID().toString())
                .issuer(environment.getRequiredProperty("app.security.jwt.issuer"))
                .claim("username", "ghost")
                .issuedAt(Date.from(Instant.now()))
                .expiration(Date.from(Instant.now().plusSeconds(300)))
                .signWith(Keys.hmacShaKeyFor("another-secret-another-secret-another-secret".getBytes(StandardCharsets.UTF_8)))
                .compact();
    }

    private String forgedTokenWithWrongIssuer() {
        String secret = environment.getRequiredProperty("app.security.jwt.secret");
        return Jwts.builder()
                .subject(UUID.randomUUID().toString())
                .issuer("evil-app")
                .claim("username", "ghost")
                .issuedAt(Date.from(Instant.now()))
                .expiration(Date.from(Instant.now().plusSeconds(300)))
                .signWith(Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8)))
                .compact();
    }

    private String forgedTokenWithUnknownUserId() {
        String secret = environment.getRequiredProperty("app.security.jwt.secret");
        String issuer = environment.getRequiredProperty("app.security.jwt.issuer");
        return Jwts.builder()
                .subject(UUID.randomUUID().toString())
                .issuer(issuer)
                .claim("username", "ghost")
                .issuedAt(Date.from(Instant.now()))
                .expiration(Date.from(Instant.now().plusSeconds(300)))
                .signWith(Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8)))
                .compact();
    }

    private static String sha256Hex(String raw) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(raw.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 is not available", ex);
        }
    }

    @Test
    void registerCreatesAccountAndMeReportsIdentity() throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new RegisterRequest("other", "other@example.com", PASSWORD))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.username").value("other"))
                .andExpect(jsonPath("$.data.userId").isNotEmpty())
                .andExpect(jsonPath("$.data.passwordHash").doesNotExist());

        TokenResponse tokens = login("other");
        mockMvc.perform(get("/api/v1/auth/me").header("Authorization", "Bearer " + tokens.accessToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value("other"))
                .andExpect(jsonPath("$.data.email").value("other@example.com"))
                .andExpect(jsonPath("$.data.passwordHash").doesNotExist());
    }

    @Test
    void registerValidationViolationsReturnFieldDetails() throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"a","email":"not-an-email","password":"weak"}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.error.details[?(@.field=='username')]").exists())
                .andExpect(jsonPath("$.error.details[?(@.field=='email')]").exists())
                .andExpect(jsonPath("$.error.details[?(@.field=='password')]").exists());
    }

    @Test
    void registerRejectsDuplicateUsernameCaseInsensitively() throws Exception {
        register(new RegisterRequest("ada", "ada@example.com", PASSWORD));

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new RegisterRequest("ADA", "different@example.com", PASSWORD))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("USERNAME_ALREADY_TAKEN"));
    }

    @Test
    void registerRejectsDuplicateEmailCaseInsensitively() throws Exception {
        register(new RegisterRequest("ada", "ada@example.com", PASSWORD));

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new RegisterRequest("newuser", "ADA@example.com", PASSWORD))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("EMAIL_ALREADY_TAKEN"));
    }

    @Test
    void loginAcceptsUsernameOrEmail() throws Exception {
        register(new RegisterRequest("grace", "grace@example.com", PASSWORD));

        TokenResponse tokens = login("GRACE@example.com");

        assertThat(tokens.accessToken()).isNotBlank();
        assertThat(tokens.refreshToken()).isNotBlank();
        assertThat(tokens.tokenType()).isEqualTo("Bearer");
        assertThat(tokens.expiresIn()).isEqualTo(900);
    }

    @Test
    void loginByWrongPasswordFailsGenericially() throws Exception {
        register(new RegisterRequest("grace", "grace@example.com", PASSWORD));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new LoginRequest("grace", "wrong-password"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("AUTHENTICATION_FAILED"));
    }

    @Test
    void loginByUnknownAccountFailsGenericially() throws Exception {
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new LoginRequest("ghost", PASSWORD))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("AUTHENTICATION_FAILED"));
    }

    @Test
    void loginRejectsDisabledAccount() throws Exception {
        register(new RegisterRequest("disabled", "disabled@example.com", PASSWORD));
        setStatus(userRepository.findByUsername("disabled").orElseThrow(), AccountStatus.DISABLED);
        userRepository.flush();

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new LoginRequest("disabled", PASSWORD))))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("ACCOUNT_DISABLED"));
    }

    @Test
    void loginRejectsLockedAccount() throws Exception {
        register(new RegisterRequest("locked", "locked@example.com", PASSWORD));
        setStatus(userRepository.findByUsername("locked").orElseThrow(), AccountStatus.LOCKED);
        userRepository.flush();

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new LoginRequest("locked", PASSWORD))))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("ACCOUNT_LOCKED"));
    }

    @Test
    void protectedEndpointRejectsAnonymousRequests() throws Exception {
        mockMvc.perform(get("/api/v1/auth/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.error.message").value("Authentication is required"));
    }

    @Test
    void protectedEndpointRejectsMalformedToken() throws Exception {
        mockMvc.perform(get("/api/v1/auth/me").header("Authorization", "Bearer garbage"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_INVALID"));
    }

    @Test
    void protectedEndpointRejectsExpiredToken() throws Exception {
        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer " + forgedExpiredToken()))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_EXPIRED"));
    }

    @Test
    void logoutRevokesRefreshToken() throws Exception {
        register(new RegisterRequest("bye", "bye@example.com", PASSWORD));
        TokenResponse tokens = login("bye");

        mockMvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new com.todoapp.dto.auth.LogoutRequest(tokens.refreshToken()))))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + tokens.refreshToken() + "\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("REFRESH_TOKEN_INVALID"));
    }

    @Test
    void refreshRotatesAndInvalidatesPresentedToken() throws Exception {
        register(new RegisterRequest("rotator", "rotator@example.com", PASSWORD));
        TokenResponse original = login("rotator");

        MvcResult rotatedResult = mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + original.refreshToken() + "\"}"))
                .andExpect(status().isOk())
                .andReturn();
        TokenResponse rotated = objectMapper.treeToValue(
                objectMapper.readTree(rotatedResult.getResponse().getContentAsString()).path("data"),
                TokenResponse.class);

        assertThat(rotated.refreshToken()).isNotBlank();
        assertThat(rotated.refreshToken()).isNotEqualTo(original.refreshToken());
        assertThat(rotated.accessToken()).isNotBlank();

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + original.refreshToken() + "\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("REFRESH_TOKEN_INVALID"));
    }

    @Test
    void refreshRejectsUnknownToken() throws Exception {
        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"totally-unknown-token\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("REFRESH_TOKEN_INVALID"));
    }

    @Test
    void refreshRejectsDisabledAccount() throws Exception {
        register(new RegisterRequest("rotator2", "rotator2@example.com", PASSWORD));
        TokenResponse tokens = login("rotator2");
        setStatus(userRepository.findByUsername("rotator2").orElseThrow(), AccountStatus.DISABLED);
        userRepository.flush();

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + tokens.refreshToken() + "\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("ACCOUNT_DISABLED"));
    }

    @Test
    void accessTokenWorksOnProtectedEndpoint() throws Exception {
        register(new RegisterRequest("ada", "ada@example.com", PASSWORD));
        TokenResponse tokens = login("ada");

        mockMvc.perform(get("/api/v1/auth/me").header("Authorization", "Bearer " + tokens.accessToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value("ada"));
    }

    @Test
    void protectedEndpointRejectsTokenSignedWithWrongKey() throws Exception {
        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer " + forgedTokenWithWrongKey()))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_INVALID"));
    }

    @Test
    void protectedEndpointRejectsTokenWithWrongIssuer() throws Exception {
        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer " + forgedTokenWithWrongIssuer()))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_INVALID"));
    }

    @Test
    void protectedEndpointRejectsTokenWithUnknownUserId() throws Exception {
        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer " + forgedTokenWithUnknownUserId()))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_INVALID"));
    }

    @Test
    void expiredRefreshTokenIsRejectedAtHttpLevel() throws Exception {
        register(new RegisterRequest("expiry", "expiry@example.com", PASSWORD));
        User user = userRepository.findByUsername("expiry").orElseThrow();
        String raw = "expired-raw-token-" + UUID.randomUUID();
        refreshTokenRepository.saveAndFlush(
                new RefreshToken(Instant.now().minusSeconds(60), user, sha256Hex(raw)));

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + raw + "\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("REFRESH_TOKEN_EXPIRED"));
    }

    @Test
    void refreshRejectsBlankAndMalformedTokens() throws Exception {
        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("REFRESH_TOKEN_INVALID"));

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"   \"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("REFRESH_TOKEN_INVALID"));

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"not-a-real-token!!!\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("REFRESH_TOKEN_INVALID"));
    }
}