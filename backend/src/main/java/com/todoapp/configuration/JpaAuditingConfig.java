package com.todoapp.configuration;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/**
 * Enables Spring Data JPA auditing so that {@link org.springframework.data.annotation.CreatedDate}
 * and {@link org.springframework.data.annotation.LastModifiedDate} annotations are honoured by
 * {@link org.springframework.data.jpa.domain.support.AuditingEntityListener}.
 *
 * <p>No {@link org.springframework.data.domain.AuditorAware} bean is required yet because
 * {@code @CreatedBy}/{@code @LastModifiedBy} are not used. The date/time-only auditing
 * handler provided by Spring Data is sufficient.</p>
 */
@Configuration
@EnableJpaAuditing
public class JpaAuditingConfig {
}