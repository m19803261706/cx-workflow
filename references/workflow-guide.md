# CX Workflow Guide

Complete reference for the cx-workflow plugin. Use this when in doubt about process, scale assessment, or troubleshooting.

## Quick Start

1. **Install Plugin**: `/cx-init`
   - Configures developer ID, GitHub sync mode
   - Creates `.claude/cx/` directory
   - Installs hooks into `.claude/settings.json`
   - Adds CX segment to CLAUDE.md

2. **Start Feature Development**: `/cx-prd <feature-name>`
   - Collect requirements via multi-turn conversation
   - Auto-assess scale (S/M/L)
   - Write PRD to `features/<feature-slug>/prd.md`

3. **Technical Design**: `/cx-design`
   - Read PRD and generate Design Doc
   - Define three mandatory API contracts
   - Write to `features/<feature-slug>/design.md`

4. **Plan Tasks**: `/cx-plan`
   - Extract contract fragments into task files
   - Generate execution checklist
   - Write to `features/<feature-slug>/tasks/`

5. **Execute Tasks**: `/cx-exec`
   - Implement one task per invocation (or batch with Task tool)
   - Validate against contracts
   - Commit code with proper message

6. **Code Review** (after all tasks done):
   - config.code_review = true → `AskUserQuestion` for review options
   - Full audit / Quick check / Skip
   - code-reviewer + code-cleanup subagents if chosen

7. **Summarize**: `/cx-summary`
   - Generate summary document
   - Sync to GitHub (based on sync mode)
   - Update CLAUDE.md (if new project conventions detected)
   - Clean up temporary files

---

## Feature Development Path (Full Feature)

```
cx-init (one-time)
  ↓
cx-scope (optional)
  ↓
cx-prd <feature-name>
  ├─ scale → S
  ├─ scale → M
  └─ scale → L
      ↓
    cx-design
      ↓
    cx-adr (L-scale only)
  ↓
cx-plan
  ↓
cx-exec (loop until done)
  ├─ per-task implementation
  ├─ contract validation
  └─ commit
  ↓
[Code Review] (if config.code_review=true)
  ├─ Full Audit
  ├─ Quick Check
  └─ Skip
  ↓
cx-summary
  ├─ summary document
  ├─ GitHub sync
  ├─ CLAUDE.md update
  └─ cleanup
  ↓
✅ Complete
```

---

## Bug Fix Path (Lightweight)

```
cx-fix <description>
  ├─ Step 1: Understand (read GitHub issue if collab/full mode)
  ├─ Step 2: Investigate (Explore subagent scans code)
  ├─ Step 3: Fix (implement root cause fix)
  ├─ Step 4: Test (run project test suite)
  ├─ Step 5: Commit (git commit with proper message)
  └─ Step 6: Close (GitHub issue if collab/full mode)
  ↓
✅ Complete
```

---

## Scale Assessment Rules

Determines which design path to follow after PRD.

### **S Scale** (Small)
- **Criteria**: ≤3 API endpoints, 1 data model, no state machine
- **Examples**: Add a field to existing form, simple validation rule, minor UI tweak
- **Path**: PRD → Plan → Exec
- **Duration**: < 2 hours
- **Rationale**: Low complexity doesn't warrant design formality

### **M Scale** (Medium)
- **Criteria**: 4–10 API endpoints, 2–5 data models, simple state transitions
- **Examples**: New payment method, user role system, basic notification feature
- **Path**: PRD → Design → Plan → Exec
- **Duration**: 2–8 hours
- **Rationale**: Need API contract definition, but no architectural decisions yet

### **L Scale** (Large)
- **Criteria**: >10 endpoints, complex state machine, cross-service dependencies
- **Examples**: Auth system, multi-tenant data model, distributed transaction flow
- **Path**: PRD → Design → ADR → Plan → Exec
- **Duration**: 8+ hours
- **Rationale**: Major architectural decisions require ADR (Architecture Decision Record)

---

## API Contract Mechanism

Contracts ensure frontend, backend, and tests stay aligned without constant re-sync.

### **What is a Contract?**

Three formal sections in Design Doc that define implementation boundaries:

1. **API Endpoint Contract** — Request/response shapes, status codes
2. **State/Enum Contract** — Valid values and allowed transitions
3. **Field Mapping Contract** — Snake_case DB → camelCase DTO → camelCase FE

