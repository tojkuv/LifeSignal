# Database Query Example

**Navigation:** [Back to Examples](README.md) | [Cloud Function Example](CloudFunctionExample.md) | [Security Rule Example](SecurityRuleExample.md)

---

## Overview

This document provides a comprehensive example of database query implementation for the LifeSignal application. The example demonstrates best practices for query implementation, including query optimization, index management, error handling, and testing.

## Query Examples

### Firestore Queries

#### 1. Get User Profile

```typescript
/**
 * Gets a user profile by user ID
 * 
 * @param userId - The ID of the user
 * @returns The user profile document
 * @throws Error if the user profile is not found
 */
async function getUserProfile(userId: string): Promise<UserProfile> {
  try {
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      throw new Error(`User profile not found for ID: ${userId}`);
    }
    
    return userDoc.data() as UserProfile;
  } catch (error) {
    console.error(`Error getting user profile for ${userId}:`, error);
    throw error;
  }
}
```

#### 2. Get User Contacts

```typescript
/**
 * Gets all contacts for a user
 * 
 * @param userId - The ID of the user
 * @returns Array of contact documents with user profile data
 */
async function getUserContacts(userId: string): Promise<Array<ContactWithProfile>> {
  try {
    const db = admin.firestore();
    const contactsSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('contacts')
      .get();
    
    if (contactsSnapshot.empty) {
      return [];
    }
    
    // Get all contact documents
    const contacts = contactsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    // Get user profiles for all contacts
    const contactProfiles = await Promise.all(
      contacts.map(async contact => {
        // Extract user ID from reference path
        const contactId = contact.id;
        
        try {
          const userDoc = await db.collection('users').doc(contactId).get();
          
          if (!userDoc.exists) {
            console.warn(`Contact user profile not found for ID: ${contactId}`);
            return {
              ...contact,
              profile: null
            };
          }
          
          return {
            ...contact,
            profile: userDoc.data() as UserProfile
          };
        } catch (error) {
          console.error(`Error getting profile for contact ${contactId}:`, error);
          return {
            ...contact,
            profile: null
          };
        }
      })
    );
    
    return contactProfiles;
  } catch (error) {
    console.error(`Error getting contacts for user ${userId}:`, error);
    throw error;
  }
}
```

#### 3. Get Responders for User

```typescript
/**
 * Gets all responders for a user
 * 
 * @param userId - The ID of the user
 * @returns Array of responder documents with user profile data
 */
async function getUserResponders(userId: string): Promise<Array<ContactWithProfile>> {
  try {
    const db = admin.firestore();
    const respondersSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('contacts')
      .where('isResponder', '==', true)
      .get();
    
    if (respondersSnapshot.empty) {
      return [];
    }
    
    // Get all responder documents
    const responders = respondersSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    // Get user profiles for all responders
    const responderProfiles = await Promise.all(
      responders.map(async responder => {
        // Extract user ID from reference path
        const responderId = responder.id;
        
        try {
          const userDoc = await db.collection('users').doc(responderId).get();
          
          if (!userDoc.exists) {
            console.warn(`Responder user profile not found for ID: ${responderId}`);
            return {
              ...responder,
              profile: null
            };
          }
          
          return {
            ...responder,
            profile: userDoc.data() as UserProfile
          };
        } catch (error) {
          console.error(`Error getting profile for responder ${responderId}:`, error);
          return {
            ...responder,
            profile: null
          };
        }
      })
    );
    
    return responderProfiles;
  } catch (error) {
    console.error(`Error getting responders for user ${userId}:`, error);
    throw error;
  }
}
```

#### 4. Get Dependents for User

