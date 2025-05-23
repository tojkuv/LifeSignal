# Database

Supabase PostgreSQL provides the primary database layer accessed exclusively through Go APIs using sqlc-generated code, with Row Level Security policies enforcing per-user and tenant isolation for secure data access.

## Content Structure

### Modern Database Access
- **SQLC Type Safety**: Use `sqlc` for compile-time SQL validation, type-safe Go struct generation, and automatic parameter binding
- **Context-Driven Operations**: Pass context.Context through all database operations for proper cancellation, timeout, and tracing
- **RLS Security**: Enforce PostgreSQL Row Level Security policies keyed on `auth.uid()` for multi-tenant data isolation
- **Migration Management**: Use `golang-migrate/migrate` for version-controlled schema migrations with atomic rollback capabilities
- **Connection Pooling**: Use `pgxpool` for efficient connection pooling with health checks and load balancing
- **Structured Logging**: Log all database operations to Loki with structured fields for observability and performance tracking

### Modern Event Architecture
- **gRPC Event Streaming**: Use gRPC streams for real-time event distribution with proper context cancellation and backpressure
- **Webhook Processing**: Process Supabase webhooks through Go HTTP handlers with structured payload validation
- **Event Transformation**: Transform database events into typed Go events using SQLC-generated structures
- **Context Propagation**: Maintain request context through event processing chains for proper cancellation and tracing
- **Async Processing**: Handle events asynchronously using Go worker pools with graceful shutdown and error recovery
- **Event Sourcing**: Implement event sourcing patterns for audit trails and system state reconstruction

### Modern Observability
- **Prometheus Integration**: Collect database metrics including query latency, connection pool status, and error rates
- **Distributed Tracing**: Implement OpenTelemetry tracing through database operations for end-to-end request tracking
- **Performance Profiling**: Use EXPLAIN ANALYZE with SQLC queries for performance optimization and index validation
- **Health Monitoring**: Implement comprehensive health checks for database connectivity, replication lag, and resource usage
- **Error Correlation**: Correlate database errors with request IDs and user context for effective debugging
- **Resource Tracking**: Monitor connection pool utilization, transaction duration, and lock contention patterns

## Error Handling

### Modern Error Categories
- **SQLC Generation Errors**: SQL compilation failures, type mismatches, and schema-query inconsistencies with compile-time validation
- **Context Cancellation Errors**: Operation timeouts, request cancellations, and context deadline exceeded scenarios
- **Connection Pool Errors**: Pool exhaustion, connection leaks, health check failures, and resource management issues
- **Migration Errors**: Schema migration failures, version conflicts, rollback scenarios, and migration lock contention
- **RLS Policy Violations**: Row-level security violations, tenant isolation failures, and unauthorized data access attempts
- **Transaction Consistency Errors**: Deadlock detection, serialization failures, and concurrent modification conflicts with retry strategies

### Modern Recovery Strategies
- **Context-Aware Retry**: Implement exponential backoff with jitter using context.Context for proper cancellation and timeout handling
- **SQLC Error Handling**: Leverage SQLC's type-safe error handling with structured error responses and query validation
- **Migration Recovery**: Use golang-migrate's atomic migration rollback capabilities with proper lock management and version tracking
- **Connection Pool Recovery**: Implement automatic connection recovery with health checks, pool recreation, and graceful degradation
- **Distributed Tracing Recovery**: Maintain trace context through error scenarios for comprehensive debugging and root cause analysis
- **Circuit Breaker Integration**: Use Go circuit breaker patterns with observability hooks for automatic failure detection and recovery

## Testing

### Unit Testing
- **pgTAP Integration**: Isolated testing of database functions, triggers, stored procedures, and RLS policies
- **Function Testing**: Comprehensive validation of database functions with various input scenarios and edge cases
- **Constraint Testing**: Validation of foreign key constraints, check constraints, and data integrity rules
- **RLS Policy Testing**: Comprehensive security policy validation with diverse user contexts and edge cases
- **SQLC Testing**: Test generated Go code with table-driven tests and context.Context integration
- **Mock Database**: Use testcontainers for isolated database testing with real PostgreSQL instances

### Integration Testing
- **End-to-End Data Flows**: Testing with Firebase Authentication, service integration, and cross-system validation
- **Real-time Testing**: Validation of real-time subscriptions, WebSocket connections, and live data updates
- **Cross-Service Testing**: Database integration testing with Fly.io gRPC services and Supabase Storage
- **Migration Testing**: Schema change validation with data integrity, rollback verification, and deployment safety
- **gRPC Integration**: Test database operations through gRPC services with proper context propagation
- **Type Safety Testing**: Validate SQLC-generated code with comprehensive Go integration tests

### Performance Testing
- **Load Testing**: Concurrent users, real-time subscriptions, query optimization, and scalability limits
- **Query Performance**: EXPLAIN plan analysis, index optimization, and query execution time validation
- **Connection Pool Testing**: Connection pooling efficiency, resource management, and concurrent access patterns
- **Real-time Performance**: WebSocket connection management, subscription performance, and resource utilization

### Security Testing
- **Penetration Testing**: RLS policies, authentication bypass attempts, and data access vulnerabilities
- **Authorization Testing**: Permission validation across different user roles, contexts, and access patterns
- **SQL Injection Testing**: Parameterized query validation and input sanitization verification
- **Data Privacy Testing**: Ensuring proper data isolation and access control across tenant boundaries

## Deployment

