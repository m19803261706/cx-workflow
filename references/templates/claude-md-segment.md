# CLAUDE.md CX Workflow Segment Template

Keep this segment **≤30 lines** to avoid token waste. This is the only part of CLAUDE.md that cx-workflow manages.

---

## Template (exactly what cx-init will insert)

```markdown
<!-- CX-WORKFLOW-START -->
## CX Workflow

### Commands
/cx-prd <feature> | /cx-fix <desc> | /cx-exec | /cx-summary | /cx-status

### Active Task
- Feature: [feature-name] — Progress [X/Y] — Current: [task description]

### Project Conventions
- API: [e.g., /api/v1/{resource}]
- Naming: [e.g., DB snake_case → DTO camelCase → Frontend camelCase]
- Tests: [e.g., npm test, target >80% coverage]
- Commit: [e.g., {type}({scope}): {desc}]

### Tech Stack
- Backend: [e.g., Node.js + Express]
- Frontend: [e.g., React + TypeScript]
- Database: [e.g., PostgreSQL]
- Auth: [e.g., JWT (if applicable)]
<!-- CX-WORKFLOW-END -->
```

---

## Placeholder Explanation

| Placeholder | Filled By | Example |
|-------------|-----------|---------|
| `[feature-name]` | cx-init from input | `payment-system` |
| `[X/Y]` | cx-exec on task completion | `3/5` |
| `[task description]` | cx-exec current task | `Backend API endpoints` |
| `[API path pattern]` | User input or auto-detected | `/api/v1/users`, `/api/v2/orders` |
| `[Naming convention]` | User input or from code scan | `snake_case → camelCase → camelCase` |
| `[Test command]` | Auto-detected from package.json | `npm test`, `pytest`, `cargo test` |
| `[Commit format]` | User input or from git log | `feat(auth): add login` |
| `[Backend]` | Auto-detected from project | `Node.js + Express`, `Python + Django`, `Rust + Actix` |
| `[Frontend]` | Auto-detected | `React`, `Vue`, `Svelte` |
| `[Database]` | Auto-detected | `PostgreSQL`, `MongoDB`, `SQLite` |
| `[Auth]` | Detected from code or user input | `JWT`, `OAuth2`, `Session-based` |

---

## Behavior Rules

### cx-init Insertion

When user runs `/cx-init`:

1. Check if CLAUDE.md exists
   - ✅ Exists → Find CX segment markers
     - Markers found → Replace content between markers
     - Markers not found → Append segment to end of file
   - ❌ Doesn't exist → Create new file with segment

2. Ask user for initial values
   - "What's the feature name?" → Fills `[feature-name]`
   - "What's your API pattern?" → Fills `[API path]`
   - Auto-detect everything else from project

3. Write segment with all placeholders filled
   - Keep ≤30 lines (warn if exceeds)

### cx-exec Updates

During task execution, cx-exec updates ONLY this line:
```markdown
- Feature: [feature-name] — Progress [X/Y] — Current: [task description]
```

- `X` = completed tasks (increments by 1)
- `Y` = total tasks (fixed from cx-plan)
- `[task description]` = current task name

Example progression:
```markdown
- Feature: auth-system — Progress 1/5 — Current: Signup endpoint
- Feature: auth-system — Progress 2/5 — Current: Login endpoint
- Feature: auth-system — Progress 3/5 — Current: Session middleware
```

**Important**: cx-exec does NOT touch other lines.

### cx-summary Smart Update

After all tasks complete, cx-summary:

1. **Auto-clean**: Remove feature line (completed)
   ```markdown
   # Before
   - Feature: auth-system — Progress 5/5 — Current: Code review

   # After
   (line removed)
   ```

2. **Auto-analyze**: Scan design.md, adr.md, git diff for NEW conventions
   - Found new conventions? → Ask user if they should be added
   - No new conventions → Silent completion

3. **If user says "Yes, update"**:
   - Show diff (old conventions vs new conventions)
   - Update "Project Conventions" and "Tech Stack" sections
   - Check final line count ≤30
     - ✅ ≤30 → Done
     - ❌ >30 → Warn user, suggest external reference file

### Line Count Guardian

**Goal**: Keep segment ≤30 lines to minimize token consumption.

**Enforcement**:
- Before cx-init: Warn if user adds too much, suggest references/ folder
- After cx-summary update: Check if conventions update pushes total over 30
  - ✅ ≤30 → Accept
  - ❌ >30 → Show warning:
    ```
    CX segment now {n} lines. Recommend:
    1. Move detailed conventions to references/ folder
    2. Keep CLAUDE.md summary only (core project context)
    3. Link to references/workflow-guide.md
    ```