### **Three-Stage Lifecycle**

```
Stage 1: Design (cx-design)
  ├─ Write contract sections in Design Doc
  └─ Reference existing API patterns from codebase

Stage 2: Sink (cx-plan)
  ├─ Extract contract fragments
  └─ Embed into each task file for context

Stage 3: Validate (cx-exec)
  ├─ Compare implementation against contract
  ├─ Catch missing fields, wrong status codes
  └─ Reject if mismatches found
```

### **Why Contracts?**

- **No constant re-discussion**: Contract is the source of truth
- **Parallel work**: Frontend dev doesn't wait for backend API decision
- **Automated validation**: cx-exec detects drift automatically
- **Clear scope boundaries**: What's in vs. out is explicit

### **Contract Validation in cx-exec**

When you implement a task:

1. cx-exec reads the contract embedded in task file
2. Parses your code changes (via ast/regex pattern matching)
3. Compares actual vs. contract:
   - All endpoint paths match?
   - All response fields present?
   - Status codes correct?
4. If mismatch → reject with specific diff
5. If pass → continue to next task

---

## GitHub Sync Modes

Configure in `.claude/cx/config.json` with `github_sync` field.

### **off** — Pure Local (Default Safe)
- No GitHub integration at all
- All files stay in `.claude/cx/` directory
- **Use when**: Solo development, private prototype
- **Closure**: `cx-summary` generates local `summary.md` only

### **local** — Local Dev + Sync at End
- Development entirely local
- `cx-summary` creates one summary Issue at the end
- **Use when**: Solo dev but want issue trail for tracking
- **Closure**: All code committed locally → Issue created → Done

### **collab** — Key Docs as Issues (Team Review)
- PRD and Design Doc created as Issues immediately
- Team can review and comment
- Execution stays local
- `cx-summary` creates summary Issue + opens PR
- **Use when**: Async team feedback on design before execution
- **Closure**: Design Issue reviewed → Local exec → Summary Issue → PR opened

### **full** — All Docs as Issues (CX 1.0 Style)
- Every artifact (PRD, Design, ADR, Plan, Summary) created as Issue
- Maximum transparency
- Higher ceremony
- **Use when**: Larger team, formal approval gates
- **Closure**: All Issues created → Exec locally → Summary closes Issues + merges PR

### **Scenario Examples**

| Scenario | Mode | Reason |
|----------|------|--------|
| Personal side project | off | No noise, full speed |
| Startup, 2-3 devs | local | Simple audit trail |
| Team of 5+, need reviews | collab | Design visibility without overhead |
| Regulated/compliance | full | Complete documentation |

---

## CLAUDE.md Management Rules

CLAUDE.md is a **rules file**, not a log. Keep it ≤30 lines in the CX segment.

### **What Goes In?**

- Current active feature (1 line)
- Key project conventions (naming, API paths, test commands)
- Any active task context

### **What Doesn't?**

- ❌ Historical record (completed features)
- ❌ Full design docs (reference Design Doc file instead)
- ❌ Implementation details (those go in code)
- ❌ Verbose descriptions (be terse)

### **Update Timing**

| Trigger | Behavior |
|---------|----------|
| cx-init | Insert new CX segment if missing |
| cx-exec | Update only the "active task" progress line (numbers) |
| cx-summary | Smart check: new conventions detected? Ask user. Else silent. |
| cx-fix | No update (too lightweight) |

### **cx-summary Smart Update**

After all tasks done:

1. **Auto-clean**: Remove completed feature from "active task"
2. **Auto-analyze**: Scan Design Doc, ADR, git diff for NEW conventions
3. **Smart decide**:
   - No new conventions → silent completion
   - New conventions found → AskUserQuestion: "Update project rules?"
     - Yes → Show diff (old vs new) → User confirms → Update
     - No → Skip
4. **Guard**: Ensure CX segment stays ≤30 lines after update

---

## Troubleshooting

### **"I modified code but cx-exec rejected it for contract mismatch"**

**Root cause**: Implementation doesn't match contract in Design Doc.

**Fix**:
1. Open `features/<slug>/design.md`
2. Check the contract section for your endpoint
3. Compare against what you actually wrote
4. Update code OR update contract (discuss with team first)
5. Re-run cx-exec

### **"cx-exec got interrupted, how do I resume?"**

**Root cause**: Session ended mid-task.

