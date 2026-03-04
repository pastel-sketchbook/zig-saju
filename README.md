# zig-saju

A Zig port of [ssaju](https://github.com/golbin/ssaju) -- a tiny, fast Korean Four Pillars (사주/만세력) astrology engine.

Given a birth date and time, computes the Four Pillars (year, month, day, hour) using the sexagenary cycle (천간/지지), then derives ten gods, twelve stages, five-element distribution, stem/branch relations, gongmang, geukguk, yongsin, daeun, seyun, wolun, and special sals.

## Attribution

This project is a Zig port of **[ssaju](https://github.com/golbin/ssaju)** by [golbin (Jin)](https://github.com/golbin), originally written in TypeScript. All core algorithms -- solar longitude calculation (simplified VSOP87), solar term finding (Newton-Raphson), four pillars derivation, ten gods, twelve stages, stem/branch relations, geukguk/yongsin determination, and daeun/seyun/wolun generation -- are faithfully ported from the original.

Lunar-solar calendar conversion is provided by **[zig-klc](https://github.com/chunghha/zig-klc)** by [chunghha](https://github.com/chunghha), a Zig port of the [rs-klc](https://crates.io/crates/rs-klc) Rust crate. zig-klc provides KASI-verified Korean lunisolar date conversion, Julian Day Number calculation, and leap year detection.

## Features

- Four Pillars calculation from solar or lunar dates (1900--2050)
- Lichun (입춘) boundary-aware year/month pillar derivation
- Solar term calculation via simplified VSOP87 + Newton-Raphson
- Ten gods (십성), twelve stages (12운성), hidden stems (지장간)
- Five-element distribution (오행 분포)
- Stem relations: combination (합), clash (충)
- Branch relations: combination (합), clash (충), punishment (형), destruction (파), harm (해), won-jin (원진), gwi-mun (귀문), triple combination (삼합), half combination (반합), directional combination (방합)
- Gongmang (공망) calculation
- Day strength (일간 강약), geukguk (격국), yongsin (용신)
- Daeun (대운), seyun (세운), wolun (월운)
- Twelve sals (12신살) and special sals (특수신살)
- Compact text output (LLM-friendly) and Markdown table output
- CLI with full option support
- Korea DST handling (1960, 1987--1988)
- Local Mean Time (LMT) correction

## Dependencies

- [zig-klc](https://github.com/chunghha/zig-klc) -- Korean Lunisolar Calendar library for Zig (lunar-solar conversion, Julian Day Number, leap year detection), a Zig port of [rs-klc](https://crates.io/crates/rs-klc)

## Build

Requires Zig 0.15+.

```sh
zig build
```

Or using the Taskfile:

```sh
task build
```

## Usage

### CLI

```sh
# Basic: solar date, male
saju --year 1992 --month 10 --day 24 --hour 5 --minute 30

# Lunar calendar input
saju --year 1992 --month 9 --day 29 --calendar l --gender f

# With Local Mean Time correction and markdown output
saju --year 1992 --month 10 --day 24 --hour 5 --minute 30 \
     --longitude 126.9784 --lmt --format m
```

### CLI Options

| Flag | Description | Default |
|:--|:--|:--|
| `--year <YYYY>` | Birth year (1900--2050) | required |
| `--month <MM>` | Birth month (1--12) | required |
| `--day <DD>` | Birth day (1--31) | required |
| `--hour <HH>` | Birth hour (0--23) | 0 |
| `--minute <MM>` | Birth minute (0--59) | 0 |
| `--gender <m\|f>` | Gender | m |
| `--calendar <s\|l>` | Calendar type (solar/lunar) | s |
| `--leap` | Lunar leap month flag | off |
| `--longitude <deg>` | Longitude for LMT correction | -- |
| `--lmt` | Enable Local Mean Time correction | off |
| `--format <c\|m>` | Output format (compact/markdown) | c |

### Library

```zig
const saju = @import("saju");

const input = saju.SajuInput{
    .year = 1992,
    .month = 10,
    .day = 24,
    .hour = 5,
    .minute = 30,
    .gender = .male,
    .calendar = .solar,
};

const result = try saju.calculateSaju(input, 2026);

// Write compact output (LLM-friendly)
result.writeCompact(writer, 2026);

// Write markdown output
result.writeMarkdownFmt(writer, 2026);
```

## Testing

```sh
zig build test
# or
task test
```

66 tests covering:
- Constants: ten gods, hidden stems, twelve stages, month branches, solar term data
- Manse: four pillars calculation, Lichun boundary, hour boundaries, LMT correction, lunar-solar equivalence
- Analyze: gongmang, five elements, twelve sals, special sals, day strength, geukguk, yongsin, daeun, seyun, wolun, stem/branch relations
- Integration: golden case validation against TypeScript reference, format output verification

## Project Structure

```
zig-saju/
  build.zig           Build configuration
  build.zig.zon       Package metadata (declares zig-klc dependency)
  Taskfile.yml         Task runner for local dev
  src/
    root.zig           Public API: SajuResult, calculateSaju(), format methods
    main.zig           CLI entry point
    types.zig          Core types: Stem, Branch, Element, Pillar, FourPillars, ...
    constants.zig      Lookup tables, ten gods, hidden stems, solar term data
    manse.zig          Calendar engine: solar longitude, solar terms, pillars
    analyze.zig        Analysis: relations, sals, strength, geukguk, yongsin, daeun
    format.zig         Compact text and Markdown formatters
```

## Differences from ssaju (TypeScript)

| Feature | ssaju (TS) | zig-saju |
|:--|:--|:--|
| Timezone | Arbitrary `Intl.DateTimeFormat` | KST only (UTC+9) |
| Ten gods | 10x10 lookup table | Algorithmic computation |
| `now` injection | Supported for testing | Uses system clock |
| Relation priority scoring | Included in format output | Not ported |
| Current daeun marking | Shows remaining years | Daeun list without "current" tracking |
| Per-pillar daeun sals | Included | Not ported |
| Manse reference codes | "이달/다음달/오늘/내일" | Not ported |
| `solarToLunar`/`lunarToSolar` | Exported as top-level API | Available via zig-klc directly |

## License

MIT License. See [LICENSE](LICENSE).

This project is a port of [ssaju](https://github.com/golbin/ssaju) by Jin, also MIT licensed. It depends on [zig-klc](https://github.com/chunghha/zig-klc) by chunghha.
