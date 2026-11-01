# Security Policy

## Supported Versions

Only the `main` branch of this port receives security fixes. Older releases and
other copies of the port are not supported.

## Reporting a Vulnerability

**Do not report security vulnerabilities through public GitHub issues.**

This is an unofficial Factory Droid port. Report vulnerabilities in this port (its
hooks, droids, skills, or permission rules) through GitHub's private vulnerability
reporting for this fork:

**[Report a vulnerability in this port →](https://github.com/LavX/factory.ai-droid-game-studios/security/advisories/new)**

Report vulnerabilities in the upstream framework through upstream's private
reporting:

**[Report a vulnerability in the upstream framework →](https://github.com/Donchitos/Claude-Code-Game-Studios/security/advisories/new)**

Use the fork's issue tracker only for problems that are not security issues.

Include as much detail as possible:
- Description of the vulnerability and what it affects
- Steps to reproduce
- Potential impact and attack scenarios
- Any suggested mitigations

## What Is In Scope

CCGS is a **local development tool** — it installs shell hooks and coordinates
AI agents that run directly on your machine. Security issues are primarily about
contributed code that executes in users' environments without their awareness.

### High Severity
- Hooks (`.factory/hooks/*.sh`) that execute malicious or undisclosed shell
  commands on user machines
- Skills or agents that exfiltrate environment variables, API keys, or secrets
- Prompt injection via skill or agent definitions that causes Droid to bypass
  safety measures or take unauthorized destructive actions
- Contributions that silently alter behavior in ways users cannot audit

### Medium Severity
- Skills that make undisclosed outbound network requests
- Agent definitions that escalate permissions or bypass user confirmation prompts
- Hook patterns that behave differently across platforms to conceal behavior
- Skills that write outside their documented scope without an explicit user
  approval step

### Out of Scope
- The behavior of the underlying model or the Factory Droid CLI itself
  (report to Factory or the model provider)
- Bugs in the user's Factory Droid installation or editor extension
- Theoretical vulnerabilities with no realistic attack path
- Issues requiring physical access to the user's machine

## Security Guidelines for Contributors

When contributing hooks, skills, or agents:

- **Hooks must be POSIX-compatible** — use `grep -E`, not `grep -P`; avoid
  platform-specific syntax that behaves differently across operating systems
- **No silent network calls** from hooks or skills unless explicitly documented
  and opt-in by the user
- **No reading secrets or environment variables** beyond what is minimally
  required and clearly documented in the skill's header
- **Skills must not write outside their documented scope** without an explicit
  user confirmation step

## Disclosure Policy

We coordinate disclosure with the reporter:

1. You submit the vulnerability privately
2. We acknowledge the report
3. We confirm and assess severity
4. We develop and test a fix
5. We notify you before any public disclosure
6. Public disclosure happens after the fix ships

We credit reporters in release notes unless you prefer to remain anonymous.
