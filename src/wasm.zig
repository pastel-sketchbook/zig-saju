/// WASM export layer for zig-saju.
///
/// Provides a thin FFI boundary between WebAssembly and the core saju library.
/// The `calculate` export writes JSON to a static buffer; JS reads it via
/// `getResultPtr`/`getResultLen` and `TextDecoder`.
const std = @import("std");
const saju = @import("saju");

// -- Static output buffer (64 KB, in WASM linear memory) --

var output_buf: [65536]u8 = undefined;
var output_len: u32 = 0;

/// Returns a pointer to the JSON result buffer in WASM linear memory.
export fn getResultPtr() [*]const u8 {
    return &output_buf;
}

/// Returns the byte length of the last JSON result.
export fn getResultLen() u32 {
    return output_len;
}

/// Calculates a complete saju analysis and writes the result as JSON.
///
/// Parameters (all integers passed as u32, float as f64):
///   year, month, day, hour, minute  — birth date/time
///   gender       — 0 = male, 1 = female
///   calendar     — 0 = solar, 1 = lunar
///   leap         — 0 = false, 1 = true (lunar leap month)
///   apply_lmt    — 0 = false, 1 = true (Local Mean Time correction)
///   longitude    — longitude for LMT (ignored if apply_lmt = 0)
///   current_year — current year for seyun centering
///   ref_year, ref_month, ref_day, ref_hour, ref_minute — KST reference time
///
/// Returns:
///    0  success (read JSON via getResultPtr / getResultLen)
///   -1  invalid input (e.g. invalid lunar date)
///   -2  JSON serialization overflow
export fn calculate(
    year: u32,
    month: u32,
    day: u32,
    hour: u32,
    minute: u32,
    gender: u32,
    calendar: u32,
    leap: u32,
    apply_lmt: u32,
    longitude: f64,
    current_year: u32,
    ref_year: u32,
    ref_month: u32,
    ref_day: u32,
    ref_hour: u32,
    ref_minute: u32,
) i32 {
    const input = saju.SajuInput{
        .year = @intCast(year),
        .month = @intCast(month),
        .day = @intCast(day),
        .hour = @intCast(hour),
        .minute = @intCast(minute),
        .gender = if (gender == 1) .female else .male,
        .calendar = if (calendar == 1) .lunar else .solar,
        .leap = leap != 0,
        .apply_local_mean_time = apply_lmt != 0,
        .longitude = if (apply_lmt != 0) longitude else null,
    };

    const ref_time = saju.DateTime{
        .year = @intCast(ref_year),
        .month = @intCast(ref_month),
        .day = @intCast(ref_day),
        .hour = @intCast(ref_hour),
        .minute = @intCast(ref_minute),
    };

    const cur_year: u16 = @intCast(current_year);

    const result = saju.calculateSaju(input, cur_year, ref_time) catch return -1;

    var w: std.Io.Writer = .fixed(&output_buf);
    result.writeJson(&w, cur_year) catch return -2;
    output_len = @intCast(w.buffered().len);

    return 0;
}
