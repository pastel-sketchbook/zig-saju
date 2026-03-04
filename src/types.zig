const std = @import("std");
const testing = std.testing;

// =============================
// Core Enums
// =============================

/// 천간 (Heavenly Stems) — 10 stems of the sexagenary cycle.
pub const Stem = enum(u4) {
    gap = 0, // 甲 갑
    eul = 1, // 乙 을
    byeong = 2, // 丙 병
    jeong = 3, // 丁 정
    mu = 4, // 戊 무
    gi = 5, // 己 기
    gyeong = 6, // 庚 경
    sin = 7, // 辛 신
    im = 8, // 壬 임
    gye = 9, // 癸 계

    /// Returns the Hanja character for this stem.
    pub fn hanja(self: Stem) []const u8 {
        const table = [_][]const u8{ "甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸" };
        return table[@intFromEnum(self)];
    }

    /// Returns the Korean character for this stem.
    pub fn korean(self: Stem) []const u8 {
        const table = [_][]const u8{ "갑", "을", "병", "정", "무", "기", "경", "신", "임", "계" };
        return table[@intFromEnum(self)];
    }

    /// Returns the five-element of this stem.
    pub fn element(self: Stem) Element {
        const table = [_]Element{ .wood, .wood, .fire, .fire, .earth, .earth, .metal, .metal, .water, .water };
        return table[@intFromEnum(self)];
    }

    /// Returns the yin-yang polarity of this stem.
    pub fn yinYang(self: Stem) YinYang {
        return if (@intFromEnum(self) % 2 == 0) .yang else .yin;
    }

    /// Creates a Stem from a u4 index (0–9).
    pub fn fromIndex(idx: u4) Stem {
        return @enumFromInt(idx);
    }
};

/// 지지 (Earthly Branches) — 12 branches of the sexagenary cycle.
pub const Branch = enum(u4) {
    ja = 0, // 子 자
    chuk = 1, // 丑 축
    in_ = 2, // 寅 인
    myo = 3, // 卯 묘
    jin = 4, // 辰 진
    sa = 5, // 巳 사
    o = 6, // 午 오
    mi = 7, // 未 미
    sin = 8, // 申 신
    yu = 9, // 酉 유
    sul = 10, // 戌 술
    hae = 11, // 亥 해

    /// Returns the Hanja character for this branch.
    pub fn hanja(self: Branch) []const u8 {
        const table = [_][]const u8{ "子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥" };
        return table[@intFromEnum(self)];
    }

    /// Returns the Korean character for this branch.
    pub fn korean(self: Branch) []const u8 {
        const table = [_][]const u8{ "자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해" };
        return table[@intFromEnum(self)];
    }

    /// Returns the five-element of this branch.
    pub fn element(self: Branch) Element {
        const table = [_]Element{ .water, .earth, .wood, .wood, .earth, .fire, .fire, .earth, .metal, .metal, .earth, .water };
        return table[@intFromEnum(self)];
    }

    /// Returns the yin-yang polarity of this branch.
    pub fn yinYang(self: Branch) YinYang {
        return if (@intFromEnum(self) % 2 == 0) .yang else .yin;
    }

    /// Creates a Branch from a u4 index (0–11).
    pub fn fromIndex(idx: u4) Branch {
        return @enumFromInt(idx);
    }
};

/// 오행 (Five Elements).
pub const Element = enum(u3) {
    wood = 0, // 목
    fire = 1, // 화
    earth = 2, // 토
    metal = 3, // 금
    water = 4, // 수

    pub fn korean(self: Element) []const u8 {
        const table = [_][]const u8{ "목", "화", "토", "금", "수" };
        return table[@intFromEnum(self)];
    }

    pub fn hanja(self: Element) []const u8 {
        const table = [_][]const u8{ "木", "火", "土", "金", "水" };
        return table[@intFromEnum(self)];
    }
};

/// 음양 (Yin-Yang polarity).
pub const YinYang = enum(u1) {
    yang = 0, // 양
    yin = 1, // 음

    pub fn korean(self: YinYang) []const u8 {
        return if (self == .yang) "양" else "음";
    }
};

