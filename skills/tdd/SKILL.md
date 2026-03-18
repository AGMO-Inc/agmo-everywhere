---
name: tdd
description: Use when implementing with test-driven development. Triggers on "TDD", "테스트 먼저", "test first", or when the plan specifies TDD.
---

# TDD — Test-Driven Development

## Iron Law

**No production code without a failing test.** No exceptions.

## Cycle

### RED — Write a Failing Test
1. Write a test that describes the desired behavior
2. Run the test — it MUST fail
3. If it passes, the test is wrong or the feature already exists

### GREEN — Make It Pass
1. Write the **minimum** code to make the test pass
2. Do not add anything beyond what the test requires
3. Run the test — it MUST pass now

### REFACTOR — Clean Up
1. Improve code quality without changing behavior
2. Run tests — they MUST still pass
3. Only refactor if there is a clear improvement

## Rules

1. **One test at a time.** Write one failing test, make it pass, then write the next.
2. **Test behavior, not implementation.** Tests should describe what, not how.
3. **No test? No code.** If you cannot write a test for it, reconsider if it is needed.
4. **Delete wrong tests.** If a test is testing the wrong thing, delete it and start over. Do not patch a bad test.
5. **Keep tests fast.** Each test should run in under 1 second.

## Anti-Patterns to Avoid

1. **Testing implementation details** — testing private methods, internal state
2. **Brittle tests** — tests that break when implementation changes but behavior does not
3. **Test duplication** — multiple tests verifying the same behavior
4. **Missing edge cases** — only testing the happy path
5. **Mock overuse** — mocking everything instead of testing real behavior

## Delegation

- Dispatch `executor` agent (standard) to write tests and implementation
- After GREEN phase, run `agmo:verification` to confirm
