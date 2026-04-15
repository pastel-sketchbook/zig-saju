//! Generates saju training data for microgpt-zig.
//!
//! Each line is 8 Hanja pillar characters + "|" + 8 element Hanja,
//! e.g. "壬申庚戌癸酉乙卯|水金金土水金木木" (51 UTF-8 bytes per line).
//!
//! The element sequence maps 1:1 to pillar characters:
//! stem→stem.element().hanja(), branch→branch.element().hanja().
//!
//! Iterates over years 1900–2050, all 12 months, days 1–28+,
//! and 12 representative hours (one per 시 / 2-hour block).
//! Duplicate pillar combinations are deduplicated.

const std = @import("std");
const saju = @import("saju");

const Pillar = saju.types.Pillar;
const FourPillars = saju.types.FourPillars;

/// Writes a single pillar's Hanja (stem + branch = 6 bytes) to the writer.
fn writePillarHanja(writer: anytype, pillar: Pillar) !void {
    try writer.writeAll(pillar.stem.hanja());
    try writer.writeAll(pillar.branch.hanja());
}

/// Writes a single pillar's element Hanja (stem element + branch element = 6 bytes).
fn writePillarElements(writer: anytype, pillar: Pillar) !void {
    try writer.writeAll(pillar.stem.element().hanja());
    try writer.writeAll(pillar.branch.element().hanja());
}

/// Writes a full four-pillar line with element annotations.
/// Format: "壬申庚戌癸酉乙卯|水金金土水金木木\n" (51 bytes + newline).
fn writeFourPillarsLine(writer: anytype, fp: FourPillars) !void {
    const pillars = [4]Pillar{ fp.year, fp.month, fp.day, fp.hour };
    // Write 8 pillar Hanja
    for (pillars) |p| {
        try writePillarHanja(writer, p);
    }
    // Separator
    try writer.writeByte('|');
    // Write 8 element Hanja
    for (pillars) |p| {
        try writePillarElements(writer, p);
    }
    try writer.writeByte('\n');
}

/// Representative hours: one per 시 (two-hour block).
/// 子 (23-1) → 0, 丑 (1-3) → 2, 寅 (3-5) → 4, ... 亥 (21-23) → 22
const REPRESENTATIVE_HOURS = [12]u8{ 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22 };

/// Days in a given month (leap-year aware).
fn daysInMonth(year: u16, month: u8) u8 {
    const days_per_month = [12]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    if (month < 1 or month > 12) return 28;
    var d = days_per_month[month - 1];
    if (month == 2) {
        const y = @as(u32, year);
        if ((y % 4 == 0 and y % 100 != 0) or y % 400 == 0) d = 29;
    }
    return d;
}

/// Builds a 24-byte key from four pillars for deduplication.
fn buildKey(fp: FourPillars) [24]u8 {
    var key: [24]u8 = undefined;
    var pos: usize = 0;
    const pillars = [4]Pillar{ fp.year, fp.month, fp.day, fp.hour };
    for (pillars) |p| {
        const sh = p.stem.hanja();
        const bh = p.branch.hanja();
        @memcpy(key[pos .. pos + 3], sh[0..3]);
        pos += 3;
        @memcpy(key[pos .. pos + 3], bh[0..3]);
        pos += 3;
    }
    return key;
}

pub fn main(init: std.process.Init) !void {
    const stdout_file = std.Io.File.stdout();
    const stderr_file = std.Io.File.stderr();

    // Use a large buffer for stdout to minimize syscalls
    var stdout_backing: [65536]u8 = undefined;
    var stderr_backing: [1024]u8 = undefined;

    var stdout_w = stdout_file.writer(init.io, &stdout_backing);
    var stderr_w = stderr_file.writer(init.io, &stderr_backing);

    const stdout = &stdout_w.interface;
    const stderr = &stderr_w.interface;

    var line_count: u64 = 0;
    var dedup = std.AutoHashMap([24]u8, void).init(std.heap.page_allocator);
    defer dedup.deinit();

    for (1900..2051) |year_usize| {
        const year: u16 = @intCast(year_usize);
        for (1..13) |month_usize| {
            const month: u8 = @intCast(month_usize);
            const max_day = daysInMonth(year, month);
            for (1..@as(u16, max_day) + 1) |day_usize| {
                const day: u8 = @intCast(day_usize);
                for (REPRESENTATIVE_HOURS) |hour| {
                    const fp = saju.calculateFourPillars(year, month, day, hour, 0);
                    const key = buildKey(fp);

                    const gop = try dedup.getOrPut(key);
                    if (!gop.found_existing) {
                        try writeFourPillarsLine(stdout, fp);
                        line_count += 1;
                    }
                }
            }
        }
    }

    try stdout.flush();

    // Print stats to stderr
    try stderr.print("Generated {d} unique four-pillar lines\n", .{line_count});
    try stderr.flush();
}
