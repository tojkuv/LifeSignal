# Supabase Deployment

## Purpose

This document outlines the deployment architecture, strategies, and best practices for deploying Supabase applications.

## Core Principles

### Type Safety

- Use TypeScript for deployment scripts
- Implement type-safe configuration
- Create typed deployment utilities
- Use schema validation for deployment configurations

### Modularity/Composability

- Organize deployment by environment
- Implement modular deployment scripts
- Create reusable deployment utilities
- Design composable deployment pipelines

### Testability

- Test deployments in isolated environments
- Implement deployment validation
- Create test utilities for deployment verification
- Design deterministic deployment processes

## Content Structure

### Deployment Environments

#### Environment Structure

Our deployment strategy uses multiple environments:

1. **Development**: For individual developer testing
2. **Staging**: For pre-production testing
3. **Production**: For live application

Each environment has its own Supabase project:

```
environments/
├── development/
│   ├── .env.development
│   └── supabase/
│       ├── config.toml
│       └── seed.sql
├── staging/
│   ├── .env.staging
│   └── supabase/
│       ├── config.toml
│       └── seed.sql
└── production/
    ├── .env.production
    └── supabase/
        ├── config.toml
        └── seed.sql
```

#### Environment Configuration

Each environment has specific configuration:

```toml
# Example: config.toml for development
project_id = "your-dev-project-id"
[api]
  port = 54321
  schemas = ["public", "storage", "auth"]
  extra_search_path = ["public", "extensions"]
  max_rows = 1000

[db]
  port = 54322
  shadow_port = 54320
  major_version = 15

[studio]
  port = 54323

[inbucket]
  port = 54324
  smtp_port = 54325
  pop3_port = 54326

[storage]
  file_size_limit = "50MiB"

[auth]
  site_url = "http://localhost:3000"
  additional_redirect_urls = ["https://localhost:3000"]
  jwt_expiry = 3600
  enable_signup = true
```

```bash
# Example: .env.development
SUPABASE_URL=https://your-dev-project.supabase.co
SUPABASE_ANON_KEY=your-dev-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-dev-service-role-key
```

### CI/CD Pipeline

#### Pipeline Structure

Our CI/CD pipeline follows these stages:

1. **Build**: Compile and build the application
2. **Test**: Run unit and integration tests
3. **Migrate**: Apply database migrations
4. **Deploy**: Deploy to the appropriate environment

```yaml
# Example: GitHub Actions workflow
name: Deploy to Supabase

on:
  push:
    branches:
      - main
      - staging
      - develop

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Set up Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '16'

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Build
        run: npm run build

      - name: Test
        run: npm test

      - name: Set environment
        id: set-env
        run: |
          if [[ $GITHUB_REF == 'refs/heads/main' ]]; then
            echo "::set-output name=environment::production"
          elif [[ $GITHUB_REF == 'refs/heads/staging' ]]; then
            echo "::set-output name=environment::staging"
          else
            echo "::set-output name=environment::development"
          fi

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Deploy migrations
        run: |
          supabase link --project-ref ${{ secrets.SUPABASE_PROJECT_ID_${{ steps.set-env.outputs.environment }} }}
          supabase db push
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}

      - name: Deploy Edge Functions
        run: |
          supabase functions deploy
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
```

#### Deployment Scripts

Create deployment scripts for consistent deployment:

```typescript
// Example: deploy.ts
import { execSync } from 'child_process';
import * as dotenv from 'dotenv';
import * as fs from 'fs';
import * as path from 'path';

// Environment configuration
const environments = {
  development: {
    projectId: 'your-dev-project-id',
    envFile: '.env.development'
  },
  staging: {
    projectId: 'your-staging-project-id',
    envFile: '.env.staging'
  },
  production: {
    projectId: 'your-prod-project-id',
    envFile: '.env.production'
  }
};

// Get environment from command line
const envArg = process.argv[2];
if (!envArg || !environments[envArg]) {
  console.error(`Please specify a valid environment: ${Object.keys(environments).join(', ')}`);
  process.exit(1);
}

const env = environments[envArg];

// Load environment variables
dotenv.config({ path: env.envFile });

// Deploy to Supabase
console.log(`Deploying to ${envArg} environment (${env.projectId})...`);

try {
  // Link to project
  execSync(`supabase link --project-ref ${env.projectId}`, {
    stdio: 'inherit'
  });

  // Deploy database migrations
  console.log('Deploying database migrations...');
  execSync('supabase db push', {
    stdio: 'inherit'
  });

  // Deploy Edge Functions
  console.log('Deploying Edge Functions...');
  execSync('supabase functions deploy', {
    stdio: 'inherit'
  });

  console.log(`Successfully deployed to ${envArg} environment!`);
} catch (error) {
  console.error(`Deployment failed: ${error.message}`);
  process.exit(1);
}
```