/// Gender for daeun direction calculation.
pub const Gender = enum(u1) {
    male = 0, // 남
    female = 1, // 여

    pub fn korean(self: Gender) []const u8 {
        return if (self == .male) "남" else "여";
    }
};

/// Calendar type for input.
pub const CalendarType = enum(u1) {
    solar = 0,
    lunar = 1,
};

/// 십신 (Ten Gods).
pub const TenGod = enum(u4) {
    bi_gyeon = 0, // 비견
    geop_jae = 1, // 겁재
    sik_sin = 2, // 식신
    sang_gwan = 3, // 상관
    pyeon_jae = 4, // 편재
    jeong_jae = 5, // 정재
    pyeon_gwan = 6, // 편관
    jeong_gwan = 7, // 정관
    pyeon_in = 8, // 편인
    jeong_in = 9, // 정인

    pub fn korean(self: TenGod) []const u8 {
        const table = [_][]const u8{ "비견", "겁재", "식신", "상관", "편재", "정재", "편관", "정관", "편인", "정인" };
        return table[@intFromEnum(self)];
    }
};

// =============================
// Composite Types
// =============================

/// A single pillar (주) — one stem + one branch.
pub const Pillar = struct {
    stem: Stem,
    branch: Branch,

    /// Returns the Hanja representation (e.g. "壬申").
    pub fn hanja(self: Pillar) struct { stem: []const u8, branch: []const u8 } {
        return .{ .stem = self.stem.hanja(), .branch = self.branch.hanja() };
    }

    /// Returns the combined Hanja string as a formatted pair.
    pub fn hanjaStr(self: Pillar, buf: []u8) []const u8 {
        const s = self.stem.hanja();
        const b = self.branch.hanja();
        if (buf.len < s.len + b.len) return "";
        @memcpy(buf[0..s.len], s);
        @memcpy(buf[s.len .. s.len + b.len], b);
        return buf[0 .. s.len + b.len];
    }

    /// Returns the sexagenary index (0–59) of this pillar.
    pub fn ganjiIndex(self: Pillar) u6 {
        const s: u8 = @intFromEnum(self.stem);
        const b: u8 = @intFromEnum(self.branch);
        // Find smallest n where n%10==s and n%12==b, 0 <= n < 60
        // Only valid combinations exist (same parity).
        var n: u8 = s;
        while (n < 60) : (n += 10) {
            if (n % 12 == b) return @intCast(n);
        }
        unreachable;
    }

    /// Creates a Pillar from a sexagenary index (0–59).
    pub fn fromGanjiIndex(idx: u6) Pillar {
        return .{
            .stem = Stem.fromIndex(@intCast(idx % 10)),
            .branch = Branch.fromIndex(@intCast(idx % 12)),
        };
    }
};

/// 사주 (Four Pillars) — year, month, day, hour.
pub const FourPillars = struct {
    year: Pillar,
    month: Pillar,
    day: Pillar,
    hour: Pillar,
};

/// 지장간 (Hidden Stems within a branch).
pub const HiddenStems = struct {
    yeogi: ?Stem, // 여기 (residual qi)
    junggi: ?Stem, // 중기 (middle qi)
    jeonggi: Stem, // 정기 (main qi) — always present
};

/// Input for saju calculation.
pub const SajuInput = struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8 = 0,
    minute: u8 = 0,
    gender: Gender = .male,
    calendar: CalendarType = .solar,
    leap: bool = false,
    longitude: ?f64 = null,
    apply_local_mean_time: bool = false,
};

/// Pillar position key.
pub const PillarKey = enum(u2) {
    year = 0,
    month = 1,
    day = 2,
    hour = 3,

    pub fn korean(self: PillarKey) []const u8 {
        const table = [_][]const u8{ "년", "월", "일", "시" };
        return table[@intFromEnum(self)];
    }
};

/// Solar date (year, month, day).
pub const SolarDate = struct {
    year: u16,
    month: u8,
    day: u8,
};