```typescript
/**
 * Gets all dependents for a user
 * 
 * @param userId - The ID of the user
 * @returns Array of dependent documents with user profile data
 */
async function getUserDependents(userId: string): Promise<Array<ContactWithProfile>> {
  try {
    const db = admin.firestore();
    const dependentsSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('contacts')
      .where('isDependent', '==', true)
      .get();
    
    if (dependentsSnapshot.empty) {
      return [];
    }
    
    // Get all dependent documents
    const dependents = dependentsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    // Get user profiles for all dependents
    const dependentProfiles = await Promise.all(
      dependents.map(async dependent => {
        // Extract user ID from reference path
        const dependentId = dependent.id;
        
        try {
          const userDoc = await db.collection('users').doc(dependentId).get();
          
          if (!userDoc.exists) {
            console.warn(`Dependent user profile not found for ID: ${dependentId}`);
            return {
              ...dependent,
              profile: null
            };
          }
          
          return {
            ...dependent,
            profile: userDoc.data() as UserProfile
          };
        } catch (error) {
          console.error(`Error getting profile for dependent ${dependentId}:`, error);
          return {
            ...dependent,
            profile: null
          };
        }
      })
    );
    
    return dependentProfiles;
  } catch (error) {
    console.error(`Error getting dependents for user ${userId}:`, error);
    throw error;
  }
}
```

#### 5. Get Users with Expiring Check-ins

```typescript
/**
 * Gets all users whose check-in is about to expire
 * 
 * @param minutesBeforeExpiry - Minutes before expiry to include
 * @returns Array of user documents with expiration information
 */
async function getUsersWithExpiringCheckIns(minutesBeforeExpiry: number): Promise<Array<UserWithExpiry>> {
  try {
    const db = admin.firestore();
    
    // Calculate the time range for expiring check-ins
    const now = admin.firestore.Timestamp.now();
    const expiryThreshold = new Date(now.toMillis() + (minutesBeforeExpiry * 60 * 1000));
    const expiryThresholdTimestamp = admin.firestore.Timestamp.fromDate(expiryThreshold);
    
    // Query users whose check-in is about to expire
    const usersSnapshot = await db
      .collection('users')
      .where('expirationTimestamp', '>', now)
      .where('expirationTimestamp', '<=', expiryThresholdTimestamp)
      .get();
    
    if (usersSnapshot.empty) {
      return [];
    }
    
    // Get all user documents
    const users = usersSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      minutesToExpiry: Math.floor((doc.data().expirationTimestamp.toMillis() - now.toMillis()) / (60 * 1000))
    }));
    
    return users;
  } catch (error) {
    console.error(`Error getting users with expiring check-ins:`, error);
    throw error;
  }
}
```

#### 6. Get Users with Expired Check-ins

```typescript
/**
 * Gets all users whose check-in has expired
 * 
 * @returns Array of user documents with expiration information
 */
async function getUsersWithExpiredCheckIns(): Promise<Array<UserWithExpiry>> {
  try {
    const db = admin.firestore();
    
    // Calculate the time for expired check-ins
    const now = admin.firestore.Timestamp.now();
    
    // Query users whose check-in has expired
    const usersSnapshot = await db
      .collection('users')
      .where('expirationTimestamp', '<', now)
      .get();
    
    if (usersSnapshot.empty) {
      return [];
    }
    
    // Get all user documents
    const users = usersSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      minutesSinceExpiry: Math.floor((now.toMillis() - doc.data().expirationTimestamp.toMillis()) / (60 * 1000))
    }));
    
    return users;
  } catch (error) {
    console.error(`Error getting users with expired check-ins:`, error);
    throw error;
  }
}
```

#### 7. Get User by QR Code ID

```typescript
/**
 * Gets a user by QR code ID
 * 
 * @param qrCodeId - The QR code ID
 * @returns The user document or null if not found
 */
async function getUserByQRCodeId(qrCodeId: string): Promise<UserProfile | null> {
  try {
    const db = admin.firestore();
    
    // Query users by QR code ID
    const usersSnapshot = await db
      .collection('users')
      .where('qrCodeId', '==', qrCodeId)
      .limit(1)
      .get();
    
    if (usersSnapshot.empty) {
      return null;
    }
    
    // Get the user document
    const userDoc = usersSnapshot.docs[0];
    
    return {
      id: userDoc.id,
      ...userDoc.data()
    } as UserProfile;
  } catch (error) {
    console.error(`Error getting user by QR code ID ${qrCodeId}:`, error);
    throw error;
  }
}
```

