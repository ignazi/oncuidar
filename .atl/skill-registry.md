# Skill Registry

**Delegator use only.** Any agent that launches sub-agents reads this registry to resolve compact rules, then injects them directly into sub-agent prompts. Sub-agents do NOT read this registry or individual SKILL.md files.

See `_shared/skill-resolver.md` for the full resolution protocol.

## User Skills

| Trigger | Skill | Path |
|---------|-------|------|
| When user asks to create a new skill, add agent instructions, or document patterns for AI | skill-creator | C:\Users\marig\.config\opencode\skills\skill-creator\SKILL.md |
| When writing Go tests, using teatest, or adding test coverage | go-testing | C:\Users\marig\.config\opencode\skills\go-testing\SKILL.md |
| When user says "judgment day", "judgment-day", "review adversarial", "dual review", "doble review", "juzgar", "que lo juzguen" | judgment-day | C:\Users\marig\.config\opencode\skills\judgment-day\SKILL.md |

## Compact Rules

Pre-digested rules per skill. Delegators copy matching blocks into sub-agent prompts as `## Project Standards (auto-resolved)`.

### skill-creator
- Create skills when patterns are repeated, project conventions differ, or complex workflows need guidance
- Don't create skills for trivial patterns, existing documentation, or one-off tasks
- Skill structure: `skills/{skill-name}/SKILL.md` with optional `assets/` and `references/`
- Frontmatter required: name, description (with trigger), license (Apache-2.0), metadata.author, metadata.version
- Start with most critical patterns, use tables for decision trees, keep code examples minimal
- Register skill in AGENTS.md after creation
- Name conventions: generic `{technology}`, project-specific `{project}-{component}`, workflow `{action}-{target}`

### go-testing
- Use table-driven tests for multiple test cases with struct slices
- Test Bubbletea Model state transitions directly via `Model.Update()`
- Use teatest for interactive TUI testing with `teatest.NewTestModel()`
- Golden file testing for visual output comparison
- Test both success and error cases for functions returning errors
- Mock dependencies via interfaces, use `t.TempDir()` for file operations
- Commands: `go test ./...`, `go test -v ./...`, `go test -cover ./...`

### judgment-day
- Launch TWO sub-agents in parallel (async delegate) — never sequential
- Neither judge knows about the other — no cross-contamination
- Orchestrator NEVER reviews code itself — only launches judges, reads results, synthesizes
- Classify warnings: WARNING (real) = causes bug in normal usage, WARNING (theoretical) = requires contrived scenario
- After 2 fix iterations, ASK user before continuing — never escalate automatically
- Round 1: Present verdict table, ASK user to confirm fixes before applying
- APPROVED criteria: 0 confirmed CRITICALs + 0 confirmed real WARNINGs
- Fix Agent is separate delegation — never use a judge as fixer
- Skill Resolution: check `**Skill Resolution**` field in responses, re-read registry if fallback

## Project Conventions

| File | Path | Notes |
|------|------|-------|
| AGENTS.md | C:\Users\marig\.config\opencode\AGENTS.md | Global agent conventions — persona, rules, engram protocol |

Read the convention files listed above for project-specific patterns and rules. All referenced paths have been extracted — no need to read index files to discover more.