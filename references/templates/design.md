# Design Doc: [Feature Name]

**Feature**: [From PRD]
**Scale**: [S/M/L from PRD assessment]
**Author**: [Your name]
**Date**: [YYYY-MM-DD]
**Status**: [In Progress / Ready for Review / Approved]

---

## Overview

[1-2 paragraph summary of the design approach. How does it solve the PRD requirements? What are the key components?]

Example: "This design implements JWT-based stateless session management. Users sign up via email, receive a session token on login, and present that token on protected endpoints. The backend validates tokens without storing session state (except for revoked tokens in Redis). This approach scales horizontally and integrates with existing user model."

---

## Architecture Diagram

**Option A: ASCII diagram**

```
┌──────────────┐
│   Browser    │
└──────┬───────┘
       │ POST /signup, POST /login
       ▼
┌──────────────┐
│  Auth API    │──┬──→ PostgreSQL (User table)
└──────┬───────┘  │
       │          └──→ Redis (revoked tokens)
       │ JWT token
       ▼
┌──────────────┐
│   Frontend   │
│ (store token)│
└──────┬───────┘
       │ GET /api/protected (with JWT)
       ▼
┌──────────────┐
│  API Gateway │─→ Verify token → Allow/Reject
└──────────────┘
```

**Option B: External diagram reference**

[Link to Figma/Miro/LucidChart diagram]

---

## Key Components

### Backend

**Auth Service** (new)
- Signup endpoint: email validation, password hashing, user creation
- Login endpoint: credential verification, token generation
- Session validation middleware: JWT parsing, expiry check
- Token revocation: logout, password reset, admin actions

**Database**
- Users table: id, email, hashed_password, created_at, updated_at
- Revoked tokens table (Redis): token, revoke_reason, ttl

### Frontend

**Auth UI** (new)
- Signup form: email, password, confirm password
- Login form: email, password, remember-me checkbox
- Session state: store token in localStorage/sessionStorage
- Protected routes: redirect to login if token missing/expired

**Middleware** (new)
- Request interceptor: attach token to Authorization header
- Response interceptor: redirect to login on 401

---

## Three Mandatory Contract Sections

### API Endpoint Contract

| Endpoint | Method | Request Body (Type) | Response Body (Type) | Status Codes |
|----------|--------|---------------------|----------------------|--------------|
| `/api/v1/auth/signup` | POST | `SignupRequest` | `AuthResponse` | 201, 400, 409 |
| `/api/v1/auth/login` | POST | `LoginRequest` | `AuthResponse` | 200, 401 |
| `/api/v1/auth/logout` | POST | ∅ | ∅ | 204, 401 |
| `/api/v1/auth/refresh` | POST | ∅ | `AuthResponse` | 200, 401 |
| `/api/v1/auth/me` | GET | ∅ | `UserResponse` | 200, 401 |
| `/api/v1/auth/reset-password` | POST | `ResetPasswordRequest` | ∅ | 200, 400, 404 |

**Type Definitions**

```typescript
// Request types
SignupRequest {
  email: string;           // Valid email format, unique
  password: string;        // Min 8 chars, must have uppercase + digit
  confirmPassword: string; // Must match password
}

LoginRequest {
  email: string;
  password: string;
  rememberMe?: boolean;    // Defaults to false (1-hour token)
}

ResetPasswordRequest {
  email: string;
  resetToken: string;      // From email link
  newPassword: string;     // Must differ from old password
  confirmPassword: string; // Must match
}

// Response types
AuthResponse {
  accessToken: string;       // JWT, expires in 1h (or 7d if rememberMe)
  refreshToken?: string;     // JWT, expires in 30d (optional)
  user: UserResponse;
}

UserResponse {
  id: string;           // UUID
  email: string;
  createdAt: string;    // ISO 8601
}
```

### State/Enum Contract

**SessionStatus** (implicit in JWT claims)
| State | Meaning | Allowed Transitions |
|-------|---------|---------------------|
| `ACTIVE` | Valid, not revoked | → `REVOKED`, expires after 1h/7d |
| `REVOKED` | Explicitly logged out | (terminal) |
| `EXPIRED` | TTL exceeded | (terminal, requires new login) |

**PasswordResetTokenStatus**
| State | Meaning | Allowed Transitions |
|-------|---------|---------------------|
| `PENDING` | Sent to user email, not yet used | → `USED`, `EXPIRED` |
| `USED` | Successfully reset password | (terminal) |
| `EXPIRED` | 24 hours elapsed | (terminal, requires new reset email) |

### Field Mapping Contract