#### 8. Get Contacts with Active Pings

```typescript
/**
 * Gets all contacts with active pings for a user
 * 
 * @param userId - The ID of the user
 * @returns Array of contact documents with active pings
 */
async function getContactsWithActivePings(userId: string): Promise<Array<ContactReference>> {
  try {
    const db = admin.firestore();
    
    // Query contacts with active pings
    const contactsSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('contacts')
      .where('incomingPingTimestamp', '!=', null)
      .get();
    
    if (contactsSnapshot.empty) {
      return [];
    }
    
    // Get all contact documents
    const contacts = contactsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    return contacts;
  } catch (error) {
    console.error(`Error getting contacts with active pings for user ${userId}:`, error);
    throw error;
  }
}
```

### Supabase Queries

#### 1. Get User Profile

```typescript
/**
 * Gets a user profile by user ID
 * 
 * @param userId - The ID of the user
 * @returns The user profile or null if not found
 */
async function getUserProfile(userId: string): Promise<UserProfile | null> {
  try {
    const { data, error } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('user_id', userId)
      .single();
    
    if (error) {
      if (error.code === 'PGRST116') {
        // No rows returned
        return null;
      }
      throw error;
    }
    
    return data;
  } catch (error) {
    console.error(`Error getting user profile for ${userId}:`, error);
    throw error;
  }
}
```

#### 2. Get User Contacts

```typescript
/**
 * Gets all contacts for a user with their profiles
 * 
 * @param userId - The ID of the user
 * @returns Array of contact records with user profile data
 */
async function getUserContacts(userId: string): Promise<Array<ContactWithProfile>> {
  try {
    // Get contacts with join to user profiles
    const { data, error } = await supabase
      .from('contacts')
      .select(`
        *,
        contact_profile:user_profiles!contacts_contact_id_fkey(*)
      `)
      .eq('user_id', userId);
    
    if (error) {
      throw error;
    }
    
    return data || [];
  } catch (error) {
    console.error(`Error getting contacts for user ${userId}:`, error);
    throw error;
  }
}
```

#### 3. Get Responders for User

```typescript
/**
 * Gets all responders for a user with their profiles
 * 
 * @param userId - The ID of the user
 * @returns Array of responder records with user profile data
 */
async function getUserResponders(userId: string): Promise<Array<ContactWithProfile>> {
  try {
    // Get responders with join to user profiles
    const { data, error } = await supabase
      .from('contacts')
      .select(`
        *,
        contact_profile:user_profiles!contacts_contact_id_fkey(*)
      `)
      .eq('user_id', userId)
      .eq('is_responder', true);
    
    if (error) {
      throw error;
    }
    
    return data || [];
  } catch (error) {
    console.error(`Error getting responders for user ${userId}:`, error);
    throw error;
  }
}
```

#### 4. Get Dependents for User

```typescript
/**
 * Gets all dependents for a user with their profiles
 * 
 * @param userId - The ID of the user
 * @returns Array of dependent records with user profile data
 */
async function getUserDependents(userId: string): Promise<Array<ContactWithProfile>> {
  try {
    // Get dependents with join to user profiles
    const { data, error } = await supabase
      .from('contacts')
      .select(`
        *,
        contact_profile:user_profiles!contacts_contact_id_fkey(*)
      `)
      .eq('user_id', userId)
      .eq('is_dependent', true);
    
    if (error) {
      throw error;
    }
    
    return data || [];
  } catch (error) {
    console.error(`Error getting dependents for user ${userId}:`, error);
    throw error;
  }
}
```

#### 5. Get Users with Expiring Check-ins

