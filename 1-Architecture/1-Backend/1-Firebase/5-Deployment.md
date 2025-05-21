# Firebase Deployment

## Purpose

This document outlines the deployment architecture, strategies, and best practices for deploying Firebase applications.

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

Each environment has its own Firebase project:

```
environments/
├── development/
│   ├── .firebaserc
│   └── firebase.json
├── staging/
│   ├── .firebaserc
│   └── firebase.json
└── production/
    ├── .firebaserc
    └── firebase.json
```

#### Environment Configuration

Each environment has specific configuration:

```json
// Example: .firebaserc for development
{
  "projects": {
    "default": "app-name-dev"
  },
  "targets": {
    "app-name-dev": {
      "hosting": {
        "app": [
          "app-name-dev"
        ],
        "admin": [
          "app-name-admin-dev"
        ]
      }
    }
  }
}
```

```json
// Example: firebase.json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": {
    "predeploy": [
      "npm --prefix \"$RESOURCE_DIR\" run lint",
      "npm --prefix \"$RESOURCE_DIR\" run build"
    ],
    "source": "functions"
  },
  "hosting": [
    {
      "target": "app",
      "public": "dist/app",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
      ],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ]
    },
    {
      "target": "admin",
      "public": "dist/admin",
      "ignore": [
        "firebase.json",
        "**/.*",
        "**/node_modules/**"
      ],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ]
    }
  ],
  "storage": {
    "rules": "storage.rules"
  },
  "emulators": {
    "auth": {
      "port": 9099
    },
    "functions": {
      "port": 5001
    },
    "firestore": {
      "port": 8080
    },
    "hosting": {
      "port": 5000
    },
    "storage": {
      "port": 9199
    },
    "ui": {
      "enabled": true
    }
  }
}
```

### CI/CD Pipeline

#### Pipeline Structure

Our CI/CD pipeline follows these stages:

1. **Build**: Compile and build the application
2. **Test**: Run unit and integration tests
3. **Deploy**: Deploy to the appropriate environment

```yaml
# Example: GitHub Actions workflow
name: Deploy to Firebase

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

      - name: Deploy to Firebase
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          projectId: app-name-${{ steps.set-env.outputs.environment }}
          channelId: live
```

#### Deployment Scripts

Create deployment scripts for consistent deployment:

```typescript
// Example: deploy.ts
import * as childProcess from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

// Environment configuration
const environments = {
  development: {
    projectId: 'app-name-dev',
    functionsNodeEnv: 'development'
  },
  staging: {
    projectId: 'app-name-staging',
    functionsNodeEnv: 'staging'
  },
  production: {
    projectId: 'app-name-prod',
    functionsNodeEnv: 'production'
  }
};

// Get environment from command line
const envArg = process.argv[2];
if (!envArg || !environments[envArg]) {
  console.error(`Please specify a valid environment: ${Object.keys(environments).join(', ')}`);
  process.exit(1);
}

const env = environments[envArg];

// Set environment variables
process.env.FIREBASE_PROJECT_ID = env.projectId;
process.env.NODE_ENV = env.functionsNodeEnv;

// Deploy to Firebase
console.log(`Deploying to ${envArg} environment (${env.projectId})...`);

try {
  // Run deployment command
  childProcess.execSync(`firebase use ${env.projectId} && firebase deploy`, {
    stdio: 'inherit'
  });

  console.log(`Successfully deployed to ${envArg} environment!`);
} catch (error) {
  console.error(`Deployment failed: ${error.message}`);
  process.exit(1);
}
```

### Environment Variables

Manage environment variables securely:

```typescript
// Example: environment.ts
export interface Environment {
  firebase: {
    apiKey: string;
    authDomain: string;
    projectId: string;
    storageBucket: string;
    messagingSenderId: string;
    appId: string;
    measurementId?: string;
  };
  apiUrl: string;
  logLevel: 'debug' | 'info' | 'warn' | 'error';
}

// Load environment variables from .env files
import * as dotenv from 'dotenv';

// Load base .env file
dotenv.config();

// Load environment-specific .env file
const nodeEnv = process.env.NODE_ENV || 'development';
dotenv.config({ path: `.env.${nodeEnv}` });

// Create environment configuration
export const environment: Environment = {
  firebase: {
    apiKey: process.env.FIREBASE_API_KEY!,
    authDomain: process.env.FIREBASE_AUTH_DOMAIN!,
    projectId: process.env.FIREBASE_PROJECT_ID!,
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET!,
    messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID!,
    appId: process.env.FIREBASE_APP_ID!,
    measurementId: process.env.FIREBASE_MEASUREMENT_ID
  },
  apiUrl: process.env.API_URL!,
  logLevel: (process.env.LOG_LEVEL as Environment['logLevel']) || 'info'
};

// Validate environment configuration
const requiredEnvVars = [
  'FIREBASE_API_KEY',
  'FIREBASE_AUTH_DOMAIN',
  'FIREBASE_PROJECT_ID',
  'FIREBASE_STORAGE_BUCKET',
  'FIREBASE_MESSAGING_SENDER_ID',
  'FIREBASE_APP_ID',
  'API_URL'
];

const missingEnvVars = requiredEnvVars.filter(varName => !process.env[varName]);

if (missingEnvVars.length > 0) {
  throw new Error(`Missing required environment variables: ${missingEnvVars.join(', ')}`);
}
```

