# Code Review Guidance – Sample iOS Project

Shared criteria for human reviewers and AI tools (Copilot, Claude Code, Codex).

## Priorities (in order)

1. **MainActor and actor-isolation correctness** — UI work off the main actor, isolated state accessed from the wrong executor, missing `Sendable` on values that cross isolation domains
2. **Correctness and safety** — crashes, data loss, security
3. **Memory management** — retain cycles, `Timer` closures that capture `self` strongly, timers that are never invalidated on stop or `deinit`
4. **SwiftUI state ownership** — `@State`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`. A view-owned class `ObservableObject` must use `@StateObject`, not `@State`
5. **Project conventions** already established in earlier modules

## Do not flag

- Pure formatting / whitespace
- Naming preferences that do not affect clarity
- Unused helpers or force-unwraps in code this diff does not call
- Duplicate restatements of a finding already listed
- Suggestions that would require large unrelated refactors

## Preferred comment style

- List **only concrete high-severity issues** with `file:line` references
- One concrete issue per comment/bullet
- Suggest a **minimal fix**, not a redesign
- If there are no high-severity issues, say so briefly and stop
- Do not include process preamble

Example of a useful comment:

`CostByModelViewModel.swift:69` — `refreshRequestsColumn()` assigns the `@Published` property `slices` from `DispatchQueue.global`. Mark the type `@MainActor`, or hop back with `await MainActor.run { … }` before the assignment.