```typescript
/**
 * Gets all users whose check-in is about to expire
 * 
 * @param minutesBeforeExpiry - Minutes before expiry to include
 * @returns Array of user records with expiration information
 */
async function getUsersWithExpiringCheckIns(minutesBeforeExpiry: number): Promise<Array<UserWithExpiry>> {
  try {
    const now = new Date();
    const expiryThreshold = new Date(now.getTime() + (minutesBeforeExpiry * 60 * 1000));
    
    // Query users whose check-in is about to expire
    const { data, error } = await supabase
      .from('user_profiles')
      .select('*')
      .gt('expiration_timestamp', now.toISOString())
      .lte('expiration_timestamp', expiryThreshold.toISOString());
    
    if (error) {
      throw error;
    }
    
    // Calculate minutes to expiry for each user
    const usersWithExpiry = (data || []).map(user => {
      const expiryTime = new Date(user.expiration_timestamp).getTime();
      const minutesToExpiry = Math.floor((expiryTime - now.getTime()) / (60 * 1000));
      
      return {
        ...user,
        minutesToExpiry
      };
    });
    
    return usersWithExpiry;
  } catch (error) {
    console.error(`Error getting users with expiring check-ins:`, error);
    throw error;
  }
}
```

## Query Optimization

### Firestore Indexes

```javascript
{
  "indexes": [
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "expirationTimestamp", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "contacts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "isResponder", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "contacts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "isDependent", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "contacts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "incomingPingTimestamp", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "qrCodeId", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "expirationTimestamp", "order": "ASCENDING" },
        { "fieldPath": "notify30MinBefore", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "expirationTimestamp", "order": "ASCENDING" },
        { "fieldPath": "notify2HoursBefore", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

### Supabase Indexes

```sql
-- Index for user_profiles table
CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX idx_user_profiles_expiration_timestamp ON user_profiles(expiration_timestamp);
CREATE INDEX idx_user_profiles_qr_code_id ON user_profiles(qr_code_id);

-- Index for contacts table
CREATE INDEX idx_contacts_user_id ON contacts(user_id);
CREATE INDEX idx_contacts_contact_id ON contacts(contact_id);
CREATE INDEX idx_contacts_user_id_is_responder ON contacts(user_id, is_responder);
CREATE INDEX idx_contacts_user_id_is_dependent ON contacts(user_id, is_dependent);
CREATE INDEX idx_contacts_user_id_incoming_ping_timestamp ON contacts(user_id, incoming_ping_timestamp) 
  WHERE incoming_ping_timestamp IS NOT NULL;
```

## Testing Queries

### Firestore Query Testing

```typescript
import * as admin from 'firebase-admin';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

// Initialize Firebase Admin SDK
initializeApp({
  projectId: 'lifesignal-test'
});

const db = getFirestore();

