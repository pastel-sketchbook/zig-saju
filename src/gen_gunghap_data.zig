//! Generates saju pair compatibility (궁합) training data for microgpt-zig.
//!
//! Each line is: <person A 8 Hanja>|<person B 8 Hanja>|<label>
//! e.g. "壬申庚戌癸酉乙卯|甲子丙寅戊辰庚午|상"
//!
//! Labels: 상 (good), 중 (moderate), 하 (poor)
//!
//! Phase 1: Collect all unique FourPillars (iterate dates 1900-2050, dedup)
//! Phase 2: Shuffle with seed 42
//! Phase 3: Pair consecutive items, score each pair, output labeled lines

const std = @import("std");
const saju = @import("saju");

const Stem = saju.types.Stem;
const Branch = saju.types.Branch;
const Element = saju.types.Element;
const Pillar = saju.types.Pillar;
const FourPillars = saju.types.FourPillars;

const TARGET_PAIRS: usize = 50_000;

// ── Helpers (shared with gen_saju_data.zig) ──

fn writePillarHanja(writer: anytype, pillar: Pillar) !void {
    try writer.writeAll(pillar.stem.hanja());
    try writer.writeAll(pillar.branch.hanja());
}

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

const REPRESENTATIVE_HOURS = [12]u8{ 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22 };

// ── Scoring functions ──

/// Day master (일간) score: evaluates the interaction between two day stems.
/// Stem combination (천간합, indices differ by 5) → +5
/// Generating (상생, (a+1)%5 == b or (b+1)%5 == a) → +3
/// Same element → +1
/// Controlling (상극, (a+2)%5 == b or (b+2)%5 == a) → -2
fn dayMasterScore(stem_a: Stem, stem_b: Stem) i32 {
    const a_idx = @intFromEnum(stem_a);
    const b_idx = @intFromEnum(stem_b);

    // Stem combination (천간합): indices differ by exactly 5
    const diff = if (a_idx >= b_idx) a_idx - b_idx else b_idx - a_idx;
    if (diff == 5) return 5;

    const ea = @intFromEnum(stem_a.element());
    const eb = @intFromEnum(stem_b.element());

    // Same element
    if (ea == eb) return 1;

    // Generating (상생): (a+1)%5 == b means a generates b
    if ((ea + 1) % 5 == eb or (eb + 1) % 5 == ea) return 3;

    // Controlling (상극): (a+2)%5 == b means a controls b
    if ((ea + 2) % 5 == eb or (eb + 2) % 5 == ea) return -2;

    // Should not reach here (every pair is same, generating, or controlling)
    return 0;
}

/// Branch interaction score for a pair of branches.
/// Six harmony (육합) → +3
/// Three harmony (삼합, same index % 4) → +2
/// Clash (충, indices differ by 6) → -3
/// Neutral → 0
fn branchScore(branch_a: Branch, branch_b: Branch) i32 {
    const a = @intFromEnum(branch_a);
    const b = @intFromEnum(branch_b);

    // Six harmony (육합) pairs: (0,1), (2,11), (3,10), (4,9), (5,8), (6,7)
    const six_harmony = [6][2]u4{
        .{ 0, 1 },
        .{ 2, 11 },
        .{ 3, 10 },
        .{ 4, 9 },
        .{ 5, 8 },
        .{ 6, 7 },
    };
    for (six_harmony) |pair| {
        if ((a == pair[0] and b == pair[1]) or (a == pair[1] and b == pair[0]))
            return 3;
    }

    // Clash (충): indices differ by exactly 6
    const adiff = if (a >= b) a - b else b - a;
    if (adiff == 6) return -3;

    // Three harmony (삼합): same index % 4
    if (a % 4 == b % 4) return 2;

    return 0;
}

/// Element balance score: count all 5 elements across 16 positions (8 per person).
/// All 5 present → +2, any single element count ≥ 6 → -1
fn elementBalanceScore(a: FourPillars, b: FourPillars) i32 {
    var counts = [5]u8{ 0, 0, 0, 0, 0 };

    const a_pillars = [4]Pillar{ a.year, a.month, a.day, a.hour };
    const b_pillars = [4]Pillar{ b.year, b.month, b.day, b.hour };

    for (a_pillars) |p| {
        counts[@intFromEnum(p.stem.element())] += 1;
        counts[@intFromEnum(p.branch.element())] += 1;
    }
    for (b_pillars) |p| {
        counts[@intFromEnum(p.stem.element())] += 1;
        counts[@intFromEnum(p.branch.element())] += 1;
    }

    var score: i32 = 0;

    // All 5 elements present
    var all_present = true;
    for (counts) |c| {
        if (c == 0) {
            all_present = false;
            break;
        }
    }
    if (all_present) score += 2;

    // Penalty for excess
    for (counts) |c| {
        if (c >= 6) score -= 1;
    }

    return score;
}

