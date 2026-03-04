# Port Rationale: ssaju (TypeScript) to zig-saju (Zig)

## Overview

This document captures the findings, decisions, and trade-offs made while porting
[ssaju](https://github.com/golbin/ssaju) (a TypeScript Korean Four Pillars / 사주
astrology engine) to Zig as `zig-saju`.

## Source Analysis

### TypeScript ssaju Architecture

The original library is ~2,700 lines across 4 core modules plus an orchestrator:

| Module | Lines | Responsibility |
|:--|--:|:--|
| constants.ts | 457 | Lookup tables: 10 heavenly stems, 12 earthly branches, element maps, yin-yang maps, 10x10 TEN_GODS table, hidden stems, 12 stages, yongsin rules, solar term data, LUNAR_DATA |
| manse.ts | 718 | Calendar conversion, solar longitude (simplified VSOP87), solar term finding (Newton-Raphson), four pillars calculation, Korea DST handling, LMT correction |
| analyze.ts | 976 | Pillar detail building, gongmang, ten gods, 12 stages, five elements, twelve sals, stem/branch relations (합/충/형/파/해/원진/귀문/삼합/반합/방합), daeun/seyun/wolun, day strength, geukguk, yongsin, advanced sinsal, interpretation |
| format.ts | 413 | `generateMarkdownSummary` and `generateCompactText` formatters |
| calculate.ts | 108 | Orchestrator tying all modules together |

### Test Suite

13 TypeScript tests covering:
- Golden case: 1992-10-24 05:30 solar male (pillars, geukguk, yongsin, gongmang)
- Lunar/solar equivalence: lunar 1992-9-29 = solar 1992-10-24
- Hour boundaries: 23:30, 00:00, 01:00 on 2024-01-01
- LMT correction: longitude 126.9784 shifts hour pillar
- Lichun boundary: 2024-02-03 vs 2024-02-05
- Seyun ordering and current year inclusion
- Compact/Markdown output section verification
- Daeun start age >= 1

All key test cases were ported to Zig.

## What Was Ported

### Modules (4,309 lines of Zig, 7 source files)

| Zig Module | Lines | Maps To |
|:--|--:|:--|
| types.zig | 364 | Type definitions extracted from across all TS files |
| constants.zig | 370 | constants.ts (lookup tables, solar term data) |
| manse.zig | 569 | manse.ts (calendar engine, pillars) |
| analyze.zig | 1,322 | analyze.ts (relations, sals, daeun, geukguk, yongsin) |
| format.zig | 818 | format.ts (compact + markdown formatters) |
| root.zig | 610 | calculate.ts + public API surface |
| main.zig | 256 | CLI (no TS equivalent -- ssaju is library-only) |

### Core Algorithms

All core algorithms were ported faithfully:

1. **Solar longitude** -- simplified VSOP87 with 47 harmonic terms
2. **Solar term finding** -- Newton-Raphson iteration to find JD where solar longitude = target
3. **Four pillars derivation** -- year/month/day/hour stems and branches
4. **Lichun boundary** -- year and month pillars shift at Lichun (입춘), not Jan 1
5. **Day pillar** -- JDN difference from known base date (1992-10-24)
6. **Hour pillar** -- two-hour blocks with day stem -> hour stem mapping
7. **Ten gods** -- algorithmically computed (TS uses 10x10 table; Zig uses element/yin-yang logic)
8. **Twelve stages** -- bong-method and geo-method
9. **Hidden stems** -- per-branch lookup
10. **Five-element distribution** -- counting across all stems and branches
11. **Gongmang** -- based on day pillar's sexagenary index
12. **Stem relations** -- combination (합), clash (충)
13. **Branch relations** -- combination (합/육합), clash (충), punishment (형), destruction (파), harm (해), won-jin (원진), gwi-mun (귀문), triple combination (삼합), half combination (반합), directional combination (방합)
14. **Day strength** -- scoring the day master's strength across all pillars
15. **Geukguk** -- pattern classification (종왕격, 인수격, etc.)
16. **Yongsin** -- favorable element selection based on geukguk
17. **Daeun** -- direction, start age, 10-year luck periods
18. **Seyun** -- yearly fortune (5 years before and after reference year)
19. **Wolun** -- monthly fortune for 12 months
20. **Twelve sals and special sals** -- per-pillar sal classification
21. **Advanced sinsal** -- 천을귀인, 화개, 역마, 도화, etc.
22. **Interpretation text** -- geukguk-based summary paragraph
23. **Korea DST** -- 1960, 1987-1988 summer time correction
24. **LMT correction** -- longitude-based local mean time adjustment