describe('Firestore Queries', () => {
  // Test data
  const userId = 'test-user-1';
  const contactId = 'test-user-2';
  
  // Setup test data
  beforeAll(async () => {
    // Create test users
    await db.collection('users').doc(userId).set({
      name: 'Test User 1',
      phone: '+15551234567',
      note: 'Test note',
      checkInInterval: 86400,
      lastCheckedIn: admin.firestore.Timestamp.now(),
      expirationTimestamp: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 30 * 60 * 1000) // 30 minutes from now
      ),
      notify30MinBefore: true,
      notify2HoursBefore: true
    });
    
    await db.collection('users').doc(contactId).set({
      name: 'Test User 2',
      phone: '+15557654321',
      note: 'Test note',
      checkInInterval: 86400,
      lastCheckedIn: admin.firestore.Timestamp.now(),
      expirationTimestamp: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 60 * 60 * 1000) // 1 hour from now
      ),
      notify30MinBefore: true,
      notify2HoursBefore: true
    });
    
    // Create contact relationship
    await db.collection('users').doc(userId).collection('contacts').doc(contactId).set({
      isResponder: true,
      isDependent: false,
      referencePath: `users/${contactId}`,
      sendPings: true,
      receivePings: true,
      notifyOnCheckIn: true,
      notifyOnExpiry: true,
      lastUpdated: admin.firestore.Timestamp.now(),
      addedAt: admin.firestore.Timestamp.now()
    });
    
    await db.collection('users').doc(contactId).collection('contacts').doc(userId).set({
      isResponder: false,
      isDependent: true,
      referencePath: `users/${userId}`,
      sendPings: true,
      receivePings: true,
      notifyOnCheckIn: false,
      notifyOnExpiry: false,
      lastUpdated: admin.firestore.Timestamp.now(),
      addedAt: admin.firestore.Timestamp.now()
    });
  });
  
  // Clean up test data
  afterAll(async () => {
    // Delete contact relationship
    await db.collection('users').doc(userId).collection('contacts').doc(contactId).delete();
    await db.collection('users').doc(contactId).collection('contacts').doc(userId).delete();
    
    // Delete test users
    await db.collection('users').doc(userId).delete();
    await db.collection('users').doc(contactId).delete();
  });
  
  test('getUserProfile returns the correct user profile', async () => {
    const userProfile = await getUserProfile(userId);
    
    expect(userProfile).toBeDefined();
    expect(userProfile.name).toBe('Test User 1');
    expect(userProfile.phone).toBe('+15551234567');
  });
  
  test('getUserContacts returns all contacts for a user', async () => {
    const contacts = await getUserContacts(userId);
    
    expect(contacts).toHaveLength(1);
    expect(contacts[0].id).toBe(contactId);
    expect(contacts[0].isResponder).toBe(true);
    expect(contacts[0].isDependent).toBe(false);
    expect(contacts[0].profile).toBeDefined();
    expect(contacts[0].profile.name).toBe('Test User 2');
  });
  
  test('getUserResponders returns responders for a user', async () => {
    const responders = await getUserResponders(userId);
    
    expect(responders).toHaveLength(1);
    expect(responders[0].id).toBe(contactId);
    expect(responders[0].isResponder).toBe(true);
    expect(responders[0].profile).toBeDefined();
    expect(responders[0].profile.name).toBe('Test User 2');
  });
  
  test('getUserDependents returns dependents for a user', async () => {
    const dependents = await getUserDependents(contactId);
    
    expect(dependents).toHaveLength(1);
    expect(dependents[0].id).toBe(userId);
    expect(dependents[0].isDependent).toBe(true);
    expect(dependents[0].profile).toBeDefined();
    expect(dependents[0].profile.name).toBe('Test User 1');
  });
  
  test('getUsersWithExpiringCheckIns returns users with expiring check-ins', async () => {
    const users = await getUsersWithExpiringCheckIns(60);
    
    expect(users.length).toBeGreaterThan(0);
    expect(users.some(user => user.id === userId)).toBe(true);
  });
});
```

### Supabase Query Testing

```typescript
import { createClient } from '@supabase/supabase-js';

// Initialize Supabase client
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