/// Overall compatibility score for a pair of FourPillars.
/// dayMasterScore * 3 + 4 × branchScore (across all positions) + elementBalanceScore
fn scoreCompatibility(a: FourPillars, b: FourPillars) i32 {
    var score: i32 = 0;

    // Day master interaction (heaviest weight)
    score += dayMasterScore(a.day.stem, b.day.stem) * 3;

    // Branch interactions across all 4 pillar positions
    const a_branches = [4]Branch{ a.year.branch, a.month.branch, a.day.branch, a.hour.branch };
    const b_branches = [4]Branch{ b.year.branch, b.month.branch, b.day.branch, b.hour.branch };
    for (0..4) |i| {
        score += branchScore(a_branches[i], b_branches[i]);
    }

    // Element balance
    score += elementBalanceScore(a, b);

    return score;
}

const Label = enum { sang, jung, ha };

fn labelStr(label: Label) []const u8 {
    return switch (label) {
        .sang => "상",
        .jung => "중",
        .ha => "하",
    };
}

fn classify(score: i32) Label {
    if (score >= 12) return .sang;
    if (score >= 2) return .jung;
    return .ha;
}

pub fn main(init: std.process.Init) !void {
    const stdout_file = std.Io.File.stdout();
    const stderr_file = std.Io.File.stderr();

    var stdout_backing: [65536]u8 = undefined;
    var stderr_backing: [1024]u8 = undefined;

    var stdout_w = stdout_file.writer(init.io, &stdout_backing);
    var stderr_w = stderr_file.writer(init.io, &stderr_backing);

    const stdout = &stdout_w.interface;
    const stderr = &stderr_w.interface;

    // Phase 1: Collect all unique FourPillars
    try stderr.print("Phase 1: Collecting unique four-pillar combinations...\n", .{});
    try stderr.flush();

    const alloc = std.heap.page_allocator;

    var dedup = std.AutoHashMap([24]u8, void).init(alloc);
    defer dedup.deinit();

    var all_fps: std.ArrayList(FourPillars) = .empty;
    defer all_fps.deinit(alloc);

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
                        try all_fps.append(alloc, fp);
                    }
                }
            }
        }
    }

    try stderr.print("Collected {d} unique four-pillar combinations\n", .{all_fps.items.len});
    try stderr.flush();

    // Phase 2: Shuffle with seed 42
    try stderr.print("Phase 2: Shuffling...\n", .{});
    try stderr.flush();

    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    rng.shuffle(FourPillars, all_fps.items);

    // Phase 3: Pair consecutive items, score, output
    try stderr.print("Phase 3: Pairing and scoring...\n", .{});
    try stderr.flush();

    const num_pairs = @min(TARGET_PAIRS, all_fps.items.len / 2);
    var label_counts = [3]u64{ 0, 0, 0 }; // sang, jung, ha
    var score_sum: i64 = 0;
    var score_min: i32 = std.math.maxInt(i32);
    var score_max: i32 = std.math.minInt(i32);

    for (0..num_pairs) |i| {
        const a = all_fps.items[i * 2];
        const b = all_fps.items[i * 2 + 1];
        const score = scoreCompatibility(a, b);
        const label = classify(score);

        // Write: <A pillars>|<B pillars>|<label>\n
        const a_pillars = [4]Pillar{ a.year, a.month, a.day, a.hour };
        const b_pillars = [4]Pillar{ b.year, b.month, b.day, b.hour };
        for (a_pillars) |p| try writePillarHanja(stdout, p);
        try stdout.writeByte('|');
        for (b_pillars) |p| try writePillarHanja(stdout, p);
        try stdout.writeByte('|');
        try stdout.writeAll(labelStr(label));
        try stdout.writeByte('\n');

        label_counts[@intFromEnum(label)] += 1;
        score_sum += score;
        if (score < score_min) score_min = score;
        if (score > score_max) score_max = score;
    }

    try stdout.flush();

    // Print stats to stderr
    const total: f64 = @floatFromInt(num_pairs);
    try stderr.print("\n=== Statistics ===\n", .{});
    try stderr.print("Total pairs: {d}\n", .{num_pairs});
    try stderr.print("Score range: [{d}, {d}], mean: {d:.1}\n", .{
        score_min,
        score_max,
        @as(f64, @floatFromInt(score_sum)) / total,
    });
    try stderr.print("Labels:\n", .{});
    try stderr.print("  상 (good):     {d:6} ({d:.1}%)\n", .{ label_counts[0], @as(f64, @floatFromInt(label_counts[0])) / total * 100.0 });
    try stderr.print("  중 (moderate): {d:6} ({d:.1}%)\n", .{ label_counts[1], @as(f64, @floatFromInt(label_counts[1])) / total * 100.0 });
    try stderr.print("  하 (poor):     {d:6} ({d:.1}%)\n", .{ label_counts[2], @as(f64, @floatFromInt(label_counts[2])) / total * 100.0 });
    try stderr.flush();
}
