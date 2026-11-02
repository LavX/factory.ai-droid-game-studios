# Agent Coordination Rules

1. **Vertical Delegation**: Leadership agents delegate to department leads, who
   delegate to specialists. Never skip a tier for complex decisions.
2. **Horizontal Consultation**: Agents at the same tier may consult each other
   but must not make binding decisions outside their domain.
3. **Conflict Resolution**: When two agents disagree, escalate to the shared
   parent. If no shared parent, escalate to `creative-director` for design
   conflicts or `technical-director` for technical conflicts.
4. **Change Propagation**: When a design change affects multiple domains, the
   `producer` agent coordinates the propagation.
5. **No Unilateral Cross-Domain Changes**: An agent must never modify files
   outside its designated directories without explicit delegation.
6. **Read Design Docs by Section**: A brief names the sections an agent needs
   by heading. Find a heading in a GDD, ADR or the art bible with the Grep
   tool (`^#`, content mode) and Read that range with offset and limit; read a doc
   whole only when the task needs all of it, and say why. `validate-read.sh`
   refuses a whole-file read of a doc over 40 KB.
7. **Nothing Goes Upstream**: Never file, open or comment on an issue or pull
   request in an engine, plugin or vendor repository, even when asked. Write a
   draft (`/bug-report` drafts only) and the user submits it.

## Model Tier Assignment

Skills in this copy do not set a model. They run on the session model, and the upstream `model:` lines were removed. Droids set their own model in `.factory/droids/`. The three directors run on `claude-sonnet-5-5` with `reasoningEffort: xhigh`, and the other 46 droids run on `claude-haiku-5-5` with `reasoningEffort: max`. Factory's models page lists xhigh and max. Droid's subagent docs describe `reasoningEffort` in droid frontmatter as accepting low, medium, or high.

## Subagents vs Agent Teams

This project uses two distinct multi-agent patterns:

### Subagents (current, always active)
Started by the main session, not by another droid. A subagent cannot call Task,
so it cannot start another droid, and AskUser is disabled for it. Used by all
`team-*` skills and orchestration skills. Subagents return results to the parent.

**When to start in parallel**: If two subagents' inputs are independent (neither
needs the other's output to begin), start both at the same time
rather than waiting. Example: `/review-all-gdds` **Phase 2** (consistency) and
**Phase 3** (design theory) are independent — start both at the same time.
Phase 1 loads the GDDs and both depend on it, so it is the one phase here that
must NOT be parallelised.

### Agent Teams (experimental, opt-in)
Not set up in this copy. The upstream feature needs an experimental flag that this copy has not mapped to Droid. Do not propose agent teams until that mapping is confirmed.

## Parallel Droid Protocol

When an orchestration skill starts multiple independent droids:

1. Start all independent droids before waiting for any result
2. Collect all results before proceeding to dependent phases
3. If any agent is BLOCKED, surface it immediately — do not silently skip
4. Always produce a partial report if some agents complete and others block
