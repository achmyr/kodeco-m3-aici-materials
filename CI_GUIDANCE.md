Treat the CODE_REVIEW.md contents below as the authoritative review policy.
- Follow its priority order exactly. MainActor and actor-isolation correctness come first.
- Suppress any finding the "Do not flag" section marks as out of scope, including unused helpers or force-unwraps this diff does not call.
- Match the preferred comment style, including file:line references and a minimal fix. Do not include process preamble.