| DB Column | DTO Field | Frontend Var | Notes |
|-----------|-----------|--------------|-------|
| `id` | `id` | `userId` | UUID primary key |
| `email` | `email` | `userEmail` | Unique, case-insensitive |
| `hashed_password` | (omitted) | (not sent) | Never sent to frontend, never logged |
| `created_at` | `createdAt` | `createdAt` | ISO 8601, UTC |
| `updated_at` | `updatedAt` | (not sent) | Server-only |

---

## Database Schema Changes

**New table: users**
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  hashed_password VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
```

**New table (optional): password_reset_tokens**
```sql
CREATE TABLE password_reset_tokens (
  token_hash VARCHAR(255) PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, USED, EXPIRED
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP + INTERVAL '24 hours'
);

CREATE INDEX idx_reset_tokens_user_id ON password_reset_tokens(user_id);
```

**Redis keys (transient)**:
```
revoked_tokens:{token}  → true (expires per token TTL)
password_reset:{hash}   → user_id (expires after 24h)
```

---

## Error Handling Strategy

| Scenario | Status Code | Response | Reason |
|----------|-------------|----------|--------|
| Invalid email format in signup | 400 | `{ error: "invalid_email" }` | Client error, actionable |
| Duplicate email in signup | 409 | `{ error: "email_exists" }` | Conflict with existing resource |
| Weak password (not 8+ chars) | 400 | `{ error: "password_too_weak" }` | Client error, actionable |
| Wrong password on login | 401 | `{ error: "invalid_credentials" }` | Generic (security: don't reveal email exists) |
| Missing/expired token | 401 | `{ error: "unauthorized" }` | Requires new login |
| Token revoked (logout) | 401 | `{ error: "token_revoked" }` | New login needed |
| Reset token expired | 400 | `{ error: "reset_token_expired" }` | User must request new reset email |
| Internal error | 500 | `{ error: "internal_error" }` | Unexpected; log details server-side |

**Logging Policy**:
- ✅ Log failed login attempts (with email)
- ✅ Log password reset requests (with email)
- ❌ Never log actual passwords
- ❌ Never log JWT tokens (log hash only)
- ✅ Log token revocations (with reason: logout, password_reset, etc.)

---

## Dependencies

**External**:
- `bcryptjs` or `argon2` — Password hashing
- `jsonwebtoken` — JWT generation/validation
- `nodemailer` or `SendGrid API` — Reset email delivery

**Internal**:
- Existing User model (if any)
- Email templates (from marketing/templates/)
- Rate limiter (to prevent brute force login)

**Database**:
- PostgreSQL (existing)
- Redis (for token revocation)

---

## Security Considerations

1. **Password Hashing**: Use bcrypt (cost 10+) or Argon2, never plaintext
2. **Token Storage**: Frontend uses HttpOnly cookie (not localStorage) or in-memory
3. **CSRF Protection**: Same-site cookies + CSRF token on sensitive endpoints
4. **Rate Limiting**: Max 5 failed logins per IP per minute
5. **HTTPS Only**: All auth endpoints require TLS
6. **Token Expiry**: Short-lived access tokens (1h) + long-lived refresh tokens (30d)
7. **Email Verification**: Confirm email before account activation (prevents spam)

---

## Deployment & Rollout

**Phase 1**: Deploy auth endpoints, not yet integrated
- [ ] Database migrations (users table)
- [ ] Auth service API
- [ ] Email service integration
- [ ] Unit + integration tests

**Phase 2**: Integrate frontend (feature flag)
- [ ] Signup/login UI
- [ ] Session middleware
- [ ] Protected routes
- [ ] Token refresh logic

**Phase 3**: Enable for all users (feature flag → 100%)
- [ ] Monitor auth error rates
- [ ] Monitor password reset success rate
- [ ] Collect user feedback

---

## Testing Strategy

**Unit Tests** (auth service logic):
- Password validation rules
- Token generation/validation
- Email format validation
- Password hashing consistency

**Integration Tests** (endpoints):
- Signup flow (happy path + error cases)
- Login flow (correct password, wrong password)
- Session validation (valid token, expired token, revoked token)
- Logout invalidates token
- Password reset email delivery
- Password reset token expiry

**Load Tests**:
- 1000 concurrent signups
- 1000 concurrent logins
- Response time <200ms (p99)

---

## Known Limitations & Future Work

- No multi-factor authentication (MFA) — planned for Phase 2
- No OAuth/social login — planned for Phase 2
- No password strength meter on signup form — could improve UX
- No account lockout after repeated failed logins — add in Phase 2

---

## Review Checklist

- [ ] All PRD requirements mapped to this design
- [ ] Three contract sections complete and specific
- [ ] Database schema finalized with team
- [ ] Security review passed
- [ ] Performance implications understood
- [ ] Deployment plan agreed
