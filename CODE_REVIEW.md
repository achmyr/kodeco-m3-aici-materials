# Code Review Guidance – Sample iOS Project

Shared criteria for human reviewers and AI tools (Copilot, Claude Code, Codex).

## Priorities (in order)

1. **Correctness and safety** — crashes, data loss, security
2. **Swift concurrency** — `MainActor`, Task isolation, `Sendable`
3. **Memory management** — retain cycles, strong reference cycles in closures/timers
4. **SwiftUI state ownership** — `@State`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`
5. **Project conventions** already established in earlier modules

## Do not flag

- Pure formatting / whitespace
- Naming preferences that do not affect clarity
- Suggestions that would require large unrelated refactors

## Preferred comment style

- List **only concrete high-severity issues** with `file:line` references
- One concrete issue per comment/bullet
- Suggest a **minimal fix**, not a redesign
- If there are no high-severity issues, say so briefly and stop
