# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 1.0.x (development) | Yes — best effort |
| Pre-1.0 tags (`v0.2`, `v0.6`, …) | No — historical only |

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security-sensitive reports.

Prefer:

1. GitHub **Private vulnerability reporting** (Security tab), when enabled on the repository
2. Or email the maintainers using the contact listed on the GitHub organization profile

Include:

- Impact description
- Reproduction steps or proof-of-concept (non-destructive)
- Affected commit / tag / device / iOS version if known

You should receive an acknowledgement within a reasonable time. We will coordinate a fix and disclosure timeline.

## Scope notes

JavaOne embeds a JVM and third-party emulator code (FreeJ2ME). Reports related to:

- Sandbox escape from a MIDlet into the iOS app container beyond intended Documents paths
- Path traversal in import / RMS / classpath staging
- Unsafe deserialization or unexpected native crashes triggered by untrusted JARs

…are in scope.

Out of scope examples:

- Crashes in individual poorly behaved MIDlets that stay contained
- Pure gameplay / compatibility bugs without security impact
- Issues solely in upstream FreeJ2ME or OpenJDK Mobile trackers (please also file upstream when appropriate)

## Safe handling of JARs

Treat unknown JARs as untrusted input. Prefer validating titles from known sources when testing.
