# API Contract Specification

Detailed format for the three mandatory contract sections in Design Doc. These contracts are embedded into task files and validated during execution.

---

## What is an API Contract in cx-workflow?

A contract is a **formal, machine-readable boundary** between:
- **Backend**: What endpoints/responses it must provide
- **Frontend**: What it can expect to receive
- **Tests**: What to validate

Contracts prevent drift without constant sync meetings. They are the single source of truth that all three (BE/FE/Test) follow.

### Why Not Just Code?

- **Code is late**: You write tests AFTER implementing
- **Contracts are early**: You define them in Design Doc BEFORE implementing
- **Code is ambiguous**: "What's the actual response shape?" requires reading 50 lines
- **Contracts are explicit**: One source, clear format

### When Are Contracts Used?

```
Design Doc (cx-design)
  ↓ Define contracts
Task File (cx-plan embeds contract)
  ↓ Developer sees contract before coding
Code Change (cx-exec)
  ↓ Validated against contract
Tests (implied)
  ↓ Should test against contract
```

---

## Three Mandatory Contract Sections in Design Doc

Every Design Doc must include these three sections. Use the templates below.

### **1. API Endpoint Contract**

Defines every HTTP endpoint: path, method, request body shape, response body shape, status codes.

**Format**:

```markdown
## API Endpoint Contract

| Endpoint | Method | Request Body (Type) | Response Body (Type) | Status Codes |
|----------|--------|---------------------|----------------------|--------------|
| `/api/v1/users` | POST | `CreateUserRequest` | `UserResponse` | 201, 400, 409 |
| `/api/v1/users/{id}` | GET | ∅ | `UserResponse` | 200, 404 |
| `/api/v1/users/{id}` | PUT | `UpdateUserRequest` | `UserResponse` | 200, 400, 404 |
| `/api/v1/users/{id}` | DELETE | ∅ | ∅ | 204, 404 |

### Type Definitions

**CreateUserRequest**
```typescript
{
  email: string;          // Unique, must be valid email
  password: string;       // Min 8 chars, contain uppercase + number
  name: string;          // 1–100 chars
  role: "admin" | "user"; // Defaults to "user"
}
```

**UpdateUserRequest**
```typescript
{
  email?: string;        // If changed, must be unique
  name?: string;
  role?: "admin" | "user";
}
```

**UserResponse**
```typescript
{
  id: string;           // UUID
  email: string;
  name: string;
  role: "admin" | "user";
  createdAt: string;    // ISO 8601 timestamp
  updatedAt: string;    // ISO 8601 timestamp
}
```
```

**Validation Rules**:
- Every endpoint must have a row
- Request body can be ∅ for GET/DELETE (unless query params)
- Response can be ∅ for DELETE
- TypeScript types must be complete (all fields listed)
- Status codes should include both success (2xx) and error cases (4xx/5xx)

**Common Mistakes**:
- ❌ "Returns user object" (not specific enough)
- ❌ Listing only success status code (e.g., only 200, omit 400)
- ❌ Forgetting optional fields (use `?:` notation)

---

### **2. State/Enum Contract**

Defines valid enum values, their meaning, and allowed transitions.

**Format**:

```markdown
## State/Enum Contract

### OrderStatus Enum
| Value | Label | Allowed Transitions |
|-------|-------|---------------------|
| `PENDING` | Order received, awaiting payment | → `PAID`, `CANCELLED` |
| `PAID` | Payment confirmed | → `PROCESSING`, `REFUNDED` |
| `PROCESSING` | Fulfilling order | → `SHIPPED`, `FAILED` |
| `SHIPPED` | Item sent to customer | → `DELIVERED`, `RETURNED` |
| `DELIVERED` | Customer received | → `RETURNED` (10 days) |
| `CANCELLED` | Order cancelled by customer | (terminal) |
| `REFUNDED` | Payment refunded | (terminal) |
| `FAILED` | Fulfillment failed | → `CANCELLED` |

### UserRole Enum
| Value | Label | Permissions |
|-------|-------|-------------|
| `USER` | Standard user | Can view own profile, create orders |
| `ADMIN` | Administrator | All permissions |
| `SUPPORT` | Support agent | Can view/edit customer tickets |
```

**Validation Rules**:
- Every enum value must have a row
- Transitions must be explicit (use arrows)
- Terminal states should be marked `(terminal)`
- If time-based transitions exist (e.g., "10 days"), note them
- Include permission implications if relevant

