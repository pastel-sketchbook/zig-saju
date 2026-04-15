const std = @import("std");
const testing = std.testing;
const types = @import("types.zig");
const Stem = types.Stem;
const Branch = types.Branch;
const TenGod = types.TenGod;
const HiddenStems = types.HiddenStems;

// =============================
// General Constants
// =============================

pub const STANDARD_LONGITUDE: f64 = 135.0;
pub const SEOUL_LONGITUDE: f64 = 126.9784;
pub const BASE_KST_OFFSET_MINUTES: i32 = 9 * 60; // UTC+9
pub const MIN_SUPPORTED_YEAR: u16 = 1900;
pub const MAX_SUPPORTED_YEAR: u16 = 2050;

// =============================
// Korea DST Periods
// =============================

pub const DstPeriod = struct {
    start: LocalTime,
    end: LocalTime,
};

pub const LocalTime = struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
};

pub const KOREA_DST_PERIODS = [_]DstPeriod{
    .{
        .start = .{ .year = 1960, .month = 5, .day = 1, .hour = 0, .minute = 0 },
        .end = .{ .year = 1960, .month = 9, .day = 13, .hour = 0, .minute = 0 },
    },
    .{
        .start = .{ .year = 1987, .month = 5, .day = 10, .hour = 2, .minute = 0 },
        .end = .{ .year = 1987, .month = 10, .day = 11, .hour = 3, .minute = 0 },
    },
    .{
        .start = .{ .year = 1988, .month = 5, .day = 8, .hour = 2, .minute = 0 },
        .end = .{ .year = 1988, .month = 10, .day = 9, .hour = 3, .minute = 0 },
    },
};

// =============================
// Ten Gods Lookup
// =============================

/// Computes the ten-god relationship from the day stem to another stem.
/// This is purely algorithmic based on the element distance and yin-yang match.
pub fn getTenGod(day_stem: Stem, other_stem: Stem) TenGod {
    const day_elem: u8 = @intFromEnum(day_stem) / 2;
    const other_elem: u8 = @intFromEnum(other_stem) / 2;
    const same_polarity = (@intFromEnum(day_stem) % 2) == (@intFromEnum(other_stem) % 2);

    const forward_steps = (other_elem + 5 - day_elem) % 5;

    // 0=비겁, 1=식상, 2=재성, 3=관살, 4=인성
    // same polarity → 편(pyeon) variant, different → 정(jeong) variant
    // Exception: step 0 — same polarity = 비견, different = 겁재
    return switch (forward_steps) {
        0 => if (same_polarity) .bi_gyeon else .geop_jae,
        1 => if (same_polarity) .sik_sin else .sang_gwan,
        2 => if (same_polarity) .pyeon_jae else .jeong_jae,
        3 => if (same_polarity) .pyeon_gwan else .jeong_gwan,
        4 => if (same_polarity) .pyeon_in else .jeong_in,
        // Safe: forward_steps is (other_elem + 5 - day_elem) % 5, always 0-4.
        else => unreachable,
    };
}

// =============================
// Hidden Stems (지장간)
// =============================

/// Returns the hidden stems for a given earthly branch.
pub fn getHiddenStems(branch: Branch) HiddenStems {
    const table = [12]HiddenStems{
        .{ .yeogi = null, .junggi = null, .jeonggi = .gye }, // 子
        .{ .yeogi = .gye, .junggi = .sin, .jeonggi = .gi }, // 丑
        .{ .yeogi = .mu, .junggi = .byeong, .jeonggi = .gap }, // 寅
        .{ .yeogi = null, .junggi = null, .jeonggi = .eul }, // 卯
        .{ .yeogi = .eul, .junggi = .gye, .jeonggi = .mu }, // 辰
        .{ .yeogi = .mu, .junggi = .gyeong, .jeonggi = .byeong }, // 巳
        .{ .yeogi = null, .junggi = .gi, .jeonggi = .jeong }, // 午
        .{ .yeogi = .jeong, .junggi = .eul, .jeonggi = .gi }, // 未
        .{ .yeogi = .gi, .junggi = .im, .jeonggi = .gyeong }, // 申
        .{ .yeogi = null, .junggi = null, .jeonggi = .sin }, // 酉
        .{ .yeogi = .sin, .junggi = .jeong, .jeonggi = .mu }, // 戌
        .{ .yeogi = .mu, .junggi = .gap, .jeonggi = .im }, // 亥
    };
    return table[@intFromEnum(branch)];
}