### Database Migrations

Manage database schema changes:

```bash
# Example: Create a new migration
supabase migration new create_posts_table

# Example: Apply migrations
supabase db push

# Example: Reset database
supabase db reset
```

Example migration file:

```sql
-- Example: Migration file (20230101000000_create_posts_table.sql)
-- Create posts table
CREATE TABLE public.posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    author_id UUID REFERENCES auth.users(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,

    CONSTRAINT title_length CHECK (char_length(title) >= 3 AND char_length(title) <= 100)
);

-- Create updated_at trigger
CREATE TRIGGER handle_posts_updated_at
BEFORE UPDATE ON public.posts
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Create RLS policies
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view published posts"
ON public.posts
FOR SELECT
USING (true);

CREATE POLICY "Users can create posts"
ON public.posts
FOR INSERT
WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can update their own posts"
ON public.posts
FOR UPDATE
USING (auth.uid() = author_id);

CREATE POLICY "Users can delete their own posts"
ON public.posts
FOR DELETE
USING (auth.uid() = author_id);
```

### Seed Data

Create seed data for development and testing:

```sql
-- Example: seed.sql
-- Insert test users
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'admin@example.com', '$2a$10$abcdefghijklmnopqrstuvwxyz', now(), '{"provider": "email", "providers": ["email"], "role": "admin"}', '{"display_name": "Admin User"}'),
  ('00000000-0000-0000-0000-000000000002', 'user@example.com', '$2a$10$abcdefghijklmnopqrstuvwxyz', now(), '{"provider": "email", "providers": ["email"]}', '{"display_name": "Regular User"}');

-- Insert profiles
INSERT INTO public.profiles (user_id, display_name, email, created_at)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'Admin User', 'admin@example.com', now()),
  ('00000000-0000-0000-0000-000000000002', 'Regular User', 'user@example.com', now());

-- Insert posts
INSERT INTO public.posts (id, title, content, author_id, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'First Post', 'This is the first post content.', '00000000-0000-0000-0000-000000000001', now(), now()),
  ('00000000-0000-0000-0000-000000000002', 'Second Post', 'This is the second post content.', '00000000-0000-0000-0000-000000000002', now(), now());
```

Apply seed data:

```bash
# Example: Apply seed data
supabase db reset --db-url postgresql://postgres:postgres@localhost:54322/postgres
```

### Environment Variables

Manage environment variables securely:

```bash
# Example: Set environment variables
supabase secrets set EXTERNAL_API_KEY=your-api-key SMTP_HOST=smtp.example.com

# Example: List environment variables
supabase secrets list
```

### Local Development

Set up local development environment:

```bash
# Example: Start local Supabase
supabase start

# Example: Stop local Supabase
supabase stop

# Example: Generate types
supabase gen types typescript --local > src/types/supabase.ts
```

### Deployment Validation

Implement deployment validation:

```typescript
// Example: validate-deployment.ts
import { createClient } from '@supabase/supabase-js';
import fetch from 'node-fetch';

async function validateDeployment() {
  try {
    console.log('Validating deployment...');

    // Create Supabase client
    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!supabaseUrl || !supabaseKey) {
      throw new Error('Missing Supabase credentials');
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Check database
    console.log('Checking database...');
    const { data: dbData, error: dbError } = await supabase
      .from('system')
      .upsert({
        key: 'deployment_check',
        value: {
          lastDeployment: new Date().toISOString(),
          status: 'online'
        }
      })
      .select();

    if (dbError) {
      throw new Error(`Database check failed: ${dbError.message}`);
    }

    // Check Edge Function
    console.log('Checking Edge Functions...');
    const functionUrl = `${supabaseUrl}/functions/v1/status`;
    const response = await fetch(functionUrl, {
      headers: {
        Authorization: `Bearer ${supabaseKey}`
      }
    });

    if (!response.ok) {
      throw new Error(`Function check failed: ${response.statusText}`);
    }

    const data = await response.json();
    if (data.status !== 'ok') {
      throw new Error(`Function status not ok: ${data.status}`);
    }

    // Check Storage
    console.log('Checking Storage...');
    const { error: storageError } = await supabase.storage
      .from('public')
      .upload('deployment-validation.txt', new Blob(['Deployment validation']), {
        contentType: 'text/plain',
        upsert: true
      });

    if (storageError) {
      throw new Error(`Storage check failed: ${storageError.message}`);
    }

    // Clean up
    await supabase.storage
      .from('public')
      .remove(['deployment-validation.txt']);

    console.log('Deployment validation successful!');
    process.exit(0);
  } catch (error) {
    console.error('Deployment validation failed:', error);
    process.exit(1);
  }
}

validateDeployment();
```

