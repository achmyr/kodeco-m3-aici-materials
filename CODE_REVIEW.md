# Code Review Guidance – Sample iOS Project
## Priorities (in order)
1. Correctness and safety (crashes, data loss, security)
2. Swift concurrency (MainActor, Task isolation, Sendable)
3. Memory management (retain cycles, strong reference cycles in closures)
4. SwiftUI state ownership (@State, @StateObject, @ObservedObject, @EnvironmentObject)
5. Project conventions already established in earlier modules
## Do not flag
- Pure formatting / whitespace
- Naming preferences that do not affect clarity
- Suggestions that would require large unrelated refactors
## Preferred comment style
- One concrete issue per comment
- Include file path and line when possible
- Suggest a minimal fix rather than a redesign
