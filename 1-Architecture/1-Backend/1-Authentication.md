# Authentication

Firebase Authentication provides phone-only authentication for the backend system, handling user verification through SMS and token management for secure access to Supabase Database, Supabase Storage, and Fly.io APIs.

## Content Structure

### Phone Authentication
- **Firebase Phone Auth**: Primary authentication method using SMS verification with async/await patterns
- **TCA Client Architecture**: iOS clients use @DependencyClient for Firebase authentication platform integration
- **Token Verification**: Go backend verifies Firebase ID tokens using `firebase.google.com/go` with context.Context
- **UID Extraction**: Extract `uid` and custom claims from verified tokens with type-safe Go patterns
- **Client Integration**: Clients include ID token in gRPC API calls for authentication
- **Structured Logging**: Authentication events logged to Loki with structured fields for observability

### Token Management
- **ID Token Verification**: Verify Firebase ID tokens in Go middleware with context.Context
- **Custom Claims**: Extract user roles and permissions from token claims with type-safe Go patterns
- **Token Propagation**: Pass `uid` to Supabase DB via RLS and Supabase Storage
- **Admin Credentials**: Never expose Firebase Admin credentials to clients
- **gRPC Integration**: Include token verification in gRPC interceptors for service authentication
- **Dependency Injection**: Use @Dependency pattern for testable token management in iOS clients

### Security Measures
- **Rate Limiting**: Enforce rate limits on SMS and login endpoints with Go middleware
- **Exponential Backoff**: Implement exponential backoff on auth attempts with context cancellation
- **Circuit Breakers**: Use circuit breakers for authentication service protection with Go patterns
- **Admin Isolation**: Keep Firebase Admin SDK server-side only
- **Fly.io Security**: Secure credential management using Fly.io secrets and environment variables
- **Structured Security Logging**: Log security events to Loki with structured fields for monitoring

## Error Handling

### Authentication Failures
- **Invalid Token**: Handle expired or malformed Firebase ID tokens gracefully
- **Missing Claims**: Manage tokens without required custom claims
- **Network Timeouts**: Implement retry logic for Firebase service connectivity
- **Rate Limit Exceeded**: Return appropriate HTTP status codes for rate limiting

### Recovery Strategies
- **Token Refresh**: Guide clients to refresh expired tokens
- **Graceful Degradation**: Provide limited functionality when auth services are down
- **Error Logging**: Log authentication failures with request context
- **Circuit Breaker**: Prevent cascading failures during auth service outages

## Testing

### Unit Testing
- **Token Verification**: Test Firebase ID token validation with mock tokens
- **Middleware Testing**: Test authentication middleware with valid and invalid tokens
- **Claims Extraction**: Test extraction of `uid` and custom claims from tokens
- **Error Scenarios**: Test handling of expired, malformed, and missing tokens

### Integration Testing
- **Firebase Integration**: Test actual Firebase token verification in test environment
- **End-to-End Flow**: Test complete authentication flow from client to backend
- **Rate Limiting**: Test rate limiting enforcement on authentication endpoints
- **Service Integration**: Test token propagation to Supabase and other services

## Deployment

### Firebase Configuration
- **Project Setup**: Configure Firebase project with phone authentication enabled
- **Service Account**: Generate and securely store Firebase Admin SDK service account key
- **Environment Variables**: Set Firebase project ID and credentials in deployment environment
- **Regional Settings**: Configure SMS providers for target geographic regions

### Go Service Deployment
- **Authentication Middleware**: Deploy JWT verification middleware in gRPC services
- **Environment Secrets**: Securely manage Firebase credentials using secret management
- **Health Checks**: Implement health endpoints that verify Firebase connectivity
- **Logging Configuration**: Set up structured logging for authentication events

## Monitoring

### Authentication Metrics
- **Success Rate**: Track authentication success/failure rates
- **Response Time**: Monitor Firebase token verification latency
- **Rate Limiting**: Track rate limit hits and blocked requests
- **Token Usage**: Monitor token validation frequency and patterns

### Security Monitoring
- **Failed Attempts**: Alert on authentication spikes or unusual patterns
- **Token Anomalies**: Detect suspicious token usage or validation failures
- **Admin Access**: Monitor Firebase Admin SDK usage and access patterns
- **Geographic Patterns**: Track authentication attempts by region

## Anti-patterns

### Security Anti-patterns
- **Exposing Admin Credentials**: Never include Firebase Admin SDK credentials in client-side code
- **Bypassing Token Verification**: Skipping Firebase ID token verification in backend services
- **Client-Side Only Auth**: Relying solely on client-side authentication without server verification
- **Weak Rate Limiting**: Not implementing proper rate limiting on authentication endpoints

### Implementation Anti-patterns
- **Hardcoded Credentials**: Embedding Firebase configuration or secrets directly in code
- **Missing Error Handling**: Not properly handling authentication failures or network errors
- **Temporary RLS Bypass**: Temporarily disabling RLS policies for admin operations
- **Insufficient Logging**: Not logging authentication events for security monitoring
