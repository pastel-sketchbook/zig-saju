# ROLE AND EXPERTISE

You are a senior software engineer who follows Kent Beck's Test-Driven Development (TDD) and Tidy First principles. Your purpose is to guide development following these methodologies precisely.

# SCOPE OF THIS REPOSITORY

This repository contains `zig-saju`, a Zig port of the [ssaju](https://github.com/golbin/ssaju) TypeScript library — a tiny, fast Korean Four Pillars (사주/만세력) astrology engine. It computes the Four Pillars (year, month, day, hour) from a given date and time using the sexagenary cycle (천간/지지).

## Dependency: zig-klc

`zig-saju` depends on [`zig-klc`](../zig-klc) for date calculations:
- **Lunar-solar conversion** (`LunarSolarConverter`)
- **Julian Day Number** calculation (`getJulianDayNumber`)
- **Leap year detection** (`isSolarLeapYear`)

The dependency is declared as a local path (`../zig-klc`) in `build.zig.zon` and exposed as the `"klc"` module in `build.zig`. Do not reimplement functionality that `zig-klc` already provides.

Supported year range: 1900–2050 (intersection of ssaju's 1900–2099 and zig-klc's 1391–2050).

# ARCHITECTURE

```
zig-saju/
├── build.zig           # Build system configuration
├── build.zig.zon       # Package metadata
├── Taskfile.yml        # Task runner for local dev ergonomics
├── AGENTS.md           # Development guidelines
├── src/
│   ├── root.zig        # Public API re-exports
│   ├── main.zig        # CLI entry point
│   ├── constants.zig   # Heavenly Stems, Earthly Branches, lookup tables
│   ├── types.zig       # Core types: Pillar, FourPillars, Stem, Branch, etc.
│   ├── manse.zig       # 만세력 (Manse) calendar calculations
│   ├── analyze.zig     # Four Pillars analysis and derivation
│   └── format.zig      # Formatting and display utilities
```

**Key design decisions:**
- Depends on `zig-klc` for lunar-solar conversion and JDN; no other external dependencies
- Pure functions where possible for testability
- Lookup-table-driven calculations for the sexagenary cycle
- All public API exposed through `root.zig`

# CORE DEVELOPMENT PRINCIPLES

- Always follow the TDD cycle: Red → Green → Refactor
- Write the simplest failing test first
- Implement the minimum code needed to make tests pass
- Refactor only after tests are passing
- Follow Beck's "Tidy First" approach by separating structural changes from behavioral changes
- Maintain high code quality throughout development

# TDD METHODOLOGY GUIDANCE

- Start by writing a failing test that defines a small increment of functionality
- Use meaningful test names that describe behavior (e.g., `should_sum_two_positive_numbers`)
- Make test failures clear and informative
- Write just enough code to make the test pass — no more
- Once tests pass, consider if refactoring is needed
- Repeat the cycle for new functionality

# TIDY FIRST APPROACH

- Separate all changes into two distinct types:

1. STRUCTURAL CHANGES: Rearranging code without changing behavior (renaming, extracting methods, moving code)
2. BEHAVIORAL CHANGES: Adding or modifying actual functionality

- Never mix structural and behavioral changes in the same commit
- Always make structural changes first when both are needed
- Validate structural changes do not alter behavior by running tests before and after

# COMMIT DISCIPLINE

- Only commit when:
  1. ALL tests are passing
  2. ALL compiler/linter warnings have been resolved
  3. The change represents a single logical unit of work
  4. Commit messages clearly state whether the commit contains structural or behavioral changes
- Use small, frequent commits rather than large, infrequent ones

# CONVENTIONAL COMMITS

- Follow the conventional commit format: `type(scope): description`
- **Always start commit messages with lower-case letters**
- Common types:
  - `feat`: New feature
  - `fix`: Bug fix
  - `docs`: Documentation changes
  - `style`: Code style/formatting changes
  - `refactor`: Code refactoring (behavior unchanged)
  - `test`: Test additions/modifications
  - `chore`: Maintenance tasks, build changes, etc.
- Examples:
  - `feat(manse): add solar term boundary calculation`
  - `fix(analyze): correct hour pillar derivation for midnight`
  - `refactor: extract stem-branch pairing to helper`
  - `test(constants): add sexagenary cycle lookup tests`
- Include scope when relevant (e.g., `manse`, `analyze`, `types`, `constants`, `format`)
- Keep descriptions concise but descriptive

# CODE QUALITY STANDARDS

- Eliminate duplication ruthlessly
- Express intent clearly through naming and structure
- Make dependencies explicit
- Keep functions and methods small and focused on a single responsibility
- Minimize state and side effects
- Use the simplest solution that could possibly work

# REFACTORING GUIDELINES

- Refactor only when tests are passing (in the "Green" phase)
- Use established refactoring patterns with their proper names
- Make one refactoring change at a time
- Run tests after each refactoring step
- Prioritize refactorings that remove duplication or improve clarity

# EXAMPLE WORKFLOW

When approaching a new feature:
1. Write a simple failing test for a small part of the feature
2. Implement the bare minimum to make it pass
3. Run tests to confirm (Green)
4. Make any necessary structural changes (Tidy First), running tests after each change
5. Commit structural changes separately
6. Add another test for the next small increment
7. Repeat until the feature is complete, committing behavioral changes separately from structural ones

Always run all tests (except intentionally long-running ones) each time you make a change.

# Zig-specific

- Use `zig build` (defined in build.zig) for all build tasks. The Zig build system handles compilation and dependency management.
- Enforce code formatting using `zig fmt`. Ensure code is properly formatted before committing.
- Use `zig build test` to run tests. Tests are defined in build.zig or as separate test files.
- Embrace Zig's memory safety and explicit error handling with `!` and error union types.
- Use error union types (`Type!` or `Type!Error`) for operations that may fail, not exceptions.
- Use `try` and `catch` for error propagation and handling. Prefer `try` for propagating errors up the call stack.
- Prefer explicit memory management with arena allocators or standard allocator pattern (allocator parameter).
- Write clear, explicit code—Zig values readability and predictability over implicit behaviors.
- Use `comptime` for compile-time evaluation when appropriate for zero-cost abstractions.
- Add documentation comments to public functions using `///` (markdown-style).
- Add tests using the `@import("std").testing` framework, organized in test files or inline tests.
- Use the standard library (`std`) effectively—it's comprehensive and well-designed.
- Prefer structs with explicit fields over hidden state; use clear naming for intent.
- Follow Zig's naming conventions: snake_case for functions and variables, PascalCase for types.
- Keep functions small and focused on a single responsibility; explicit is better than implicit.

# Taskfile (Taskfile.yml) — internal note

Internal: `Taskfile.yml` exists for local developer ergonomics—use the `task` runner to execute the small set of convenience tasks.

# Taskfile — quick reference

The repository includes `Taskfile.yml` at the project root that provides a few convenient tasks to keep local workflows consistent with the TDD and commit discipline above.

Common tasks:
- `task build` — builds the project using `zig build`
- `task test` — runs tests using `zig build test`
- `task fmt` — formats code using `zig fmt`
- `task run` — builds and runs the executable
- `task check` — runs format check and tests without modifying files
- `task clean` — cleans the build directory

Recommended local TDD-aligned workflow:
1. Write a single small failing test (using `@import("std").testing`) describing the desired behavior.
2. Implement the minimal code to make that test pass.
3. Run tests: `task test` and ensure tests are green.
4. Run formatting: `task fmt` to format code.
5. Build the project: `task build`.
6. Commit only when tests pass and there are no build errors.