**Fix**:
1. Check `.claude/cx/status.json`
2. Find `in_progress` task
3. Run `/cx-status` to see current state
4. Run `/cx-exec` again (reads from last state)
5. If still stuck, manually check `features/<slug>/tasks/` for incomplete task file

### **"cx-summary asks about CLAUDE.md every time"**

**Root cause**: Detects new conventions each run (maybe false positive from dev diff).

**Fix**:
1. Run cx-summary and choose "No"
2. Or manually edit `.claude/cx/config.json` and set `prompt_refresh_interval` to 0 to reduce noise
3. Review your git diff to ensure real conventions changed

### **"I want to skip design for a small feature but it looks M-scale"**

**Root cause**: PRD was evaluated as M (4+ endpoints).

**Fix**:
1. Re-run `/cx-prd` and clarify scope downward (cut endpoints)
2. Or accept the M-scale path (Design is only ~15 mins overhead)
3. Or manually override: edit `features/<slug>/prd.md` and change scale comment

### **"GitHub sync failing, says 'no token'"**

**Root cause**: Missing GitHub token in environment.

**Fix**:
1. Ensure `gh` CLI is installed (`gh --version`)
2. Authenticate: `gh auth login`
3. Verify: `gh api user` returns your info
4. Re-run cx-summary

### **"Code review subagent isn't catching obvious bugs"**

**Root cause**: Subagent prompt might be too broad or contract wasn't detailed enough.

**Fix**:
1. If full audit → repeat with "Quick Check" (simpler prompt)
2. Improve contract sections in Design Doc (more specific types/rules)
3. Add comments in code (subagent reads code + comments better)
4. File issue against cx-workflow for improved reviewer prompt

### **"Can't find my old PRD/Design Doc"**

**Root cause**: Files are in `features/<slug>/` directory based on feature slug, not memorable name.

**Fix**:
1. Run `/cx-status` to see current and past features
2. Check `.claude/cx/status.json` for feature → slug mapping
3. Browse `.claude/cx/features/` to find directory

### **"Is it OK to manually edit task files?"**

**Caution**: Yes, but be careful.

- ✅ Editing contract section at top of task file is fine
- ✅ Updating acceptance criteria if requirements changed
- ❌ Don't delete task file (cx-exec uses it for state)
- ❌ Don't rename without updating status.json

### **"How do I know if I should use Agent Teams?"**

**When to enable** (`config.agent_teams = true`):
- You have frontend and backend devs working in parallel
- You want them to align on contracts without constant sync calls
- Contract drift is a real problem on your team

**When to skip**:
- Solo dev (you are both)
- Small team where devs pair frequently
- Contract violations aren't a pain point yet

---

## Command Reference

| Command | When | Output |
|---------|------|--------|
| `/cx-init` | First time, or reset | config.json, .claude/cx/ setup |
| `/cx-prd <name>` | Start new feature | prd.md |
| `/cx-design` | After PRD + scale ≥ M | design.md |
| `/cx-adr` | L-scale only | adr.md |
| `/cx-plan` | Before execution | tasks/task-*.md with contracts |
| `/cx-exec` | Implement each task | code changes + commit |
| `/cx-fix <desc>` | Report bug | fix.md + code changes + commit |
| `/cx-summary` | All tasks done | summary.md + GitHub sync |
| `/cx-status` | Check progress | text overview |
| `/cx-help` | Need guidance | this document (or interactive) |
| `/cx-config` | Adjust settings | config.json view/edit |

---

## Files Generated During Workflow

```
.claude/cx/
├── config.json                    (developer ID, sync mode, hooks config)
├── status.json                    (current feature, tasks in progress)
├── context-snapshot.md            (saved before compaction)
├── hooks/                         (auto-installed)
└── features/
    └── <feature-slug>/
        ├── prd.md                 (requirements)
        ├── design.md              (architecture + 3 contracts)
        ├── adr.md                 (decisions, L-scale only)
        ├── summary.md             (final deliverable)
        └── tasks/
            ├── task-1.md          (backend API)
            ├── task-2.md          (frontend UI)
            └── task-3.md          (tests)
```

---

## See Also

- `contract-spec.md` — Detailed API contract format
- `templates/prd.md` — PRD template
- `templates/design.md` — Design Doc template with contract sections
- `templates/fix.md` — Bug Fix record template
- `config-schema.json` — Full config field reference
