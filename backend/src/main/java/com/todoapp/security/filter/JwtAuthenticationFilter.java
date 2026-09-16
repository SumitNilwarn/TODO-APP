package com.todoapp.security.filter;

import com.todoapp.entity.AccountStatus;
import com.todoapp.entity.User;
import com.todoapp.repository.UserRepository;
import com.todoapp.security.TokenAuthenticationException;
import com.todoapp.security.principal.AuthenticatedUser;
import com.todoapp.service.JwtService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Authenticates {@code Authorization: Bearer <jwt>} requests.
 *
 * <p>Created via {@code new} in {@link com.todoapp.security.config.SecurityConfig}
 * (deliberately not a {@code @Component}) so Spring Boot does not register a
 * second copy on the default filter chain.</p>
 *
 * <p>On a presented-but-invalid token the filter writes the standardized 401
 * {@code ApiError} through the injected {@link AuthenticationEntryPoint} rather
 * than throwing, because this filter runs <em>after</em>
 * {@code ExceptionTranslationFilter} in the chain, so a thrown exception would
 * surface as a 500. The global {@code GlobalExceptionHandler} does not apply at
 * the filter stage.</p>
 */
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private static final String BEARER_PREFIX = "Bearer ";

    private final JwtService jwtService;
    private final UserRepository userRepository;
    private final AuthenticationEntryPoint authenticationEntryPoint;

    public JwtAuthenticationFilter(JwtService jwtService, UserRepository userRepository,
                                   AuthenticationEntryPoint authenticationEntryPoint) {
        this.jwtService = jwtService;
        this.userRepository = userRepository;
        this.authenticationEntryPoint = authenticationEntryPoint;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (header != null && header.startsWith(BEARER_PREFIX)) {
            String token = header.substring(BEARER_PREFIX.length());
            try {
                AuthenticatedUser principal = jwtService.parseAccessToken(token);
                User user = userRepository.findById(principal.userId()).orElse(null);
                if (user == null || user.getAccountStatus() != AccountStatus.ACTIVE) {
                    throw new TokenAuthenticationException(
                            "TOKEN_INVALID", "Account is not available", null);
                }
                UsernamePasswordAuthenticationToken authentication =
                        new UsernamePasswordAuthenticationToken(principal, null, List.of());
                authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                SecurityContextHolder.getContext().setAuthentication(authentication);
            } catch (AuthenticationException ex) {
                SecurityContextHolder.clearContext();
                authenticationEntryPoint.commence(request, response, ex);
                return;
            }
        }
        filterChain.doFilter(request, response);
    }
}