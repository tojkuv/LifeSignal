# Database

Supabase PostgreSQL provides the primary database layer accessed exclusively through Go APIs using sqlc-generated code, with Row Level Security policies enforcing per-user and tenant isolation for secure data access.

## Content Structure

### Database Access
- **Go API Only**: Only access DB via Go APIs using `sqlc`-generated type-safe code with context.Context
- **RLS Policies**: Enforce RLS policies keyed on `auth.uid()` for per-user and tenant isolation
- **SQL Migrations**: Apply SQL migrations using `golang-migrate` with rollback scripts and transaction safety
- **No Direct Client Access**: Do not expose direct client socket subscriptions
- **Type Safety**: Use SQLC for compile-time SQL validation and Go struct generation
- **Connection Context**: Pass context.Context through all database operations for cancellation and timeouts

### Real-time Integration
- **Webhooks**: Use webhooks to forward real-time events to Fly.io services with structured logging
- **Event Processing**: Forward real-time events to Fly.io services for processing with gRPC integration
- **No Client Subscriptions**: Do not expose direct client socket subscriptions
- **Service Integration**: Integrate with Go services for real-time functionality using type-safe patterns
- **Structured Events**: Log all real-time events to Loki with structured fields for observability

### Monitoring and Performance
- **Query Monitoring**: Monitor query latency, pool size, index usage with Prometheus metrics
- **Performance Alerts**: Set up alerts for slow queries and DB load using structured logging
- **Connection Management**: Use `pgxpool` for DB connections in Go services with proper lifecycle management
- **Index Optimization**: Optimize indexes for query performance with EXPLAIN plan analysis
- **Structured Logging**: Log all database operations to Loki with query context and performance metrics

## Error Handling

### Error Categories
- **Connection Errors**: Network timeouts, connection pool exhaustion, service unavailability, and connectivity issues
- **Constraint Violations**: Foreign key conflicts, unique constraint failures, check constraint violations, and data integrity errors
- **Authorization Errors**: RLS policy violations, insufficient privileges, authentication failures, and permission denials
- **Transaction Errors**: Deadlocks, serialization conflicts, concurrent modification failures, and isolation violations
- **Data Validation Errors**: Type mismatches, format violations, constraint check failures, and schema validation errors
- **Performance Errors**: Query timeouts, resource limits, memory constraints, and execution plan issues

### Recovery Strategies
- **Exponential Backoff**: Progressive retry delays for transient connection, timeout, and availability errors with context cancellation
- **Transaction Rollback**: Automatic cleanup and consistent state restoration on operation failures with ACID compliance
- **Graceful Degradation**: Fallback to cached data, read replicas, or limited functionality during primary database outages
- **Circuit Breaker**: Service protection and cascade failure prevention during extended outages with automatic recovery using Go patterns
- **Error Context Logging**: Comprehensive error tracking with query context, user information, and performance metrics logged to Loki
- **Health Check Integration**: Proactive monitoring, automatic failover, and database health issue detection with alerting and structured logging

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