---

## Example Segments (Different Projects)

### Minimal (Solo Dev)

```markdown
<!-- CX-WORKFLOW-START -->
## CX Workflow
### Commands
/cx-prd | /cx-fix | /cx-exec | /cx-status

### Active Task
(none)

### Conventions
- API: /api/v1/{resource}
- Test: npm test
- Commit: {type}({scope}): {desc}
<!-- CX-WORKFLOW-END -->
```

**Lines**: 13

### Standard (Team)

```markdown
<!-- CX-WORKFLOW-START -->
## CX Workflow

### Commands
/cx-prd <feature> | /cx-fix <desc> | /cx-exec | /cx-summary | /cx-status

### Active Task
- Feature: payment-gateway — Progress 2/6 — Current: Backend Stripe integration

### Project Conventions
- API: /api/v1/{resource}
- Naming: DB snake_case → DTO camelCase
- Auth: JWT (1h + 7d tokens), HttpOnly cookies
- Tests: npm test (target >80%)
- Commit: {type}({scope}): {desc}

### Tech Stack
- Backend: Node.js + Express
- Frontend: React + TypeScript
- Database: PostgreSQL
- Cache: Redis
<!-- CX-WORKFLOW-END -->
```

**Lines**: 25 ✅

### Maximal (Reference Complex Project)

```markdown
<!-- CX-WORKFLOW-START -->
## CX Workflow

### Commands
/cx-prd <feature> | /cx-fix <desc> | /cx-exec | /cx-summary | /cx-status

### Active Task
(completed, awaiting next feature)

### Project Conventions
- API: /api/v1/{resource}, pagination: ?page=1&limit=20
- Naming: snake_case (DB) → camelCase (DTO) → camelCase (FE)
- Auth: JWT exp 1h (refresh 7d), HttpOnly secure cookies
- Tests: npm test, >80%, github checks
- Commit: {type}({scope}): {desc} (enforce via husky)
- Branching: feature/{name}, auto-squash on merge

### Tech Stack
- Backend: Node.js 18 + Express + TypeORM
- Frontend: React 18 + TypeScript + Vite
- Database: PostgreSQL 15 + Redis 7
- Deployment: Docker + k8s

### Architecture Notes
- See design.md for endpoint contracts
- See references/workflow-guide.md for full process
<!-- CX-WORKFLOW-END -->
```

**Lines**: 30 ✅ (at limit)

---

## What NOT to Include

❌ **Historical items**:
- Completed features (remove after cx-summary)
- Past decisions (document in ADR, not CLAUDE.md)
- Old bug fixes (link to fix.md instead)

❌ **Verbose descriptions**:
- Full feature requirements (link PRD)
- Implementation details (link Design Doc)
- Test specs (link test files)

❌ **Duplicates**:
- Anything in design.md (reference it)
- Anything in contract-spec.md (reference it)
- Team docs (link to wiki/confluence)

---

## Maintenance

### cx-init

Occurs once at project start.

```bash
/cx-init
# Creates:
# - .claude/cx/config.json
# - .claude/cx/status.json
# - .claude/cx/features/ directory
# - CLAUDE.md CX segment (if not exists)
# - .claude/settings.json hooks
```

### cx-exec

Occurs per task completion. Auto-updates progress line.

```bash
/cx-exec
# On task finish:
# - Validates contract
# - Commits code
# - Updates: "Progress [X/Y]" and "Current: [task]"
```

### cx-summary

Occurs after all tasks done. Smart updates conventions.

```bash
/cx-summary
# On feature completion:
# - Removes feature line (if completed)
# - Detects new conventions (optional user prompt)
# - Updates "Project Conventions" (if user agrees)
# - Validates ≤30 lines
```

### Manual Edits

Users can edit CLAUDE.md directly:
- ✅ Update "Active Task" manually between cx-runs (won't break cx-exec)
- ✅ Update "Tech Stack" if something changes
- ✅ Add custom section above/below CX segment
- ❌ Don't edit section markers (<!-- CX-WORKFLOW-START/END -->)
- ❌ Don't move CX segment (cx-update expects fixed location)

---

## See Also

- `workflow-guide.md` — Full workflow reference
- `config-schema.json` — cx-workflow config fields
- `references/templates/prd.md` — PRD template
- `references/templates/design.md` — Design Doc template