### Output Formats

Both output formats ported:

- **Compact text** -- LLM-friendly ~950 token output
- **Markdown tables** -- human-readable formatted output

### Tests

66 Zig tests total, including:
- Unit tests inline in each module
- Integration tests in root.zig validating against TS golden cases

## What Was NOT Ported

| Feature | Reason |
|:--|:--|
| Arbitrary timezone support | TS uses `Intl.DateTimeFormat`; Zig has no equivalent. Scoped to KST only. Could add IANA tz support via a future dependency. |
| `now` injection for testing | TS allows passing a reference `Date` for deterministic tests. Zig uses `std.time.timestamp()`. Tests work around this by passing `current_year` explicitly. |
| `solarToLunar` / `lunarToSolar` top-level exports | Available directly via zig-klc. No need to re-export. |
| Relation priority scoring | TS `format.ts` ranks relations by priority score and generates caution text. Not included in Zig format module. |
| Current daeun marking with remaining years | TS marks current daeun with a star and shows remaining years. Zig daeun list doesn't track "current". |
| Per-pillar daeun sals | TS daeun items include a sinsal column. Zig daeun items omit this. |
| Manse reference codes | TS includes "이달/다음달/오늘/내일" section. Not in Zig output. |
| Current age calculation | TS computes `currentAge` from birth year. Not exposed in Zig `SajuResult`. |
| Input validation with error throwing | TS validates ranges and throws descriptive errors. Zig uses the type system (enums, u4/u8 ranges) and CLI-level validation. |

## Key Design Decisions

### 1. Index-Based Enums

All stems, branches, elements, etc. use `u4`/`u3`/`u2`/`u1` backed enums with
integer values matching their traditional ordering. String conversion happens only
at the output boundary (in format.zig). This gives type safety, compact storage,
and fast arithmetic.

### 2. Algorithmic Ten Gods

The TS library uses a 10x10 lookup table for ten gods. The Zig port computes them
algorithmically from element relationships and yin-yang polarity. This is more
compact, eliminates a large table, and is arguably clearer about the underlying
logic.

### 3. zig-klc Dependency

Rather than porting ssaju's inline lunar-solar conversion and JDN calculation, the
Zig port delegates to [zig-klc](https://github.com/psk-kr/zig-klc) which already
provides these with high accuracy (1391-2050 range). This follows the principle of
not reimplementing existing functionality.

### 4. KST-Only Timezone

The TS library supports arbitrary timezones via `Intl.DateTimeFormat`. Since saju
is traditionally a Korean practice and Zig has no built-in IANA timezone database,
the Zig port is scoped to KST (UTC+9) with Korea DST handling for the relevant
historical periods. This covers the primary use case without introducing a heavy
timezone dependency.

### 5. Named Struct Types

Zig anonymous struct literals don't unify across translation units (e.g., a struct
returned from `analyze.zig` can't be directly consumed in `root.zig` without a
named type). This led to creating explicit types like `StemRelationsResult`,
`BranchRelationsResult`, etc.

### 6. Fractional LMT Offset

The initial implementation of `addMinutesToDateTime` used integer rounding for the
minute offset, which caused a 1-minute discrepancy vs. the TS reference. Switching
to `addMinutesToDateTimeFractional` with floating-point offset and floor (matching
JS `Date` behavior) resolved this.

### 7. Writer Pattern for Formatters

Format functions accept `anytype` writer to avoid circular module dependencies and
work with any `std.Io.Writer`-compatible type. This matches Zig's standard library
conventions.

### 8. Signed Integer Modulo

Zig's `%` operator doesn't work on signed integers. All modular arithmetic uses
`@mod` and `@divFloor` instead, which was a recurring adjustment throughout the
port.

## Supported Range

- **ssaju (TS)**: 1900-2099
- **zig-klc**: 1391-2050
- **zig-saju**: 1900-2050 (intersection)

## What's Next

Potential future work, roughly ordered by value:

1. **Benchmark** -- measure calculation time and compare with TS
2. **Manse reference codes** -- add "이달/다음달/오늘/내일" section to output
3. **Current daeun tracking** -- mark current daeun and show remaining years
4. **Per-pillar daeun sals** -- add sinsal column to daeun items
5. **Relation priority scoring** -- rank relations and generate caution text
6. **Current age** -- expose in SajuResult
7. **`now` injection** -- accept optional reference timestamp for deterministic testing
8. **Extended year range** -- if zig-klc extends beyond 2050
9. **IANA timezone support** -- via external tz database if demand exists
10. **WASM target** -- compile to WebAssembly for browser use