**Why Transitions Matter**:
- Prevents invalid state changes in code
- Makes state machine testable
- Frontend UI can enable/disable actions based on current state

---

### **3. Field Mapping Contract**

Maps database column names (snake_case) → API DTO (camelCase) → Frontend vars (camelCase).

**Format**:

```markdown
## Field Mapping Contract

| DB Column | DTO Field | Frontend Var | Notes |
|-----------|-----------|--------------|-------|
| `user_id` | `userId` | `userId` | Sent to frontend in all responses |
| `email_address` | `email` | `userEmail` | Unique, case-insensitive in DB |
| `hashed_password` | (omitted) | (not sent) | Never sent to frontend |
| `first_name` | `firstName` | `firstName` | From Profile panel |
| `last_name` | `lastName` | `lastName` | From Profile panel |
| `created_at` | `createdAt` | `createdAt` | ISO 8601, UTC timezone |
| `updated_at` | `updatedAt` | `updatedAt` | ISO 8601, UTC timezone |
| `is_active` | `isActive` | `isActive` | Boolean, defaults true |
| `role_id` (FK) | `role` | `userRole` | Resolved to `UserRole` enum |
```

**Validation Rules**:
- Every DB column involved must have a row
- DTO field can be omitted if column is private (e.g., password)
- Frontend var name can differ from DTO (rare but OK)
- Notes section should highlight:
  - ✓ Data transformations (camelCase, enum resolution)
  - ✓ Uniqueness constraints
  - ✓ Fields omitted from API
  - ✓ Timezone info for timestamps

**Why This Matters**:
- Prevents mismatches between BE request body and FE expected shape
- Obvious when someone forgets to include a field in API response
- Makes refactoring safer (you see all references at once)

---

## Contract Sinking Process (cx-plan)

When `cx-plan` runs, it extracts contract fragments and embeds them into each task file.

### Example: Backend Task with Embedded Contract

```markdown
# Task: Implement User CRUD API

## Embedded Contract Fragment

### Relevant Endpoints
| Path | Method | Request | Response | Status |
|------|--------|---------|----------|--------|
| `/api/v1/users` | POST | CreateUserRequest | UserResponse | 201, 400, 409 |
| `/api/v1/users/{id}` | GET | ∅ | UserResponse | 200, 404 |

### Relevant Type Definitions
**CreateUserRequest**: email (unique, valid), password (8+ chars, upper+digit), name (1-100), role (admin|user, default user)
**UserResponse**: id, email, name, role, createdAt, updatedAt

### Relevant Field Mappings
| DB | DTO | FE |
|----|-----|----|
| user_id | userId | userId |
| email_address | email | userEmail |
| hashed_password | (omit) | (not sent) |
| first_name | firstName | firstName |

---

## Implementation Checklist

- [ ] POST /api/v1/users accepts CreateUserRequest
- [ ] POST /api/v1/users returns UserResponse (id, email, name, role, createdAt, updatedAt)
- [ ] POST returns 201 on success, 400 on validation error, 409 on duplicate email
- [ ] GET /api/v1/users/{id} returns UserResponse
- [ ] GET returns 404 if user not found
- [ ] Field names in response match DTO (camelCase)
- [ ] Timestamps are ISO 8601, UTC
- [ ] Password never in response body
```

### What Gets Embedded?