### Environment Configuration
- **Development**: Local Supabase instance with Docker for isolated development, testing, and rapid iteration
- **Staging**: Dedicated Supabase project for pre-production validation, integration testing, and deployment verification
- **Production**: Optimized Supabase project with performance tuning, monitoring, backup strategies, and high availability
- **Configuration Management**: Secure environment variables, connection strings, API key rotation, and secrets management
- **Fly.io Integration**: Use Fly.io secrets for database credentials and environment-specific configuration
- **Context Configuration**: Configure database connections with proper context.Context timeout and cancellation

### Schema Management
- **Migration Pipeline**: Version-controlled schema changes with automated deployment, validation, and dependency tracking
- **CI/CD Integration**: Automated schema deployment with testing, rollback capabilities, and deployment verification
- **Data Migration**: Safe data transformation strategies with backup, recovery procedures, and integrity validation
- **Rollback Procedures**: Automated rollback mechanisms for failed deployments with data integrity checks
- **SQLC Integration**: Regenerate Go code after schema changes with automated validation and type checking
- **Migration Logging**: Log all migration operations to Loki with structured fields for audit and debugging

### Performance Optimization
- **Index Strategy**: Performance-optimized indexing with query analysis, maintenance, and automated optimization
- **Connection Optimization**: Advanced connection pooling with load balancing, failover, and resource management
- **RLS Policy Optimization**: Performance-tuned Row Level Security policies with query plan analysis
- **Function Deployment**: Database functions, triggers, and stored procedures with version control and optimization

### Infrastructure Deployment
- **Container Deployment**: Database service containerization and orchestration for scalability
- **Load Balancing**: High availability setup with failover, redundancy, and traffic distribution
- **Backup Strategy**: Automated backup procedures with point-in-time recovery and disaster recovery
- **SSL/TLS Configuration**: Secure communication channels for all database connections and operations
- **Fly.io Deployment**: Deploy Go database services on Fly.io with proper health checks and scaling
- **gRPC Services**: Deploy database access through gRPC services with proper connection management

## Monitoring

### Performance Monitoring
- **Query Performance**: Response times, execution plans, and query optimization metrics with Prometheus
- **Connection Metrics**: Connection pool utilization, active connections, and resource usage with structured logging
- **Real-time Metrics**: WebSocket connection counts, subscription performance, and live data throughput
- **Resource Utilization**: CPU, memory, disk I/O, and network usage monitoring for database operations
- **SQLC Metrics**: Monitor generated query performance and type safety validation with Prometheus
- **Context Monitoring**: Track context.Context usage, timeouts, and cancellation patterns

### Security Monitoring
- **Access Patterns**: User access patterns, authentication events, and authorization failures logged to Loki
- **RLS Policy Violations**: Row Level Security policy violations and unauthorized access attempts with structured logging
- **Data Access Auditing**: Comprehensive audit trails for data access, modifications, and administrative operations
- **Threat Detection**: Suspicious query patterns, potential SQL injection attempts, and security anomalies
- **Authentication Integration**: Monitor Firebase token validation and user context propagation

### Operational Monitoring
- **Database Health**: Database availability, uptime, and service health monitoring with Prometheus
- **Migration Status**: Schema migration progress, success rates, and rollback events logged to Loki
- **Backup Monitoring**: Backup completion status, integrity verification, and recovery testing
- **Integration Status**: Cross-service integration health with Fly.io APIs and Firebase Authentication
- **gRPC Health**: Monitor gRPC service health and database connection status with structured logging

### Alerting and Response
- **Performance Alerts**: Query performance degradation, connection pool exhaustion, and resource limits
- **Security Alerts**: Unauthorized access attempts, RLS policy violations, and security incidents
- **Availability Alerts**: Database downtime, connection failures, and service unavailability
- **Capacity Alerts**: Storage utilization, connection limits, and scaling requirements

## Anti-patterns

### Security Anti-patterns
- **Bypassing RLS**: Using service_role key on client-side or bypassing Row Level Security policies without proper justification
- **Weak Authentication**: Not properly validating Firebase JWT tokens or implementing insufficient authentication checks
- **SQL Injection Risks**: Hardcoding SQL queries without parameterization, creating security vulnerabilities
- **Insufficient Access Control**: Not implementing comprehensive RLS policies for all sensitive data access

### Performance Anti-patterns
- **Inefficient Queries**: Using SELECT * queries instead of specific column selection for performance optimization
- **Poor Indexing**: Creating excessive or redundant indexes that impact write performance and storage costs
- **Missing Pagination**: Not implementing proper pagination for large result sets, causing performance issues
- **Connection Mismanagement**: Not implementing proper database connection lifecycle management and resource cleanup
- **Missing Context**: Not using context.Context for query timeouts and cancellation in Go operations
- **Bypassing SQLC**: Writing raw SQL queries instead of using SQLC-generated type-safe code

### Architecture Anti-patterns
- **Large Binary Storage**: Storing large binary data directly in database tables instead of using Supabase Storage
- **Manual Schema Changes**: Making manual schema changes without creating corresponding migration files
- **Complex RLS Logic**: Implementing complex business logic in RLS policies instead of application layer
- **Missing Constraints**: Not using foreign key constraints, leading to referential integrity issues

### Testing and Monitoring Anti-patterns
- **Insufficient Testing**: Not testing Row Level Security policies comprehensively with different user contexts
- **Poor Error Handling**: Not handling database connection errors, timeouts, and transaction failures properly
- **Missing Monitoring**: Ignoring database performance monitoring and query optimization opportunities
- **Inadequate Backup**: Not implementing proper backup and disaster recovery strategies with testing
- **Unstructured Logging**: Not using structured logging for database operations and performance tracking with Loki
- **Missing Type Safety Testing**: Not testing SQLC-generated code with comprehensive Go integration tests
- **Poor Context Usage**: Not testing context.Context cancellation and timeout scenarios in database operations