### Deployment Validation

Implement deployment validation:

```typescript
// Example: validate-deployment.ts
import * as admin from 'firebase-admin';
import * as fetch from 'node-fetch';

// Initialize Firebase Admin
admin.initializeApp();

async function validateDeployment() {
  try {
    console.log('Validating deployment...');

    // Check Firestore
    console.log('Checking Firestore...');
    const db = admin.firestore();
    await db.collection('system').doc('status').set({
      lastDeployment: admin.firestore.FieldValue.serverTimestamp(),
      status: 'online'
    });

    // Check Functions
    console.log('Checking Cloud Functions...');
    const functionsUrl = `https://${process.env.FIREBASE_REGION}-${process.env.FIREBASE_PROJECT_ID}.cloudfunctions.net/api/status`;
    const response = await fetch(functionsUrl);

    if (!response.ok) {
      throw new Error(`Functions check failed: ${response.statusText}`);
    }

    const data = await response.json();
    if (data.status !== 'ok') {
      throw new Error(`Functions status not ok: ${data.status}`);
    }

    // Check Storage
    console.log('Checking Storage...');
    const bucket = admin.storage().bucket();
    const file = bucket.file('deployment-validation.txt');

    await file.save('Deployment validation', {
      contentType: 'text/plain'
    });

    await file.delete();

    console.log('Deployment validation successful!');
    process.exit(0);
  } catch (error) {
    console.error('Deployment validation failed:', error);
    process.exit(1);
  }
}

validateDeployment();
```

### Rollback Strategy

Implement deployment rollback:

```typescript
// Example: rollback.ts
import * as childProcess from 'child_process';

// Get environment and version from command line
const [envArg, versionArg] = process.argv.slice(2);

if (!envArg) {
  console.error('Please specify an environment');
  process.exit(1);
}

if (!versionArg) {
  console.error('Please specify a version to roll back to');
  process.exit(1);
}

// Set environment variables
const projectId = `app-name-${envArg === 'prod' ? 'prod' : envArg}`;

console.log(`Rolling back ${envArg} to version ${versionArg}...`);

try {
  // Roll back hosting
  childProcess.execSync(
    `firebase hosting:clone ${projectId}:${versionArg} ${projectId}:live`,
    { stdio: 'inherit' }
  );

  console.log(`Successfully rolled back ${envArg} to version ${versionArg}!`);
} catch (error) {
  console.error(`Rollback failed: ${error.message}`);
  process.exit(1);
}
```

## Error Handling

- Implement proper error handling in deployment scripts
- Create detailed error logs for deployment failures
- Implement automatic rollback on deployment failure
- Handle timeouts and network issues gracefully
- Provide clear error messages for common deployment issues
- Implement retry mechanisms for transient failures

## Testing

- Test deployments in isolated environments
- Verify all services after deployment
- Implement smoke tests for critical functionality
- Test rollback procedures regularly
- Verify security rules after deployment
- Test performance after deployment

## Best Practices

* Use separate Firebase projects for each environment
* Implement CI/CD for automated deployments
* Use environment variables for configuration
* Validate deployments after they complete
* Implement rollback strategies
* Use feature flags for controlled rollouts
* Monitor deployments with alerts
* Document deployment procedures
* Secure deployment credentials
* Test deployments in emulators before production
* Implement blue-green deployments for zero downtime
* Use canary releases for gradual rollouts

## Anti-patterns

* Manual deployments to production
* Sharing Firebase projects between environments
* Hardcoding environment-specific values
* No deployment validation
* No rollback strategy
* Direct database modifications in production
* Insufficient logging during deployment
* No staging environment
* Deploying without testing
* Exposing sensitive credentials in repositories
* Deploying during high-traffic periods
* Not monitoring deployments after completion