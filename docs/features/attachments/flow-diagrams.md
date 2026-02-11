# Attachment Access Control Flow Diagrams

## Access Control Decision Flow

```mermaid
flowchart TD
    A[User Requests Attachment] --> B{Is Super Admin?}
    B -->|Yes| Z[✓ Grant Access]
    B -->|No| C{Check Embargo}
    C -->|Under Embargo| X[✗ Deny Access]
    C -->|Not Under Embargo| D{Check Access Level}
    D -->|Public| Z
    D -->|Restricted| X
    D -->|Limited| E{User Authenticated?}
    E -->|No| X
    E -->|Yes| F{Has Role Access?}
    F -->|Yes| Z
    F -->|No| G{Has User Access?}
    G -->|Yes| Z
    G -->|No| X
```

## Embargo Check Flow

```mermaid
flowchart TD
    A[Check Embargo] --> B{Has Start Date?}
    B -->|Yes| C{Current Date >= Start Date?}
    B -->|No| D{Has End Date?}
    C -->|No| E[Under Embargo]
    C -->|Yes| D
    D -->|Yes| F{Current Date <= End Date?}
    D -->|No| G[Not Under Embargo]
    F -->|No| E
    F -->|Yes| G
```

## Access Level Relationships

```mermaid
erDiagram
    ATTACHMENTS ||--o{ ATTACHMENT_ROLE_ACCESS : has
    ATTACHMENTS ||--o{ ATTACHMENT_USER_ACCESS : has
    ROLES ||--o{ ATTACHMENT_ROLE_ACCESS : grants
    USERS ||--o{ ATTACHMENT_USER_ACCESS : receives
    USERS ||--o{ ATTACHMENT_USER_ACCESS : grants
    USERS ||--o{ ATTACHMENTS : "updates access"

    ATTACHMENTS {
        uuid id PK
        string access_level
        timestamp embargo_start_date
        timestamp embargo_end_date
        uuid access_settings_updated_by_id FK
        timestamp access_settings_updated_at
    }

    ATTACHMENT_ROLE_ACCESS {
        uuid id PK
        uuid attachment_id FK
        int role_id FK
    }

    ATTACHMENT_USER_ACCESS {
        uuid id PK
        uuid attachment_id FK
        uuid user_id FK
        uuid granted_by_id FK
        timestamp granted_at
    }

    ROLES {
        int id PK
        string name
    }

    USERS {
        uuid id PK
        string email
    }
```

## Typical Usage Scenarios

### Scenario 1: Public Document
```mermaid
sequenceDiagram
    participant Staff
    participant System
    participant Database
    
    Staff->>System: Upload attachment
    System->>Database: Create with access_level='public'
    Database-->>System: Attachment created
    System-->>Staff: Upload successful
    
    Note over Staff,Database: Anyone can now access this attachment
```

### Scenario 2: Staff-Only Document
```mermaid
sequenceDiagram
    participant Admin
    participant System
    participant Database
    
    Admin->>System: Upload attachment with access_level='limited'
    System->>Database: Create attachment
    Admin->>System: Grant access to 'staff' role
    System->>Database: Insert into attachment_role_access
    Database-->>System: Access granted
    System-->>Admin: Configuration complete
    
    Note over Admin,Database: Only users with 'staff' role can access
```

### Scenario 3: Embargoed Research Paper
```mermaid
sequenceDiagram
    participant Researcher
    participant System
    participant Database
    participant Time
    
    Researcher->>System: Upload with embargo_start_date
    System->>Database: Create attachment
    Database-->>System: Saved
    
    Note over Time: Before embargo date
    Researcher->>System: Request access
    System->>System: Check embargo
    System-->>Researcher: Access denied (under embargo)
    
    Note over Time: After embargo date
    Researcher->>System: Request access
    System->>System: Check embargo
    System-->>Researcher: Access granted
```

