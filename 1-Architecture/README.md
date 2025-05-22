# Documentation Structure Guide

This document outlines the structure and organization of our architecture documentation to ensure consistency and ease of navigation.

## Core Principles

The architecture core principles that all documentation should take into consideration:
- Type Safety 
- Modularity/Composability
- Testability

## FileSystem Structure

The documentation filesystem is organized in a hierarchical structure, with the following considerations:

```
1-Architecture/
├── README.md                           # Overview of architecture documentation
│
├── 1-Backend/                          # Backend architecture
│   ├── 1-Authentication.md             # Firebase Authentication (phone only)
│   ├── 2-Database.md                   # Supabase Database (accessed only through Fly.io APIs)
│   ├── 3-Storage.md                    # Supabase Storage (accessed only through Fly.io APIs)
│   └── 4-Functions.md                  # Fly.io APIs (using Go typed SQL and Go gRPC functions and firebase authentication)
│
├── 2-iOS/                              # iOS architecture
│   ├── 1-MockApplication/              # Mock Application (using vanilla MVVM)
│   │   ├── 1-Views.md                  # Views and design system (no state extensive state management)
│   │   ├── 2-ViewModels.md             # View models and data binding (one per view)
│   │   └── 3-Clients.md                # Device clients and key mock clients (mock notification client)
│   │
│   └── 2-ProductionApplication/        # Production Application (using TCA from swift-composable-architecture)
│       ├── 1-Views.md                  # TCA compliant views (UI focused)
│       ├── 2-Features.md               # TCA reducer features (comprehensive state management and side effects)
│       └── 3-Clients.md                # TCA domain clients and platform clients (using @DependencyClient from swift-dependencies)
```

## Documents Structure

Each document in our architecture documentation follows a consistent structure

### iOS Mock Application Documents

**Title**

1. **Clear Purpose Statement**: Paragraph describing the component's purpose

2. **Content Structure**:
	* Clear headings and subheadings
	* Bullet points for lists of related items
    * items should be in the following format: - **Key phrase**: Description

3. **Testing**:
	* Clear headings and subheadings
	* Bullet points for lists of related items
	* items should be in the following format: - **Key phrase**: Description

4. **Anti-patterns**:
	* Clear headings and subheadings
	* Bullet points for lists of related items
	* items should be in the following format: - **Key phrase**: Description


### iOS Production Application Documents

**Title**

1. **Clear Purpose Statement**: Paragraph describing the component's purpose

2. **Content Structure**:
	* Clear headings and subheadings
	* Bullet points for lists of related items
	* items should be in the following format: - **Key phrase**: Description

3. **Error Handling**:
	* Clear headings and subheadings
	* Bullet points for lists of related items
	* items should be in the following format: - **Key phrase**: Description

4. **Testing**:
	* Clear headings and subheadings
	* Bullet points for lists of related items
	* items should be in the following format: - **Key phrase**: Description

5. **Anti-patterns**:
	* Clear headings and subheadings
	* Bullet points for lists of related items
	* items should be in the following format: - **Key phrase**: Description

### Backend Documents

**Title**

1. **Clear Purpose Statement**: Paragraph describing the component's purpose

2. **Content Structure**:
	* Clear headings and subheadings
	* Bullet points for lists of related items
	* items should be in the following format: - **Key phrase**: Description

3. **Error Handling**:
	* Clear headings and subheadings
	* Bullet points for lists of related items
	* items should be in the following format: - **Key phrase**: Description

4. **Testing**:
	* Clear headings and subheadings
	* Bullet points for lists of related items
	* items should be in the following format: - **Key phrase**: Description

5. **Deployment**:
	* Clear headings and subheadings
	* Bullet points for lists of related items
	* items should be in the following format: - **Key phrase**: Description

5. **Monitoring**:
	* Clear headings and subheadings
	* Bullet points for lists of related items
	* items should be in the following format: - **Key phrase**: Description

7. **Anti-patterns**:
	* Clear headings and subheadings
	* Bullet points for lists of related items
	* items should be in the following format: - **Key phrase**: Description

## Contribution Guidelines

When contributing to the architecture documentation:

1. Follow the templates provided above
2. Maintain consistent formatting
3. Keep content concise and focused
