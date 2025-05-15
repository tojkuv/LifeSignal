# Deployment

> **Note:** As this is an MVP, the deployment process may evolve as the project matures.

## Deployment Environments

LifeSignal uses multiple environments for development, testing, and production:

1. **Local Development** - For individual developer work
2. **Development** - For integration testing
3. **Staging** - For pre-production testing
4. **Production** - For live application

## Firebase Projects

Each environment has its own Firebase project:

1. **lifesignal-dev** - Development environment
2. **lifesignal-staging** - Staging environment
3. **lifesignal-prod** - Production environment

## Deployment Process

### 1. Local Development

Developers work with Firebase emulators for local development:

```bash
# Start Firebase emulators
firebase emulators:start

# Deploy to local emulators
firebase deploy --only functions --project demo
```

### 2. Development Environment

Changes are deployed to the development environment for integration testing:

```bash
# Deploy to development
firebase deploy --only functions --project lifesignal-dev
```

### 3. Staging Environment

After testing in development, changes are deployed to staging for pre-production testing:

```bash
# Deploy to staging
firebase deploy --only functions --project lifesignal-staging
```

### 4. Production Environment

After validation in staging, changes are deployed to production:

```bash
# Deploy to production
firebase deploy --only functions --project lifesignal-prod
```

## Continuous Integration/Continuous Deployment (CI/CD)

LifeSignal uses GitHub Actions for CI/CD:

### 1. Pull Request Workflow

```yaml
# .github/workflows/pull-request.yml
name: Pull Request

on:
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Set up Node.js
      uses: actions/setup-node@v2
      with:
        node-version: '16'
    
    - name: Install dependencies
      run: npm ci
      working-directory: ./functions
    
    - name: Lint
      run: npm run lint
      working-directory: ./functions
    
    - name: Start Firebase emulators
      run: npm run emulators:start &
      working-directory: ./functions
    
    - name: Wait for emulators
      run: sleep 10
    
    - name: Run tests
      run: npm test
      working-directory: ./functions
    
    - name: Upload coverage
      uses: codecov/codecov-action@v2
      with:
        directory: ./functions/coverage
```

### 2. Development Deployment Workflow

```yaml
# .github/workflows/deploy-dev.yml
name: Deploy to Development

on:
  push:
    branches: [ main ]

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
      working-directory: ./functions
    
    - name: Lint
      run: npm run lint
      working-directory: ./functions
    
    - name: Run tests
      run: npm test
      working-directory: ./functions
    
    - name: Deploy to Firebase
      uses: w9jds/firebase-action@master
      with:
        args: deploy --only functions --project lifesignal-dev
      env:
        FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

### 3. Staging Deployment Workflow

```yaml
# .github/workflows/deploy-staging.yml
name: Deploy to Staging

on:
  workflow_dispatch:
  push:
    tags:
      - 'v*-rc*'

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
      working-directory: ./functions
    
    - name: Lint
      run: npm run lint
      working-directory: ./functions
    
    - name: Run tests
      run: npm test
      working-directory: ./functions
    
    - name: Deploy to Firebase
      uses: w9jds/firebase-action@master
      with:
        args: deploy --only functions --project lifesignal-staging
      env:
        FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

### 4. Production Deployment Workflow

```yaml
# .github/workflows/deploy-prod.yml
name: Deploy to Production

on:
  workflow_dispatch:
  push:
    tags:
      - 'v*'
      - '!v*-rc*'

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
      working-directory: ./functions
    
    - name: Lint
      run: npm run lint
      working-directory: ./functions
    
    - name: Run tests
      run: npm test
      working-directory: ./functions
    
    - name: Deploy to Firebase
      uses: w9jds/firebase-action@master
      with:
        args: deploy --only functions --project lifesignal-prod
      env:
        FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

## Environment Configuration

Each environment has its own configuration:

### 1. Firebase Functions Configuration

```typescript
// functions/src/config.ts
import * as functions from 'firebase-functions';

interface Config {
  notificationEnabled: boolean;
  checkInReminderInterval: number; // in minutes
  pingExpirationTime: number; // in hours
  maxPingsPerDay: number;
}

