# Supabase Database Guidelines

**Navigation:** [Back to Supabase Guidelines](README.md) | [Functions](Functions.md) | [Authentication](Authentication.md) | [Security](Security.md)

---

## Overview

This document provides guidelines for implementing database operations in Supabase for the LifeSignal application. While the primary data storage is in Firebase Firestore, Supabase may be used for specific database needs related to cloud functions.

## Database Usage

In the LifeSignal application, Supabase database is used primarily for:

1. **Function Metadata**: Storing metadata about cloud functions
2. **Caching**: Caching frequently accessed data
3. **Analytics**: Storing analytics data
4. **Logs**: Storing function logs

The primary application data remains in Firebase Firestore.

## Implementation Guidelines

### General Guidelines

1. **Schema Design**: Design schemas with normalization in mind
2. **Indexing**: Create appropriate indexes for query performance
3. **Constraints**: Use constraints to enforce data integrity
4. **Migrations**: Use migrations for schema changes
5. **Versioning**: Version database schemas
6. **Documentation**: Document database schemas and queries

### Schema Design

When designing database schemas, follow these guidelines:

1. **Use Descriptive Names**: Use descriptive names for tables and columns
2. **Use Appropriate Data Types**: Use appropriate data types for columns
3. **Use Primary Keys**: Define primary keys for all tables
4. **Use Foreign Keys**: Define foreign keys for relationships
5. **Use Indexes**: Create indexes for frequently queried columns
6. **Use Constraints**: Use constraints to enforce data integrity
7. **Normalize Data**: Normalize data to reduce redundancy

Example schema:

```sql
-- Function metadata table
CREATE TABLE function_metadata (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  function_name TEXT NOT NULL,
  version TEXT NOT NULL,
  last_deployed TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deployed_by TEXT,
  status TEXT DEFAULT 'active',
  UNIQUE(function_name, version)
);

-- Function logs table
CREATE TABLE function_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  function_name TEXT NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  level TEXT NOT NULL,
  message TEXT NOT NULL,
  metadata JSONB
);

-- Create indexes
CREATE INDEX function_logs_function_name_idx ON function_logs(function_name);
CREATE INDEX function_logs_timestamp_idx ON function_logs(timestamp);
CREATE INDEX function_logs_level_idx ON function_logs(level);
```

### Querying

When querying the database, follow these guidelines:

1. **Use Parameterized Queries**: Use parameterized queries to prevent SQL injection
2. **Use Transactions**: Use transactions for multi-step operations
3. **Limit Results**: Limit query results to prevent performance issues
4. **Use Pagination**: Use pagination for large result sets
5. **Use Appropriate Joins**: Use appropriate joins for related data
6. **Use Indexes**: Ensure queries use indexes
7. **Monitor Performance**: Monitor query performance

Example query:

```typescript
// Get function logs for a specific function
const { data, error } = await supabase
  .from('function_logs')
  .select('*')
  .eq('function_name', 'myFunction')
  .order('timestamp', { ascending: false })
  .limit(100)
```

### Transactions

Use transactions for multi-step operations:

```typescript
// Start a transaction
const { error } = await supabase.rpc('begin_transaction')

try {
  // Perform operations
  await supabase.from('function_metadata').insert({
    function_name: 'myFunction',
    version: '1.0.0',
    deployed_by: 'user@example.com'
  })
  
  await supabase.from('function_logs').insert({
    function_name: 'myFunction',
    level: 'info',
    message: 'Function deployed'
  })
  
  // Commit the transaction
  await supabase.rpc('commit_transaction')
} catch (error) {
  // Rollback the transaction
  await supabase.rpc('rollback_transaction')
  throw error
}
```

### Migrations

Use migrations for schema changes:

```typescript
// Create a migration
const { error } = await supabase.rpc('create_migration', {
  name: 'add_function_metadata_table',
  sql: `
    CREATE TABLE function_metadata (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      function_name TEXT NOT NULL,
      version TEXT NOT NULL,
      last_deployed TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      deployed_by TEXT,
      status TEXT DEFAULT 'active',
      UNIQUE(function_name, version)
    );
  `
})
```

### Error Handling

Handle database errors appropriately:

```typescript
// Query the database
const { data, error } = await supabase
  .from('function_logs')
  .select('*')
  .eq('function_name', 'myFunction')
  .limit(100)

// Handle errors
if (error) {
  console.error('Database error:', error)
  throw new Error('Failed to query function logs')
}

// Use the data
console.log('Function logs:', data)
```

## Best Practices

1. **Use Connection Pooling**: Use connection pooling for efficient database connections
2. **Use Prepared Statements**: Use prepared statements for frequently executed queries
3. **Use Transactions**: Use transactions for multi-step operations
4. **Use Appropriate Indexes**: Create indexes for frequently queried columns
5. **Monitor Performance**: Monitor database performance
6. **Backup Data**: Regularly backup database data
7. **Use Migrations**: Use migrations for schema changes
8. **Document Schemas**: Document database schemas and queries
9. **Use Constraints**: Use constraints to enforce data integrity
10. **Use Appropriate Data Types**: Use appropriate data types for columns

## Related Documentation

- [Supabase Overview](README.md) - Overview of Supabase integration
- [Functions](Functions.md) - Guidelines for implementing Supabase functions
- [Authentication](Authentication.md) - Guidelines for implementing Supabase authentication
- [Security](Security.md) - Guidelines for implementing Supabase security