### Backup and Restore

Implement database backup and restore:

```bash
# Example: Backup database
supabase db dump -f backup.sql

# Example: Restore database
supabase db reset --db-url postgresql://postgres:postgres@localhost:54322/postgres
psql postgresql://postgres:postgres@localhost:54322/postgres -f backup.sql
```

## Error Handling

### Deployment Error Types

- **Configuration Errors**: Issues with environment configuration
- **Database Migration Errors**: Problems applying schema changes
- **Function Deployment Errors**: Issues deploying Edge Functions
- **Network Errors**: Connection issues affecting deployment
- **Permission Errors**: Insufficient privileges for deployment operations
- **Timeout Errors**: Operations exceeding time limits

### Error Handling Strategy

```typescript
// Example: Error handling in deployment script
async function deployToEnvironment(environment: string): Promise<void> {
  try {
    // Validate environment
    if (!['development', 'staging', 'production'].includes(environment)) {
      throw new DeploymentError('Invalid environment specified', 'CONFIGURATION_ERROR');
    }

    // Load environment configuration
    const config = loadEnvironmentConfig(environment);
    if (!config) {
      throw new DeploymentError(`Configuration not found for environment: ${environment}`, 'CONFIGURATION_ERROR');
    }

    // Deploy database migrations
    try {
      await deployMigrations(config);
    } catch (error) {
      throw new DeploymentError(
        `Database migration failed: ${error.message}`,
        'DATABASE_ERROR',
        error
      );
    }

    // Deploy Edge Functions
    try {
      await deployFunctions(config);
    } catch (error) {
      // Attempt to roll back migrations if function deployment fails
      try {
        await rollbackMigrations(config);
        console.log('Successfully rolled back migrations after function deployment failure');
      } catch (rollbackError) {
        console.error('Failed to roll back migrations:', rollbackError);
      }

      throw new DeploymentError(
        `Function deployment failed: ${error.message}`,
        'FUNCTION_ERROR',
        error
      );
    }

    // Validate deployment
    try {
      await validateDeployment(config);
    } catch (error) {
      throw new DeploymentError(
        `Deployment validation failed: ${error.message}`,
        'VALIDATION_ERROR',
        error
      );
    }

    console.log(`Successfully deployed to ${environment}`);
  } catch (error) {
    if (error instanceof DeploymentError) {
      console.error(`Deployment error [${error.code}]: ${error.message}`);
      // Log detailed error information for debugging
      if (error.originalError) {
        console.error('Original error:', error.originalError);
      }
    } else {
      console.error('Unexpected deployment error:', error);
    }
    process.exit(1);
  }
}

class DeploymentError extends Error {
  constructor(
    message: string,
    public code: string,
    public originalError?: any
  ) {
    super(message);
    this.name = 'DeploymentError';
  }
}
```

### Retry Mechanisms

```typescript
// Example: Retry utility with exponential backoff
async function withRetry<T>(
  operation: () => Promise<T>,
  options: {
    maxRetries?: number;
    initialDelay?: number;
    retryableErrors?: string[];
  } = {}
): Promise<T> {
  const {
    maxRetries = 3,
    initialDelay = 1000,
    retryableErrors = ['NETWORK_ERROR', 'TIMEOUT_ERROR']
  } = options;

  let lastError: Error;
  let retryCount = 0;

  while (retryCount <= maxRetries) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;

      // Only retry on specific error types
      if (error instanceof DeploymentError) {
        if (!retryableErrors.includes(error.code)) {
          throw error; // Don't retry permanent errors
        }
      } else {
        throw error; // Don't retry unknown errors
      }

      // Last retry attempt failed
      if (retryCount === maxRetries) {
        break;
      }

      // Exponential backoff with jitter
      const delay = initialDelay * Math.pow(2, retryCount) * (0.5 + Math.random() * 0.5);
      console.log(`Retrying operation in ${Math.round(delay / 1000)}s... (Attempt ${retryCount + 1}/${maxRetries})`);
      await new Promise(resolve => setTimeout(resolve, delay));
      retryCount++;
    }
  }

  throw lastError;
}
```

### Rollback Strategies

- Implement automatic rollback for failed migrations
- Create deployment snapshots for quick recovery
- Use database backups for critical failures
- Implement feature flags for controlled rollbacks
- Document manual rollback procedures

### Monitoring and Alerting

- Set up deployment status monitoring
- Configure alerts for failed deployments
- Implement detailed deployment logging
- Create deployment dashboards
- Set up error tracking for production issues