const defaultConfig: Config = {
  notificationEnabled: true,
  checkInReminderInterval: 15,
  pingExpirationTime: 24,
  maxPingsPerDay: 10
};

// Get environment-specific configuration
export const getConfig = (): Config => {
  const environment = process.env.FUNCTIONS_EMULATOR ? 'local' : 
                      process.env.GCLOUD_PROJECT === 'lifesignal-prod' ? 'production' :
                      process.env.GCLOUD_PROJECT === 'lifesignal-staging' ? 'staging' : 'development';
  
  // Get configuration from Firebase Functions config
  const config = functions.config();
  
  // Merge with default config
  return {
    ...defaultConfig,
    ...(config.app || {})
  };
};
```

### 2. Setting Environment Variables

```bash
# Set configuration for development
firebase functions:config:set app.notificationEnabled=true app.checkInReminderInterval=15 --project lifesignal-dev

# Set configuration for staging
firebase functions:config:set app.notificationEnabled=true app.checkInReminderInterval=15 --project lifesignal-staging

# Set configuration for production
firebase functions:config:set app.notificationEnabled=true app.checkInReminderInterval=15 --project lifesignal-prod
```

## Deployment Verification

After deployment, verify that the functions are working correctly:

### 1. Automated Smoke Tests

```typescript
// scripts/smoke-test.js
const admin = require('firebase-admin');
const axios = require('axios');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Get Firebase Functions base URL
const getBaseUrl = () => {
  const project = process.env.FIREBASE_PROJECT || 'lifesignal-dev';
  const region = 'us-central1';
  return `https://${region}-${project}.cloudfunctions.net`;
};

// Run smoke tests
const runSmokeTests = async () => {
  const baseUrl = getBaseUrl();
  
  try {
    // Test HTTPS callable function
    const addContactResult = await axios.post(`${baseUrl}/addContactRelation`, {
      data: {
        qrCodeId: 'test-qr-code'
      }
    }, {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.ID_TOKEN}`
      }
    });
    
    console.log('addContactRelation test:', addContactResult.status === 200 ? 'PASS' : 'FAIL');
    
    // Test Firestore trigger
    const db = admin.firestore();
    await db.collection('users').doc('test-user').update({
      lastCheckedIn: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('Firestore trigger test: PASS');
    
    // Test scheduled function
    const sendCheckInRemindersResult = await axios.get(`${baseUrl}/sendCheckInReminders`);
    
    console.log('sendCheckInReminders test:', sendCheckInRemindersResult.status === 200 ? 'PASS' : 'FAIL');
    
    console.log('All smoke tests passed!');
  } catch (error) {
    console.error('Smoke test failed:', error);
    process.exit(1);
  }
};

runSmokeTests();
```

### 2. Manual Verification

1. Check Firebase Console to verify functions are deployed
2. Test critical functions manually
3. Monitor logs for errors

## Rollback Procedure

If issues are detected after deployment, roll back to the previous version:

```bash
# Get the previous deployment
firebase functions:list --project lifesignal-prod

# Roll back to a specific version
firebase functions:rollback --project lifesignal-prod
```

## Monitoring and Alerting

Set up monitoring and alerting for production:

### 1. Firebase Monitoring

- Set up Firebase Monitoring in the Firebase Console
- Configure alerts for function errors and performance issues

### 2. Google Cloud Monitoring

- Set up Google Cloud Monitoring for more advanced monitoring
- Create dashboards for key metrics
- Configure alerts for critical issues

### 3. Error Reporting

- Set up Error Reporting in the Google Cloud Console
- Configure notifications for new errors

## Deployment Schedule

- **Development**: Continuous deployment on merge to main branch
- **Staging**: Weekly deployment for testing
- **Production**: Bi-weekly deployment after validation in staging

## Deployment Checklist

Before deploying to production, verify:

1. All tests pass
2. Code has been reviewed
3. Changes have been tested in staging
4. Documentation has been updated
5. Release notes have been prepared
6. Rollback plan is in place

## Deployment Documentation

For each production deployment, document:

1. Version number
2. Changes included
3. Known issues
4. Rollback instructions
5. Verification steps