// =============================
// Twelve Stages (12운성)
// =============================

pub const TwelveStage = enum(u4) {
    jang_saeng = 0, // 장생
    mok_yok = 1, // 목욕
    gwan_dae = 2, // 관대
    geon_rok = 3, // 건록
    je_wang = 4, // 제왕
    soe = 5, // 쇠
    byeong = 6, // 병
    sa = 7, // 사
    myo = 8, // 묘
    jeol = 9, // 절
    tae = 10, // 태
    yang = 11, // 양

    pub fn korean(self: TwelveStage) []const u8 {
        const table = [_][]const u8{ "장생", "목욕", "관대", "건록", "제왕", "쇠", "병", "사", "묘", "절", "태", "양" };
        return table[@intFromEnum(self)];
    }
};

/// 봉법 (Bong) twelve stages lookup. Returns the stage for stem at branch.
pub fn getTwelveStageBong(stem: Stem, branch: Branch) TwelveStage {
    // Each row: starting branch index for 장생, direction (+1 forward or -1 backward)
    // 甲: 亥=장생, forward → 장생 at 亥(11), so stage[branch] = (branch - 11 + 12) % 12
    // But the TS data is given per stem as an array indexed by branch.
    // Let's encode the TS table directly as stage indices.
    const table = [10][12]u4{
        // 甲: 목욕,장생,양,태,절,묘,사,병,쇠,제왕,건록,관대
        .{ 1, 0, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2 },
        // 乙: 병,사,묘,절,태,양,장생,목욕,관대,건록,제왕,쇠
        .{ 6, 7, 8, 9, 10, 11, 0, 1, 2, 3, 4, 5 },
        // 丙: 태,양,장생,목욕,관대,건록,제왕,쇠,병,사,묘,절
        .{ 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
        // 丁: 절,태,양,장생,목욕,관대,건록,제왕,쇠,병,사,묘
        .{ 9, 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8 },
        // 戊: 태,양,장생,목욕,관대,건록,제왕,쇠,병,사,묘,절
        .{ 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
        // 己: 절,태,양,장생,목욕,관대,건록,제왕,쇠,병,사,묘
        .{ 9, 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8 },
        // 庚: 사,묘,절,태,양,장생,목욕,관대,건록,제왕,쇠,병
        .{ 7, 8, 9, 10, 11, 0, 1, 2, 3, 4, 5, 6 },
        // 辛: 장생,목욕,관대,건록,제왕,쇠,병,사,묘,절,태,양
        .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
        // 壬: 건록,제왕,쇠,병,사,묘,절,태,양,장생,목욕,관대
        .{ 3, 4, 5, 6, 7, 8, 9, 10, 11, 0, 1, 2 },
        // 癸: 관대,건록,제왕,쇠,병,사,묘,절,태,양,장생,목욕
        .{ 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0, 1 },
    };
    return @enumFromInt(table[@intFromEnum(stem)][@intFromEnum(branch)]);
}

/// 거법 (Geo) twelve stages lookup. Returns the stage for stem at branch.
pub fn getTwelveStageGeo(stem: Stem, branch: Branch) TwelveStage {
    const table = [10][12]u4{
        // 甲: 장생,목욕,관대,건록,제왕,쇠,병,사,묘,절,태,양
        .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
        // 乙: 양,태,절,묘,사,병,쇠,제왕,건록,관대,목욕,장생
        .{ 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 },
        // 丙: 태,양,장생,목욕,관대,건록,제왕,쇠,병,사,묘,절
        .{ 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
        // 丁: 절,묘,사,병,쇠,제왕,건록,관대,목욕,장생,양,태
        .{ 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 11, 10 },
        // 戊: 태,양,장생,목욕,관대,건록,제왕,쇠,병,사,묘,절
        .{ 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
        // 己: 절,묘,사,병,쇠,제왕,건록,관대,목욕,장생,양,태
        .{ 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 11, 10 },
        // 庚: 사,병,쇠,제왕,건록,관대,목욕,장생,양,태,절,묘
        .{ 7, 6, 5, 4, 3, 2, 1, 0, 11, 10, 9, 8 },
        // 辛: 장생,목욕,관대,건록,제왕,쇠,병,사,묘,절,태,양
        .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
        // 壬: 건록,관대,목욕,장생,양,태,절,묘,사,병,쇠,제왕
        .{ 3, 2, 1, 0, 11, 10, 9, 8, 7, 6, 5, 4 },
        // 癸: 관대,목욕,장생,양,태,절,묘,사,병,쇠,제왕,건록
        .{ 2, 1, 0, 11, 10, 9, 8, 7, 6, 5, 4, 3 },
    };
    return @enumFromInt(table[@intFromEnum(stem)][@intFromEnum(branch)]);
}

// =============================
// Month Branch Mapping
// =============================

/// Month index (1-based: 1=寅월 ... 12=丑월) to Branch.
pub fn monthBranch(month_index: u8) Branch {
    // month 1 → 寅(2), month 2 → 卯(3), ..., month 11 → 子(0), month 12 → 丑(1)
    const table = [12]Branch{ .in_, .myo, .jin, .sa, .o, .mi, .sin, .yu, .sul, .hae, .ja, .chuk };
    if (month_index < 1 or month_index > 12) return .in_; // fallback
    return table[month_index - 1];
}

/// Year stem index → starting month stem index (for 寅월).
pub fn yearStemToMonthStartStemIndex(year_stem: Stem) u4 {
    const table = [10]u4{ 2, 4, 6, 8, 0, 2, 4, 6, 8, 0 };
    return table[@intFromEnum(year_stem)];
}

// =============================
// Solar Term Data
// =============================

/// The 12 major solar term target degrees (절기), in month order starting from 입춘.
pub const MAJOR_SOLAR_TERM_DEGREES = [12]f64{ 315, 345, 15, 45, 75, 105, 135, 165, 195, 225, 255, 285 };

/// Approximate day-of-year for each major solar term degree (for Newton-Raphson initial guess).
pub fn majorSolarTermApproxDay(degree: f64) f64 {
    if (degree == 315) return 35.85;
    if (degree == 345) return 65.5;
    if (degree == 15) return 95.0;
    if (degree == 45) return 125.5;
    if (degree == 75) return 156.0;
    if (degree == 105) return 187.0;
    if (degree == 135) return 219.0;
    if (degree == 165) return 251.0;
    if (degree == 195) return 283.0;
    if (degree == 225) return 315.0;
    if (degree == 255) return 340.0;
    if (degree == 285) return 5.0;
    return 35.85; // fallback
}

// =============================
// Yongsin Rules
// =============================

/// Yongsin (용신) rules per day stem: stems recommended when strong vs weak.
pub const YongsinRule = struct {
    strong: [3]Stem,
    weak: [3]Stem,
};

pub fn getYongsinRule(day_stem: Stem) YongsinRule {
    const table = [10]YongsinRule{
        .{ .strong = .{ .gyeong, .jeong, .gye }, .weak = .{ .gye, .byeong, .gi } }, // 甲
        .{ .strong = .{ .sin, .byeong, .mu }, .weak = .{ .gye, .byeong, .gi } }, // 乙
        .{ .strong = .{ .im, .gi, .gyeong }, .weak = .{ .gap, .gyeong, .im } }, // 丙
        .{ .strong = .{ .gye, .gyeong, .gap }, .weak = .{ .gap, .gyeong, .im } }, // 丁
        .{ .strong = .{ .gap, .gye, .byeong }, .weak = .{ .byeong, .gye, .gap } }, // 戊
        .{ .strong = .{ .gap, .gye, .byeong }, .weak = .{ .byeong, .gye, .gap } }, // 己
        .{ .strong = .{ .jeong, .gap, .im }, .weak = .{ .gi, .byeong, .gye } }, // 庚
        .{ .strong = .{ .im, .gap, .gi }, .weak = .{ .mu, .im, .byeong } }, // 辛
        .{ .strong = .{ .mu, .byeong, .gap }, .weak = .{ .gyeong, .eul, .jeong } }, // 壬
        .{ .strong = .{ .mu, .byeong, .sin }, .weak = .{ .gyeong, .gap, .jeong } }, // 癸
    };
    return table[@intFromEnum(day_stem)];
}

// =============================
// Month Labels (for 천덕귀인 etc.)
// =============================

pub const MONTH_LABELS = [12][]const u8{
    "正月",
    "二月",
    "三月",
    "四月",
    "五月",
    "六月",
    "七月",
    "八月",
    "九月",
    "十月",
    "十一月",
    "十二月",
};

pub const WOLUN_MONTH_NAMES = [12][]const u8{
    "인월(1월)",
    "묘월(2월)",
    "진월(3월)",
    "사월(4월)",
    "오월(5월)",
    "미월(6월)",
    "신월(7월)",
    "유월(8월)",
    "술월(9월)",
    "해월(10월)",
    "자월(11월)",
    "축월(12월)",
};

// =============================
// Tests
// =============================

test "ten god: same stem is bi_gyeon" {
    // 甲 vs 甲 = 비견
    try testing.expectEqual(TenGod.bi_gyeon, getTenGod(.gap, .gap));
    // 癸 vs 癸 = 비견
    try testing.expectEqual(TenGod.bi_gyeon, getTenGod(.gye, .gye));
}

test "ten god: known pairs from TS table" {
    // 甲 day, 乙 other = 겁재
    try testing.expectEqual(TenGod.geop_jae, getTenGod(.gap, .eul));
    // 甲 day, 丙 other = 식신
    try testing.expectEqual(TenGod.sik_sin, getTenGod(.gap, .byeong));
    // 甲 day, 庚 other = 편관
    try testing.expectEqual(TenGod.pyeon_gwan, getTenGod(.gap, .gyeong));
    // 甲 day, 辛 other = 정관
    try testing.expectEqual(TenGod.jeong_gwan, getTenGod(.gap, .sin));
    // 壬 day, 甲 other = 식신
    try testing.expectEqual(TenGod.sik_sin, getTenGod(.im, .gap));
    // 壬 day, 丁 other = 정재
    try testing.expectEqual(TenGod.jeong_jae, getTenGod(.im, .jeong));
    // 癸 day, 庚 other = 정인
    try testing.expectEqual(TenGod.jeong_in, getTenGod(.gye, .gyeong));
}

test "ten god: all 100 combinations match TS table" {
    // Full verification against the TS TEN_GODS table.
    // TEN_GODS[day][other] encoded as TenGod indices.
    // Row = day stem, Col = other stem
    const expected = [10][10]TenGod{
        // 甲
        .{ .bi_gyeon, .geop_jae, .sik_sin, .sang_gwan, .pyeon_jae, .jeong_jae, .pyeon_gwan, .jeong_gwan, .pyeon_in, .jeong_in },
        // 乙
        .{ .geop_jae, .bi_gyeon, .sang_gwan, .sik_sin, .jeong_jae, .pyeon_jae, .jeong_gwan, .pyeon_gwan, .jeong_in, .pyeon_in },
        // 丙
        .{ .pyeon_in, .jeong_in, .bi_gyeon, .geop_jae, .sik_sin, .sang_gwan, .pyeon_jae, .jeong_jae, .pyeon_gwan, .jeong_gwan },
        // 丁
        .{ .jeong_in, .pyeon_in, .geop_jae, .bi_gyeon, .sang_gwan, .sik_sin, .jeong_jae, .pyeon_jae, .jeong_gwan, .pyeon_gwan },
        // 戊
        .{ .pyeon_gwan, .jeong_gwan, .pyeon_in, .jeong_in, .bi_gyeon, .geop_jae, .sik_sin, .sang_gwan, .pyeon_jae, .jeong_jae },
        // 己
        .{ .jeong_gwan, .pyeon_gwan, .jeong_in, .pyeon_in, .geop_jae, .bi_gyeon, .sang_gwan, .sik_sin, .jeong_jae, .pyeon_jae },
        // 庚
        .{ .pyeon_jae, .jeong_jae, .pyeon_gwan, .jeong_gwan, .pyeon_in, .jeong_in, .bi_gyeon, .geop_jae, .sik_sin, .sang_gwan },
        // 辛
        .{ .jeong_jae, .pyeon_jae, .jeong_gwan, .pyeon_gwan, .jeong_in, .pyeon_in, .geop_jae, .bi_gyeon, .sang_gwan, .sik_sin },
        // 壬
        .{ .sik_sin, .sang_gwan, .pyeon_jae, .jeong_jae, .pyeon_gwan, .jeong_gwan, .pyeon_in, .jeong_in, .bi_gyeon, .geop_jae },
        // 癸
        .{ .sang_gwan, .sik_sin, .jeong_jae, .pyeon_jae, .jeong_gwan, .pyeon_gwan, .jeong_in, .pyeon_in, .geop_jae, .bi_gyeon },
    };

    for (0..10) |d| {
        for (0..10) |o| {
            const day_stem = Stem.fromIndex(@intCast(d));
            const other_stem = Stem.fromIndex(@intCast(o));
            const got = getTenGod(day_stem, other_stem);
            try testing.expectEqual(expected[d][o], got);
        }
    }
}

test "hidden stems: 子 has only jeonggi 癸" {
    const hs = getHiddenStems(.ja);
    try testing.expectEqual(@as(?Stem, null), hs.yeogi);
    try testing.expectEqual(@as(?Stem, null), hs.junggi);
    try testing.expectEqual(Stem.gye, hs.jeonggi);
}

test "hidden stems: 丑 has 癸,辛,己" {
    const hs = getHiddenStems(.chuk);
    try testing.expectEqual(@as(?Stem, Stem.gye), hs.yeogi);
    try testing.expectEqual(@as(?Stem, Stem.sin), hs.junggi);
    try testing.expectEqual(Stem.gi, hs.jeonggi);
}

test "hidden stems: 寅 has 戊,丙,甲" {
    const hs = getHiddenStems(.in_);
    try testing.expectEqual(@as(?Stem, Stem.mu), hs.yeogi);
    try testing.expectEqual(@as(?Stem, Stem.byeong), hs.junggi);
    try testing.expectEqual(Stem.gap, hs.jeonggi);
}

test "month branch mapping" {
    try testing.expectEqual(Branch.in_, monthBranch(1));
    try testing.expectEqual(Branch.myo, monthBranch(2));
    try testing.expectEqual(Branch.ja, monthBranch(11));
    try testing.expectEqual(Branch.chuk, monthBranch(12));
}

test "year stem to month start stem index" {
    try testing.expectEqual(@as(u4, 2), yearStemToMonthStartStemIndex(.gap)); // 甲→丙(2)
    try testing.expectEqual(@as(u4, 4), yearStemToMonthStartStemIndex(.eul)); // 乙→戊(4)
    try testing.expectEqual(@as(u4, 0), yearStemToMonthStartStemIndex(.mu)); // 戊→甲(0) // idx 4
}

test "twelve stage bong: 甲 at 子 is 목욕" {
    try testing.expectEqual(TwelveStage.mok_yok, getTwelveStageBong(.gap, .ja));
}

test "twelve stage bong: 辛 at 子 is 장생" {
    try testing.expectEqual(TwelveStage.jang_saeng, getTwelveStageBong(.sin, .ja));
}