### Scenario 4: Guest User Access
```mermaid
sequenceDiagram
    participant Admin
    participant System
    participant Database
    participant Guest
    
    Admin->>System: Create limited attachment
    System->>Database: Save attachment
    Admin->>System: Grant access to guest@example.com
    System->>Database: Insert into attachment_user_access
    Database-->>System: Access granted
    System-->>Admin: Guest access configured
    
    Guest->>System: Request attachment
    System->>Database: Check user access
    Database-->>System: Access found
    System-->>Guest: Download attachment
```

## Access Matrix Visualization

```mermaid
graph LR
    subgraph "Anonymous User"
        A1[Public<br/>✓] 
        A2[Limited<br/>✗]
        A3[Restricted<br/>✗]
        A4[Under Embargo<br/>✗]
    end
    
    subgraph "Regular User"
        B1[Public<br/>✓]
        B2[Limited w/ access<br/>✓]
        B3[Limited no access<br/>✗]
        B4[Restricted<br/>✗]
        B5[Under Embargo<br/>✗]
    end
    
    subgraph "Super Admin"
        C1[Public<br/>✓]
        C2[Limited<br/>✓]
        C3[Restricted<br/>✓]
        C4[Under Embargo<br/>✓]
    end
```

## State Transitions

```mermaid
stateDiagram-v2
    [*] --> Public: Create (default)
    
    Public --> Limited: Staff restricts
    Public --> Restricted: Admin restricts
    Public --> Embargoed: Set embargo dates
    
    Limited --> Public: Staff opens access
    Limited --> Restricted: Admin elevates
    Limited --> Embargoed: Add embargo
    
    Restricted --> Limited: Admin reduces
    Restricted --> Public: Admin opens
    Restricted --> Embargoed: Add embargo
    
    Embargoed --> Public: Embargo expires
    Embargoed --> Limited: Embargo expires
    Embargoed --> Restricted: Embargo expires
    
    note right of Public
        Anyone can access
    end note
    
    note right of Limited
        Role or user-based
    end note
    
    note right of Restricted
        Super admin only
    end note
    
    note right of Embargoed
        Time-based restriction
    end note
```

## Query Filtering Process

```mermaid
flowchart TD
    A[Query: Get Attachments] --> B{User Type?}
    
    B -->|Super Admin| C[Return ALL attachments]
    
    B -->|Anonymous| D[Filter: access_level = 'public']
    D --> E[Filter: NOT under embargo]
    E --> F[Return filtered]
    
    B -->|Authenticated| G[Get user's role IDs]
    G --> H[Build complex query]
    H --> I[Include: access_level = 'public']
    I --> J[Include: Limited + Role match]
    J --> K[Include: Limited + User match]
    K --> L[Filter: NOT under embargo]
    L --> M[Distinct results]
    M --> N[Return filtered]
```

## Bulk Operations Flow

```mermaid
flowchart TD
    A[Start: Bulk Grant Access] --> B{Grant Type?}
    
    B -->|Role| C[Get attachment IDs list]
    C --> D[Generate entries with timestamps]
    D --> E[Insert all with on_conflict: nothing]
    E --> F[Return count]
    
    B -->|User| G[Get attachment IDs list]
    G --> H[Generate entries with granted_by]
    H --> I[Insert all with on_conflict: nothing]
    I --> J[Return count]
```

## Access Summary Aggregation

```mermaid
flowchart TD
    A[Get Access Summary] --> B[Preload Associations]
    B --> C[allowed_roles]
    B --> D[allowed_users]
    B --> E[access_settings_updated_by]
    
    C --> F[Map to role names]
    D --> G[Map to user details]
    E --> H[Map to admin info]
    
    F --> I[Build Summary Object]
    G --> I
    H --> I
    
    I --> J[Add embargo status]
    J --> K[Return complete summary]
```

## Legend

- ✓ = Access Granted
- ✗ = Access Denied
- FK = Foreign Key
- PK = Primary Key

## Notes

1. **Super Admin**: Always has access, bypasses all restrictions
2. **Embargo**: Time-based restriction, checked before access level
3. **Limited Access**: Requires authentication AND (role OR user access)
4. **Public**: No restrictions (except embargo)
5. **Restricted**: Only super_admin can access
