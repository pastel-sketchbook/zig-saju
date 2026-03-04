# Ported Features: Per-Pillar Daeun Sals, Relation Priority Scoring, Manse Reference Codes

## Overview

This document covers the three features ported from ssaju (TypeScript) to zig-saju
in the 0.2.0 release. These were previously listed as "Not ported" in the 0001 port
rationale.

## 1. Per-Pillar Daeun Sals

### What

Each 10-year daeun period now includes a `sals: SpecialSals` field indicating which
special sals (천을귀인, 역마살, 도화살, 화개살) apply to that daeun's branch.

### How

The `buildDaeunList` function in analyze.zig was extended with a `day_branch`
parameter. For each daeun period, `calculateSpecialSals(day_stem, day_branch,
daeun_branch)` is called to populate the sals field. The format module renders sals
as comma-separated names in both compact text and markdown table output.

### Design decision

The TS code computed sals inside the format layer. The Zig port computes them in the
analysis layer (`buildDaeunList`) so the data is available to any consumer, not just
formatters. This follows the principle of separating computation from presentation.

## 2. Relation Priority Scoring and Caution Points

### What

Relations (stem combinations/clashes, branch combinations/clashes/punishments/etc.)
are scored by priority weight and sorted in descending order. Strong clashes generate
advisory caution text strings.

### How

Two new functions in analyze.zig:

- `buildRelationPriorities(stem_rels, branch_rels) -> RelationPriorities` -- scores
  each relation and returns up to 16 items sorted by descending `score_x10`.
- `buildCautionPoints(stem_rels, branch_rels) -> CautionPoints` -- generates up to 8
  Korean advisory strings for strong clash/punishment relations.

### Scoring

Integer x10 scores avoid floating-point:

| Relation Type | Score (x10) |
|:--|--:|
| Branch 충 (clash) | 50 |
| Branch 형 (punishment) | 45 |
| Stem 충 (clash) | 48 |
| Branch 파 (destruction) | 35 |
| Branch 해 (harm) | 30 |
| Branch 원진 (won-jin) | 28 |
| Branch 귀문 (gwi-mun) | 25 |
| Stem 합 (combination) | 20 |
| Branch 합 (combination) | 18 |
| Branch 삼합/반합/방합 | 15 |

### Design decisions

- **Integer scores** (`score_x10: u16`) instead of floats. Avoids float comparison
  issues and keeps the zero-allocation constraint. Dividing by 10 at the output
  boundary gives the display value (e.g., 50 -> "5.0").
- **Fixed-capacity arrays** (`[16]RelationPriorityItem`, `[8]CautionPoints`) with a
  count field, matching the pattern used throughout the codebase.
- **Insertion sort** during building, not a separate sort step. Since there are at
  most ~16 items, this is efficient and avoids extra passes.

## 3. Manse Reference Codes

### What

Six hanja pillar codes for dates relative to the current moment: this year, next
year, this month, next month, today, and tomorrow. Plus a formatted "now" label.

### How

New functions in manse.zig:

- `encodePillarHanja(pillar: Pillar) -> HanjaCode` -- encodes a stem-branch pair as
  6 UTF-8 bytes (2 CJK characters, 3 bytes each).
- `advanceDateByDays(year, month, day, days) -> {year, month, day}` -- advances a
  date by N days using JDN arithmetic via zig-klc.
- `buildReferenceCodes(ref_time: DateTime) -> ReferenceCodes` -- computes all 6
  codes and the now label.

The TS library uses rough day offsets for "next year" (+370 days) and "next month"
(+32 days). The Zig port uses the same heuristic for faithful output parity.

### Design decisions

- **`HanjaCode` is `[6]u8`**, not a string or slice. Two CJK hanja characters are
  always exactly 3 UTF-8 bytes each, so the size is known at comptime. This avoids
  allocation and slice lifetime issues.
- **`now_label` uses `[21]u8` + length**. The formatted KST timestamp
  "YYYY-MM-DD HH:MM KST" is always 21 bytes, but a length field is included for
  safety.
- **`ref_time: DateTime` parameter** added to `calculateSaju` rather than reading
  system time internally. This enables deterministic testing (tests pass a fixed
  reference time) while the CLI passes the actual KST time. This also addresses
  the previously noted gap of "`now` injection" support.

## Impact

### API Change

`calculateSaju` now takes a 3rd parameter:

```zig
// Before
const result = try saju.calculateSaju(input, current_year);

// After
const result = try saju.calculateSaju(input, current_year, ref_time);
```

This is a breaking change to the public API, warranting the minor version bump to
0.2.0.

### Test Count

Tests grew from 66 (initial port) to 80:
- +4 daeun sals tests (analyze.zig)
- +5 relation priority / caution tests (analyze.zig)
- +4 manse reference code tests (manse.zig)
- +1 format 만세력 section assertion (format.zig)

### Zero-Allocation Maintained

All three features use fixed-size arrays and stack allocation only. No heap
allocations were introduced.

### Output Changes

Both compact text and markdown formatters now include three new sections:
- **관계 강도** -- relation priorities ranked by score
- **주의 포인트** -- advisory caution strings
- **만세력** -- reference hanja codes for 6 key dates