/// Date-time components for KST / calculation time.
pub const DateTime = struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
};

/// Normalized birth date info after lunar/solar conversion, DST, and LMT adjustments.
pub const NormalizedBirth = struct {
    solar: SolarDate,
    kst: DateTime,
    calculation: DateTime,
    local_mean_time: ?LocalMeanTimeInfo = null,
};

/// Local Mean Time adjustment details.
pub const LocalMeanTimeInfo = struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    longitude: f64,
    offset_minutes: f64,
    standard_longitude: f64,
};

// =============================
// Pillar Detail
// =============================

/// Detailed information for a single pillar.
pub const PillarDetail = struct {
    stem: Stem,
    branch: Branch,
    hidden_stems: HiddenStems,
    stem_ten_god: TenGod,
    /// Ten god of the branch's jeonggi (main hidden stem) relative to day stem.
    branch_ten_god: TenGod,
};

// =============================
// Tests
// =============================

test "stem hanja and korean" {
    try testing.expectEqualStrings("甲", Stem.gap.hanja());
    try testing.expectEqualStrings("갑", Stem.gap.korean());
    try testing.expectEqualStrings("癸", Stem.gye.hanja());
    try testing.expectEqualStrings("계", Stem.gye.korean());
}

test "stem element and yin-yang" {
    try testing.expectEqual(Element.wood, Stem.gap.element());
    try testing.expectEqual(Element.wood, Stem.eul.element());
    try testing.expectEqual(Element.water, Stem.gye.element());
    try testing.expectEqual(YinYang.yang, Stem.gap.yinYang());
    try testing.expectEqual(YinYang.yin, Stem.eul.yinYang());
}

test "branch hanja and korean" {
    try testing.expectEqualStrings("子", Branch.ja.hanja());
    try testing.expectEqualStrings("자", Branch.ja.korean());
    try testing.expectEqualStrings("亥", Branch.hae.hanja());
    try testing.expectEqualStrings("해", Branch.hae.korean());
}

test "branch element and yin-yang" {
    try testing.expectEqual(Element.water, Branch.ja.element());
    try testing.expectEqual(Element.earth, Branch.chuk.element());
    try testing.expectEqual(YinYang.yang, Branch.ja.yinYang());
    try testing.expectEqual(YinYang.yin, Branch.chuk.yinYang());
}

test "pillar ganji index round-trip" {
    // 甲子 = index 0
    const gap_ja = Pillar{ .stem = .gap, .branch = .ja };
    try testing.expectEqual(@as(u6, 0), gap_ja.ganjiIndex());
    const rt0 = Pillar.fromGanjiIndex(0);
    try testing.expectEqual(Stem.gap, rt0.stem);
    try testing.expectEqual(Branch.ja, rt0.branch);

    // 壬申 = index 8*6+... let's compute: stem=8(壬), branch=8(申)
    // n=8: 8%12=8 ✓ → index 8
    const im_sin = Pillar{ .stem = .im, .branch = .sin };
    try testing.expectEqual(@as(u6, 8), im_sin.ganjiIndex());

    // 癸酉 = stem=9, branch=9 → n=9: 9%12=9 ✓ → index 9
    const gye_yu = Pillar{ .stem = .gye, .branch = .yu };
    try testing.expectEqual(@as(u6, 9), gye_yu.ganjiIndex());

    // Full round-trip for all 60
    for (0..60) |i| {
        const idx: u6 = @intCast(i);
        const p = Pillar.fromGanjiIndex(idx);
        try testing.expectEqual(idx, p.ganjiIndex());
    }
}

test "ten god korean names" {
    try testing.expectEqualStrings("비견", TenGod.bi_gyeon.korean());
    try testing.expectEqualStrings("정인", TenGod.jeong_in.korean());
}

test "pillar hanjaStr formatting" {
    const p = Pillar{ .stem = .im, .branch = .sin };
    var buf: [16]u8 = undefined;
    const result = p.hanjaStr(&buf);
    try testing.expectEqualStrings("壬申", result);
}