- ✅ Relevant endpoints table (only for this task's scope)
- ✅ Type definitions (only the ones this task uses)
- ✅ Enum transitions (if task modifies state)
- ✅ Field mappings (only relevant columns)
- ❌ Architecture diagrams
- ❌ Implementation details from other sections

**Why Embed?**

- Developer doesn't have to switch files
- Clear what they're being held accountable to
- ci-exec can validate the task output without reading Design Doc

---

## Contract Validation Rules (cx-exec)

When you implement a task, cx-exec validates your code against the embedded contract.

### Validation Checklist

**For API Endpoint Contract**:
- ✓ Every defined endpoint path exists in code
- ✓ HTTP method matches (POST vs PUT)
- ✓ Request body fields match (no missing fields, no extra unsanctioned fields)
- ✓ Response body fields match DTO type
- ✓ Status codes returned match expected set (e.g., 200, 404 for GET)
- ✓ No additional status codes added without design discussion

**For State/Enum Contract**:
- ✓ Enum values in code match defined set
- ✓ State transitions in code respect allowed transitions
- ✓ No direct jumps between disallowed states (e.g., PENDING → DELIVERED)

**For Field Mapping Contract**:
- ✓ DB column names match snake_case mappings
- ✓ DTO response uses camelCase names
- ✓ Private fields (password, hashed_*) never sent to frontend
- ✓ Enum fields properly resolved (e.g., role_id → UserRole)

### Validation Process

```
Developer writes code (backend, frontend, or both)
  ↓
git diff generated
  ↓
cx-exec parses code:
  ├─ Extract endpoint routes
  ├─ Extract response shape
  ├─ Extract enum/state usage
  └─ Extract DB query patterns
  ↓
Compare against contract:
  ├─ Path = contract path?
  ├─ Method = contract method?
  ├─ Fields = contract fields?
  ├─ Status codes ⊆ contract codes?
  ├─ State transitions valid?
  └─ Field names correct case?
  ↓
If mismatch → REJECT with specific diff
If pass → Continue to next task
```

### Example Validation Failure

**Contract says**:
```
POST /api/v1/users
Request: { email, password, name, role }
Response: { id, email, name, role, createdAt, updatedAt }
Status: 201, 400, 409
```

**Code has**:
```typescript
app.post("/api/v1/users", (req, res) => {
  const { email, password, name } = req.body;
  // Missing 'role' field!
  const user = createUser(email, password, name, "user");
  res.status(201).json({
    id: user.id,
    email: user.email,
    name: user.name,
    // Missing 'role', 'createdAt', 'updatedAt'
    role: user.role
  });
});
```

**cx-exec output**:
```
❌ Contract validation failed:

Task: task-1.md (Implement User CRUD API)

Mismatch in POST /api/v1/users:

Missing from request handling:
  - role field not read from req.body (should be optional? check contract)

Missing from response:
  - createdAt (contract requires ISO 8601)
  - updatedAt (contract requires ISO 8601)

Action: Add timestamps and verify role handling. Re-run cx-exec.
```

---

## Examples: Good vs Bad Contracts

### ✅ GOOD Contract (Specific, Testable)

```markdown
## API Endpoint Contract

| Endpoint | Method | Request | Response | Status |
|----------|--------|---------|----------|--------|
| `/api/v1/payments` | POST | CreatePaymentRequest | PaymentResponse | 201, 400, 422 |

**CreatePaymentRequest**
```typescript
{
  amount: number;        // Cents, > 0
  currency: "USD" | "EUR" | "GBP";
  method: "card" | "bank_transfer";
  customerId: string;    // UUID, must exist
  metadata?: Record<string, string>; // Max 10 keys
}
```

**PaymentResponse**
```typescript
{
  id: string;           // UUID
  amount: number;       // Echoes request amount
  currency: string;
  method: string;
  customerId: string;
  status: "PENDING" | "SUCCEEDED" | "FAILED";
  createdAt: string;    // ISO 8601
  expiresAt: string;    // ISO 8601 (30 min from creation)
  errorMessage?: string; // Present if status=FAILED
}
```
```

✅ Why good:
- Exact field names and types
- Constraints listed (> 0 amount, must exist customer)
- Response shape unambiguous
- Status codes cover success and expected errors

### ❌ BAD Contract (Vague, Untestable)

```markdown
## API Endpoint Contract

Takes payment info and returns payment result.

Request:
```
amount (number)
currency (string)
method (string)
customer (string or ID)
metadata (optional)
```

Response:
```
Returns payment object with id, amount, status, and other fields.
```

Status: 201 if success
```

❌ Why bad:
- Field names inconsistent (amount vs req.amount)
- Types incomplete ("string or ID" unclear)
- No constraints (is amount in cents or dollars?)
- Response fields vague ("other fields" — which ones?)
- Only lists happy path (201), missing error cases

---

## Updating Contracts

If mid-development you realize the contract was wrong:

1. **Stop** the current task
2. **Discuss with team** (if team project)
3. **Update Design Doc** contract section + type definitions
4. **Re-run cx-plan** to re-sink updated contracts into tasks
5. **Adjust code** to match new contract
6. **Re-run cx-exec** (it will re-validate)

**Why this process?**
- Contracts are not code comments (temporary)
- They're agreements (require validation)
- Change impacts other developers / team

---

## See Also

- `workflow-guide.md` — Whole workflow overview
- `templates/design.md` — Design Doc template with contract sections
- `templates/prd.md` — PRD (feeds into Design Doc)
