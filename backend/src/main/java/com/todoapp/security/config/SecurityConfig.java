package com.todoapp.security.config;

import com.todoapp.controller.ApiPaths;
import com.todoapp.repository.UserRepository;
import com.todoapp.security.RestAccessDeniedHandler;
import com.todoapp.security.RestAuthenticationEntryPoint;
import com.todoapp.security.filter.JwtAuthenticationFilter;
import com.todoapp.service.JwtService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private final JwtService jwtService;
    private final UserRepository userRepository;

    public SecurityConfig(JwtService jwtService, UserRepository userRepository) {
        this.jwtService = jwtService;
        this.userRepository = userRepository;
    }

    @Bean
    SecurityFilterChain securityFilterChain(
            HttpSecurity http,
            RestAuthenticationEntryPoint authenticationEntryPoint,
            RestAccessDeniedHandler accessDeniedHandler) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .cors(Customizer.withDefaults())
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .exceptionHandling(exceptions -> exceptions
                .authenticationEntryPoint(authenticationEntryPoint)
                .accessDeniedHandler(accessDeniedHandler))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                .requestMatchers(HttpMethod.POST, ApiPaths.AUTH + "/register").permitAll()
                .requestMatchers(HttpMethod.POST, ApiPaths.AUTH + "/login").permitAll()
                .requestMatchers(HttpMethod.POST, ApiPaths.AUTH + "/refresh").permitAll()
                .requestMatchers(HttpMethod.POST, ApiPaths.AUTH + "/logout").permitAll()
                .requestMatchers(ApiPaths.HEALTH + "/**").permitAll()
                .requestMatchers("/swagger-ui/**", "/swagger-ui.html", "/v3/api-docs/**").permitAll()
                .requestMatchers(ApiPaths.PROFILE + "/**").authenticated()
                .requestMatchers(ApiPaths.TASKS + "/**").authenticated()
                .requestMatchers(ApiPaths.DASHBOARD + "/**").authenticated()
                .anyRequest().authenticated())
            .addFilterBefore(
                new JwtAuthenticationFilter(jwtService, userRepository, authenticationEntryPoint),
                UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }
}