describe('Supabase Queries', () => {
  // Test data
  const userId = 'test-user-1';
  const contactId = 'test-user-2';
  
  // Setup test data
  beforeAll(async () => {
    // Create test users
    await supabase.from('user_profiles').insert([
      {
        user_id: userId,
        name: 'Test User 1',
        phone: '+15551234567',
        note: 'Test note',
        check_in_interval: 86400,
        last_checked_in: new Date().toISOString(),
        expiration_timestamp: new Date(Date.now() + 30 * 60 * 1000).toISOString(), // 30 minutes from now
        notify_30_min_before: true,
        notify_2_hours_before: true
      },
      {
        user_id: contactId,
        name: 'Test User 2',
        phone: '+15557654321',
        note: 'Test note',
        check_in_interval: 86400,
        last_checked_in: new Date().toISOString(),
        expiration_timestamp: new Date(Date.now() + 60 * 60 * 1000).toISOString(), // 1 hour from now
        notify_30_min_before: true,
        notify_2_hours_before: true
      }
    ]);
    
    // Create contact relationship
    await supabase.from('contacts').insert([
      {
        user_id: userId,
        contact_id: contactId,
        is_responder: true,
        is_dependent: false,
        send_pings: true,
        receive_pings: true,
        notify_on_check_in: true,
        notify_on_expiry: true,
        last_updated: new Date().toISOString(),
        added_at: new Date().toISOString()
      },
      {
        user_id: contactId,
        contact_id: userId,
        is_responder: false,
        is_dependent: true,
        send_pings: true,
        receive_pings: true,
        notify_on_check_in: false,
        notify_on_expiry: false,
        last_updated: new Date().toISOString(),
        added_at: new Date().toISOString()
      }
    ]);
  });
  
  // Clean up test data
  afterAll(async () => {
    // Delete contact relationship
    await supabase.from('contacts').delete().eq('user_id', userId);
    await supabase.from('contacts').delete().eq('user_id', contactId);
    
    // Delete test users
    await supabase.from('user_profiles').delete().eq('user_id', userId);
    await supabase.from('user_profiles').delete().eq('user_id', contactId);
  });
  
  test('getUserProfile returns the correct user profile', async () => {
    const userProfile = await getUserProfile(userId);
    
    expect(userProfile).toBeDefined();
    expect(userProfile.name).toBe('Test User 1');
    expect(userProfile.phone).toBe('+15551234567');
  });
  
  test('getUserContacts returns all contacts for a user', async () => {
    const contacts = await getUserContacts(userId);
    
    expect(contacts).toHaveLength(1);
    expect(contacts[0].contact_id).toBe(contactId);
    expect(contacts[0].is_responder).toBe(true);
    expect(contacts[0].is_dependent).toBe(false);
    expect(contacts[0].contact_profile).toBeDefined();
    expect(contacts[0].contact_profile.name).toBe('Test User 2');
  });
  
  test('getUserResponders returns responders for a user', async () => {
    const responders = await getUserResponders(userId);
    
    expect(responders).toHaveLength(1);
    expect(responders[0].contact_id).toBe(contactId);
    expect(responders[0].is_responder).toBe(true);
    expect(responders[0].contact_profile).toBeDefined();
    expect(responders[0].contact_profile.name).toBe('Test User 2');
  });
  
  test('getUserDependents returns dependents for a user', async () => {
    const dependents = await getUserDependents(contactId);
    
    expect(dependents).toHaveLength(1);
    expect(dependents[0].contact_id).toBe(userId);
    expect(dependents[0].is_dependent).toBe(true);
    expect(dependents[0].contact_profile).toBeDefined();
    expect(dependents[0].contact_profile.name).toBe('Test User 1');
  });
  
  test('getUsersWithExpiringCheckIns returns users with expiring check-ins', async () => {
    const users = await getUsersWithExpiringCheckIns(60);
    
    expect(users.length).toBeGreaterThan(0);
    expect(users.some(user => user.user_id === userId)).toBe(true);
  });
});
```

## Best Practices

1. **Query Optimization**: Optimize queries for performance
   - Use appropriate indexes
   - Limit query results when possible
   - Use compound queries to reduce the number of database operations
   - Use batch operations for multiple reads or writes

2. **Error Handling**: Implement proper error handling
   - Catch and log errors
   - Provide meaningful error messages
   - Handle specific error cases (e.g., not found)
   - Use try-catch blocks for all database operations

3. **Type Safety**: Use TypeScript for type safety
   - Define interfaces for database models
   - Use type assertions when necessary
   - Validate data before using it

4. **Query Organization**: Organize queries by domain
   - Group related queries together
   - Use descriptive function names
   - Document query parameters and return values

5. **Testing**: Write comprehensive tests for queries
   - Test happy path scenarios
   - Test error cases
   - Use mock data for testing
   - Clean up test data after tests

For detailed implementation guidelines, see the [Backend Guidelines](../../Guidelines/README.md) section.
