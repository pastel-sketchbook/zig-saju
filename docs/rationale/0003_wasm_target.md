# WASM Target: Core Logic as WebAssembly Module

## Overview

This document records the decision to add a WebAssembly (WASM) build target for
zig-saju, enabling the core Four Pillars calculation engine to run in browsers
and other WASM runtimes.

## Context

zig-saju's core logic (types, constants, manse, analyze, format) is already
cleanly separated from the CLI entry point (main.zig). The core library uses
only pure computation -- no filesystem, process, time, or network APIs. This
makes it inherently WASM-compatible.

The CLI (main.zig) uses OS-specific APIs that are unavailable in WASM:

- `std.process.args()` -- command-line argument parsing
- `std.time.timestamp()` -- system clock
- `std.fs.File.stdout()/stderr()` -- file descriptors
- `std.process.exit()` -- process termination

The dependency `zig-klc` is also pure computation (lunar-solar conversion,
Julian Day Number calculation) with no OS-specific APIs in its library module.

## Options Considered

### Export Strategy

Three approaches were evaluated for the WASM FFI boundary:

| Option | Description | Pros | Cons |
|:--|:--|:--|:--|
| **A. JSON to linear memory** | Single `calculate` export writes full result as JSON to a static buffer; JS reads via `TextDecoder` | Familiar JS API; single call per query; self-describing output | Requires JSON serializer; slightly larger WASM binary |
| **B. Shared struct in linear memory** | Export raw `SajuResult` bytes; JS reads fields by byte offset | Zero serialization cost; smallest binary | Fragile across versions; requires maintaining a JS-side decoder that mirrors Zig struct layout |
| **C. Multiple accessor exports** | Export individual getter functions (`getYearStem`, `getDayStrength`, etc.) | No serialization; each export is trivial | Many exports; chatty API; multiple WASM-to-JS boundary crossings per query |

### WASM Target

| Target | Description |
|:--|:--|
| `wasm32-freestanding` | No OS, no WASI. WASM module is completely standalone. |
| `wasm32-wasi` | WASI interface for I/O. Useful for running CLI in WASM runtimes (Wasmtime, etc.). |

## Decision

**Option A (JSON to linear memory)** with **wasm32-freestanding** target.

### Rationale

1. **JSON is the natural exchange format** for JavaScript consumers. The JS side
   calls one function, reads a buffer, and gets a fully parsed object with
   `JSON.parse()`. No additional decoder library or binary layout knowledge
   needed.

2. **Single function call** avoids repeated WASM boundary crossings. A saju
   calculation produces a rich result (~30 fields, nested arrays); querying each
   field individually via Option C would require dozens of calls.

3. **Version resilience**: JSON key names are stable across versions. Adding or
   reordering fields does not break consumers (unlike binary layout in Option B).

4. **Serialization cost is negligible**: the JSON output is ~12-15 KB for a full
   result. Writing it to a 64 KB static buffer takes microseconds -- well under
   the ~1 ms calculation time. There is no memory allocation.

5. **Freestanding target** is chosen because the library needs no WASI
   capabilities. No file I/O, no environment variables, no clocks. Freestanding
   produces the smallest WASM binary and works in any WASM runtime (browsers,
   Deno, Node.js, Cloudflare Workers, etc.).

## Implementation

### Architecture

```
src/wasm.zig     <- WASM export layer (thin, ~80 lines)
  | imports
src/root.zig     <- Core library (SajuResult.writeJson)
  | delegates to
src/format.zig   <- JSON serializer (writeJson function)
```

### Exported WASM Functions

| Export | Signature | Description |
|:--|:--|:--|
| `calculate` | `(year, month, day, hour, minute, gender, calendar, leap, applyLmt, longitude, currentYear, refYear, refMonth, refDay, refHour, refMinute) -> i32` | Runs calculation, writes JSON to buffer. Returns 0 on success, negative on error. |
| `getResultPtr` | `() -> i32` | Returns pointer to JSON result buffer in linear memory. |
| `getResultLen` | `() -> i32` | Returns byte length of last JSON result. |

### Return Codes

| Code | Meaning |
|:--|:--|
| `0` | Success |
| `-1` | Invalid input (e.g. invalid lunar date) |
| `-2` | JSON serialization buffer overflow |

### JS Usage

```js
const { instance } = await WebAssembly.instantiateStreaming(fetch('saju.wasm'));
const { calculate, getResultPtr, getResultLen, memory } = instance.exports;

// Parameters: year, month, day, hour, minute, gender(0=m/1=f),
//   calendar(0=solar/1=lunar), leap(0/1), applyLmt(0/1), longitude,
//   currentYear, refYear, refMonth, refDay, refHour, refMinute
const status = calculate(
    1992, 10, 24, 5, 30,  // birth date/time
    0, 0, 0,              // male, solar, no leap
    0, 0.0,               // no LMT
    2026,                  // current year
    2026, 3, 4, 12, 0     // reference time (KST)
);

if (status === 0) {
    const ptr = getResultPtr();
    const len = getResultLen();
    const bytes = new Uint8Array(memory.buffer, ptr, len);
    const result = JSON.parse(new TextDecoder().decode(bytes));
    console.log(result.pillars);
    console.log(result.dayStrength);
}
```

### Build

```sh
zig build wasm                              # debug
zig build wasm -Doptimize=ReleaseSmall      # optimized for size
```

Output: `zig-out/bin/saju.wasm`

## Trade-offs Accepted

- **WASM binary size**: the JSON serializer adds ~2-3 KB to the binary (primarily
  the `writeJson` function and format string data). With `ReleaseSmall`, the
  total WASM binary is expected to be under 100 KB.

- **Static buffer limit**: the 64 KB output buffer imposes a hard ceiling on JSON
  size. In practice, the largest possible output is ~15 KB, well within the
  limit.

- **No streaming**: the entire result is serialized before JS can read it. For a
  single calculation, this is fine. If batch processing were needed, a streaming
  approach would be worth revisiting.

## Future Work

- TypeScript type definitions (`.d.ts`) generated from the JSON schema
- NPM package wrapping the WASM module with a typed JS API
- Benchmark: native CLI vs WASM execution time
- WASI target for server-side WASM runtimes (optional)