## Testing

### Deployment Testing Strategy

We implement a comprehensive testing strategy for deployments:

1. **Pre-deployment Testing**: Validate changes before deployment
2. **Migration Testing**: Test database migrations in isolation
3. **Function Testing**: Verify Edge Functions in test environment
4. **Integration Testing**: Test complete deployment in staging
5. **Smoke Testing**: Verify critical functionality after deployment

### Migration Testing

```typescript
// Example: Test database migrations
import { execSync } from 'child_process';
import { createClient } from '@supabase/supabase-js';

async function testMigrations() {
  try {
    // Start local Supabase instance
    execSync('supabase start', { stdio: 'inherit' });

    // Apply migrations
    execSync('supabase db reset', { stdio: 'inherit' });

    // Connect to local Supabase
    const supabase = createClient(
      'http://localhost:54321',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
    );

    // Verify schema changes
    const { data, error } = await supabase.rpc('test_migrations');

    if (error) {
      throw new Error(`Migration test failed: ${error.message}`);
    }

    console.log('Migration tests passed:', data);

    // Stop local Supabase instance
    execSync('supabase stop', { stdio: 'inherit' });
  } catch (error) {
    console.error('Migration test failed:', error);
    // Stop local Supabase instance even if tests fail
    try {
      execSync('supabase stop', { stdio: 'inherit' });
    } catch (stopError) {
      console.error('Failed to stop Supabase:', stopError);
    }
    process.exit(1);
  }
}

testMigrations();
```

### Function Testing

```typescript
// Example: Test Edge Functions
import { execSync } from 'child_process';
import fetch from 'node-fetch';

async function testFunctions() {
  try {
    // Start local Supabase instance
    execSync('supabase start', { stdio: 'inherit' });

    // Deploy functions to local instance
    execSync('supabase functions deploy --no-verify-jwt', { stdio: 'inherit' });

    // Test each function
    const functions = ['get-user-profile', 'update-user-profile'];

    for (const func of functions) {
      console.log(`Testing function: ${func}`);

      // Call the function
      const response = await fetch(`http://localhost:54321/functions/v1/${func}`, {
        method: 'GET',
        headers: {
          Authorization: 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
        }
      });

      if (!response.ok) {
        throw new Error(`Function ${func} test failed: ${response.statusText}`);
      }

      console.log(`Function ${func} test passed`);
    }

    // Stop local Supabase instance
    execSync('supabase stop', { stdio: 'inherit' });
  } catch (error) {
    console.error('Function test failed:', error);
    // Stop local Supabase instance even if tests fail
    try {
      execSync('supabase stop', { stdio: 'inherit' });
    } catch (stopError) {
      console.error('Failed to stop Supabase:', stopError);
    }
    process.exit(1);
  }
}

testFunctions();
```

### Integration Testing

```typescript
// Example: Integration test for deployment
import { execSync } from 'child_process';
import { createClient } from '@supabase/supabase-js';

async function testDeployment() {
  try {
    // Deploy to test environment
    execSync('npm run deploy:test', { stdio: 'inherit' });

    // Connect to test environment
    const supabaseUrl = process.env.TEST_SUPABASE_URL;
    const supabaseKey = process.env.TEST_SUPABASE_KEY;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Test database
    const { data: dbData, error: dbError } = await supabase
      .from('system')
      .select('*')
      .limit(1);

    if (dbError) {
      throw new Error(`Database test failed: ${dbError.message}`);
    }

    // Test functions
    const { data: funcData, error: funcError } = await supabase
      .functions
      .invoke('status');

    if (funcError) {
      throw new Error(`Function test failed: ${funcError.message}`);
    }

    console.log('Deployment integration tests passed');
  } catch (error) {
    console.error('Deployment integration test failed:', error);
    process.exit(1);
  }
}

testDeployment();
```

## Best Practices

* Use separate Supabase projects for each environment
* Implement CI/CD for automated deployments
* Use environment variables for configuration
* Validate deployments after they complete
* Implement regular database backups
* Use migrations for schema changes
* Document deployment procedures
* Secure deployment credentials
* Test deployments in local environment before production
* Implement proper error handling in Edge Functions
* Use feature flags for controlled rollouts
* Implement blue-green deployments when possible

## Anti-patterns

* Manual deployments to production
* Sharing Supabase projects between environments
* Hardcoding environment-specific values
* No deployment validation
* No backup strategy
* Direct database modifications in production
* Insufficient logging during deployment
* No staging environment
* Deploying without testing
* Exposing sensitive credentials in repositories
* Deploying during high-traffic periods
* Not monitoring deployments after completion