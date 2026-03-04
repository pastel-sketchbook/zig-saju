const std = @import("std");
const testing = std.testing;

/// Internal modules (for advanced use).
pub const types = @import("types.zig");
/// Lookup tables for stems, branches, ten gods, hidden stems, solar terms.
pub const constants = @import("constants.zig");
/// Calendar engine: solar longitude, solar terms, four pillars calculation.
pub const manse = @import("manse.zig");
/// Analysis: relations, sals, day strength, geukguk, yongsin, daeun/seyun/wolun.
pub const analyze = @import("analyze.zig");
/// Compact text and Markdown formatters.
pub const format = @import("format.zig");

// --- Core types ---

/// Heavenly Stem (천간): 甲乙丙丁戊己庚辛壬癸 (indices 0-9).
pub const Stem = types.Stem;
/// Earthly Branch (지지): 子丑寅卯辰巳午未申酉戌亥 (indices 0-11).
pub const Branch = types.Branch;
/// Five Elements (오행): 木火土金水.
pub const Element = types.Element;
/// Yin-Yang (음양).
pub const YinYang = types.YinYang;
/// Gender: male or female.
pub const Gender = types.Gender;
/// Calendar type: solar or lunar.
pub const CalendarType = types.CalendarType;
/// Ten God (십성): 비견, 겁재, 식신, 상관, 편재, 정재, 편관, 정관, 편인, 정인.
pub const TenGod = types.TenGod;
/// A stem-branch pair (간지).
pub const Pillar = types.Pillar;
/// The four pillars: year, month, day, hour.
pub const FourPillars = types.FourPillars;
/// Hidden stems (지장간) for a branch: up to 3 stems.
pub const HiddenStems = types.HiddenStems;
/// Input parameters for saju calculation.
pub const SajuInput = types.SajuInput;
/// Identifies one of the four pillars: year, month, day, hour.
pub const PillarKey = types.PillarKey;
/// A solar (Gregorian) date.
pub const SolarDate = types.SolarDate;
/// A date with time (year, month, day, hour, minute).
pub const DateTime = types.DateTime;
/// Normalized birth date after calendar conversion and DST adjustment.
pub const NormalizedBirth = types.NormalizedBirth;
/// Detailed analysis for a single pillar.
pub const PillarDetail = types.PillarDetail;

// --- Key functions ---

/// Computes the ten god relationship between two stems.
pub const getTenGod = constants.getTenGod;
/// Returns the hidden stems for a given branch.
pub const getHiddenStems = constants.getHiddenStems;
/// Calculates the four pillars from a solar date and time.
pub const calculateFourPillars = manse.calculateFourPillars;
/// Normalizes a birth date input (lunar-to-solar conversion, DST, LMT).
pub const normalizeBirthDate = manse.normalizeBirthDate;

// --- Analyze types ---

/// Day master strength classification: strong or weak.
pub const DayStrength = analyze.DayStrength;
/// Day strength result with classification and numeric score.
pub const DayStrengthResult = analyze.DayStrengthResult;
/// Geukguk (격국) classification.
pub const Geukguk = analyze.Geukguk;
/// Special sals (특수신살) for a pillar.
pub const SpecialSals = analyze.SpecialSals;
/// A single 10-year daeun (대운) period.
pub const DaeunItem = analyze.DaeunItem;
/// A single yearly seyun (세운) entry.
pub const SeyunItem = analyze.SeyunItem;
/// A single monthly wolun (월운) entry.
pub const WolunItem = analyze.WolunItem;
/// A stem-level relation (combination or clash).
pub const StemRelation = analyze.StemRelation;
/// Result of analyzing all stem relations across four pillars.
pub const StemRelationsResult = analyze.StemRelationsResult;
/// All branch-level relations across four pillars.
pub const BranchRelations = analyze.BranchRelations;
/// Advanced sinsal: gilsin (길신) and hyungsin (흉신) lists.
pub const AdvancedSinsal = analyze.AdvancedSinsal;

// =============================
// SajuResult — Complete analysis result
// =============================

/// Complete saju analysis result containing pillars, relations, sals, daeun, and more.
pub const SajuResult = struct {
    /// Original input.
    input: SajuInput,

    /// Normalized birth date info.
    normalized: NormalizedBirth,

    /// Four pillars (raw).
    pillars: FourPillars,

    /// Detailed per-pillar info (ten gods, hidden stems).
    pillar_details: [4]PillarDetail,

    /// Gongmang (empty) branches.
    gongmang: [2]Branch,

    /// Five elements count across all 8 positions (4 stems + 4 branches).
    five_elements: [5]u8,

    /// Twelve stages (봉법) per pillar: [year, month, day, hour].
    twelve_stages_bong: [4]constants.TwelveStage,

    /// Twelve stages (거법) per pillar: [year, month, day, hour].
    twelve_stages_geo: [4]constants.TwelveStage,

    /// Twelve sal per pillar.
    twelve_sals: [4][]const u8,

    /// Special sals per pillar.
    special_sals: [4]SpecialSals,

    /// Stem relations across pillars.
    stem_relations: StemRelationsResult,

    /// Branch relations across pillars.
    branch_relations: BranchRelations,

    /// Day strength analysis.
    day_strength: DayStrengthResult,

    /// Geukguk (격국).
    geukguk: Geukguk,

    /// Yongsin (용신) — 3 recommended stems.
    yongsin: [3]Stem,

    /// Advanced sinsal.
    advanced_sinsal: AdvancedSinsal,

    /// Daeun direction (true = forward/순행).
    daeun_forward: bool,

    /// Daeun start age and precision info.
    daeun_start_age: u8,
    daeun_precise_age: f64,
    daeun_diff_days: f64,

    /// Daeun list (10 periods).
    daeun: [10]DaeunItem,

    /// Seyun list (10 years centered on current year).
    seyun: [10]SeyunItem,

    /// Wolun list (12 months for current year).
    wolun: [12]WolunItem,

    /// Interpretation text buffer (stack-allocated).
    interpretation_buf: [1024]u8,
    interpretation_len: usize,

    /// Returns the interpretation text slice.
    pub fn interpretation(self: *const SajuResult) []const u8 {
        return self.interpretation_buf[0..self.interpretation_len];
    }

    /// Convenience: day stem.
    pub fn dayStem(self: *const SajuResult) Stem {
        return self.pillars.day.stem;
    }

    /// Convenience: day branch.
    pub fn dayBranch(self: *const SajuResult) Branch {
        return self.pillars.day.branch;
    }

    /// Writes compact text output to the given writer.
    pub fn writeCompact(self: *const SajuResult, writer: anytype, current_year: u16) !void {
        try format.writeCompactText(
            writer,
            self.input,
            self.normalized,
            self.pillars,
            self.pillar_details,
            self.gongmang,
            self.five_elements,
            self.twelve_stages_bong,
            self.twelve_stages_geo,
            self.twelve_sals,
            self.special_sals,
            self.stem_relations,
            self.branch_relations,
            self.day_strength,
            self.geukguk,
            self.yongsin,
            self.advanced_sinsal,
            self.daeun_forward,
            self.daeun_start_age,
            self.daeun,
            self.seyun,
            self.wolun,
            current_year,
        );
    }

    /// Writes markdown output to the given writer.
    pub fn writeMarkdownFmt(self: *const SajuResult, writer: anytype, current_year: u16) !void {
        try format.writeMarkdown(
            writer,
            self.input,
            self.normalized,
            self.pillars,
            self.pillar_details,
            self.gongmang,
            self.five_elements,
            self.twelve_stages_bong,
            self.twelve_stages_geo,
            self.twelve_sals,
            self.special_sals,
            self.stem_relations,
            self.branch_relations,
            self.day_strength,
            self.geukguk,
            self.yongsin,
            self.advanced_sinsal,
            self.daeun_forward,
            self.daeun_start_age,
            self.daeun,
            self.seyun,
            self.wolun,
            current_year,
            self.interpretation(),
        );
    }
};

// =============================
// calculateSaju — Orchestrator
// =============================

/// Errors that can occur during saju calculation.
pub const CalculateError = error{
    InvalidLunarDate,
};

/// Main entry point: calculates a complete saju analysis from input.
pub fn calculateSaju(input: SajuInput, current_year: u16) CalculateError!SajuResult {
    // 1. Normalize birth date (lunar→solar, DST, LMT)
    const normalized = manse.normalizeBirthDate(input) catch return error.InvalidLunarDate;
    const calc = normalized.calculation;

    // 2. Calculate four pillars
    const pillars = manse.calculateFourPillars(calc.year, calc.month, calc.day, calc.hour, calc.minute);

    // 3. Build pillar details
    const day_stem = pillars.day.stem;
    var pillar_details: [4]PillarDetail = undefined;
    const pillar_arr = [4]Pillar{ pillars.year, pillars.month, pillars.day, pillars.hour };
    for (pillar_arr, 0..) |p, i| {
        const hs = constants.getHiddenStems(p.branch);
        pillar_details[i] = .{
            .stem = p.stem,
            .branch = p.branch,
            .hidden_stems = hs,
            .stem_ten_god = constants.getTenGod(day_stem, p.stem),
            .branch_ten_god = constants.getTenGod(day_stem, hs.jeonggi),
        };
    }

    // 4. Gongmang
    const gongmang = analyze.calculateGongmang(pillars.day);

    // 5. Five elements
    const five_elements = analyze.countFiveElements(pillars);

    // 6. Twelve stages (bong + geo)
    var stages_bong: [4]constants.TwelveStage = undefined;
    var stages_geo: [4]constants.TwelveStage = undefined;
    for (pillar_arr, 0..) |p, i| {
        stages_bong[i] = constants.getTwelveStageBong(day_stem, p.branch);
        stages_geo[i] = constants.getTwelveStageGeo(day_stem, p.branch);
    }

    // 7. Twelve sals + special sals per pillar
    var twelve_sals: [4][]const u8 = undefined;
    var special_sals: [4]SpecialSals = undefined;
    for (pillar_arr, 0..) |p, i| {
        twelve_sals[i] = analyze.getTwelveSal(pillars.year.branch, p.branch);
        special_sals[i] = analyze.calculateSpecialSals(day_stem, pillars.day.branch, p.branch);
    }

    // 8. Stem and branch relations
    const stem_rels = analyze.getStemRelations(pillars);
    const branch_rels = analyze.getBranchRelations(pillars);

    // 9. Day strength, geukguk, yongsin
    const day_strength = analyze.calculateDayStrength(day_stem, pillars.month.branch, five_elements);
    const month_ten_god = constants.getTenGod(day_stem, pillars.month.stem);
    const geukguk = analyze.determineGeukguk(month_ten_god, day_strength.score);
    const yongsin = analyze.selectYongsin(day_stem, day_strength.strength, geukguk);

    // 10. Advanced sinsal
    const adv_sinsal = analyze.calculateAdvancedSinsal(
        pillars.year.branch,
        pillars.month.branch,
        pillars.day.branch,
        pillars.hour.branch,
        day_stem,
    );

    // 11. Daeun
    const daeun_forward = analyze.isDaeunForward(pillars.year.stem, input.gender);
    const birth_jd = manse.kstToJulianDayPub(calc.year, calc.month, calc.day, calc.hour, calc.minute);
    const daeun_info = analyze.calculateDaeunStartAge(birth_jd, daeun_forward);
    const daeun = analyze.buildDaeunList(
        pillars.month,
        daeun_forward,
        daeun_info.start_age,
        normalized.solar.year,
        day_stem,
    );

    // 12. Seyun + Wolun
    const seyun = analyze.buildSeyunList(current_year, day_stem, 10);
    const wolun = analyze.buildWolunList(current_year, day_stem);

    // 13. Interpretation
    var interp_buf: [1024]u8 = undefined;
    const interp = analyze.generateInterpretation(&interp_buf, geukguk, five_elements, adv_sinsal);

    return .{
        .input = input,
        .normalized = normalized,
        .pillars = pillars,
        .pillar_details = pillar_details,
        .gongmang = gongmang,
        .five_elements = five_elements,
        .twelve_stages_bong = stages_bong,
        .twelve_stages_geo = stages_geo,
        .twelve_sals = twelve_sals,
        .special_sals = special_sals,
        .stem_relations = stem_rels,
        .branch_relations = branch_rels,
        .day_strength = day_strength,
        .geukguk = geukguk,
        .yongsin = yongsin,
        .advanced_sinsal = adv_sinsal,
        .daeun_forward = daeun_forward,
        .daeun_start_age = daeun_info.start_age,
        .daeun_precise_age = daeun_info.precise_age,
        .daeun_diff_days = daeun_info.diff_days,
        .daeun = daeun,
        .seyun = seyun,
        .wolun = wolun,
        .interpretation_buf = interp_buf,
        .interpretation_len = interp.len,
    };
}

// =============================
// Tests
// =============================

test "calculateSaju: golden case 1992-10-24 05:30 solar male" {
    const result = try calculateSaju(.{
        .year = 1992,
        .month = 10,
        .day = 24,
        .hour = 5,
        .minute = 30,
        .gender = .male,
        .calendar = .solar,
    }, 2026);

    // Pillars: 壬申/庚戌/癸酉/乙卯
    try testing.expectEqual(Stem.im, result.pillars.year.stem);
    try testing.expectEqual(Branch.sin, result.pillars.year.branch);
    try testing.expectEqual(Stem.gyeong, result.pillars.month.stem);
    try testing.expectEqual(Branch.sul, result.pillars.month.branch);
    try testing.expectEqual(Stem.gye, result.pillars.day.stem);
    try testing.expectEqual(Branch.yu, result.pillars.day.branch);
    try testing.expectEqual(Stem.eul, result.pillars.hour.stem);
    try testing.expectEqual(Branch.myo, result.pillars.hour.branch);

    // Gongmang: 戌,亥
    try testing.expectEqual(Branch.sul, result.gongmang[0]);
    try testing.expectEqual(Branch.hae, result.gongmang[1]);

    // Yongsin: 庚甲丁 (for 종왕격 → weak rules for 癸)
    try testing.expectEqual(Stem.gyeong, result.yongsin[0]);
    try testing.expectEqual(Stem.gap, result.yongsin[1]);
    try testing.expectEqual(Stem.jeong, result.yongsin[2]);

    // Daeun direction: 壬 is yang, male → forward
    try testing.expect(result.daeun_forward);

    // Interpretation is non-empty
    try testing.expect(result.interpretation_len > 0);
}

test "calculateSaju: lunar input matches solar" {
    // Lunar 1992-9-29 = Solar 1992-10-24
    const lunar_result = try calculateSaju(.{
        .year = 1992,
        .month = 9,
        .day = 29,
        .hour = 5,
        .minute = 30,
        .gender = .male,
        .calendar = .lunar,
    }, 2026);

    const solar_result = try calculateSaju(.{
        .year = 1992,
        .month = 10,
        .day = 24,
        .hour = 5,
        .minute = 30,
        .gender = .male,
        .calendar = .solar,
    }, 2026);

    // Pillars should match
    try testing.expectEqual(solar_result.pillars.year.stem, lunar_result.pillars.year.stem);
    try testing.expectEqual(solar_result.pillars.year.branch, lunar_result.pillars.year.branch);
    try testing.expectEqual(solar_result.pillars.month.stem, lunar_result.pillars.month.stem);
    try testing.expectEqual(solar_result.pillars.day.stem, lunar_result.pillars.day.stem);
    try testing.expectEqual(solar_result.pillars.hour.stem, lunar_result.pillars.hour.stem);
}

test "calculateSaju: hour boundary 23:30 and 00:00 are 자시, 01:00 is 축시" {
    // TS test: 2024-01-01, female
    const at2330 = try calculateSaju(.{
        .year = 2024,
        .month = 1,
        .day = 1,
        .hour = 23,
        .minute = 30,
        .gender = .female,
        .calendar = .solar,
    }, 2026);
    const at0000 = try calculateSaju(.{
        .year = 2024,
        .month = 1,
        .day = 1,
        .hour = 0,
        .minute = 0,
        .gender = .female,
        .calendar = .solar,
    }, 2026);
    const at0100 = try calculateSaju(.{
        .year = 2024,
        .month = 1,
        .day = 1,
        .hour = 1,
        .minute = 0,
        .gender = .female,
        .calendar = .solar,
    }, 2026);

    // 23:30 → 甲子 (gap/ja)
    try testing.expectEqual(Stem.gap, at2330.pillars.hour.stem);
    try testing.expectEqual(Branch.ja, at2330.pillars.hour.branch);

    // 00:00 → 甲子 (gap/ja)
    try testing.expectEqual(Stem.gap, at0000.pillars.hour.stem);
    try testing.expectEqual(Branch.ja, at0000.pillars.hour.branch);

    // 01:00 → 乙丑 (eul/chuk)
    try testing.expectEqual(Stem.eul, at0100.pillars.hour.stem);
    try testing.expectEqual(Branch.chuk, at0100.pillars.hour.branch);
}

test "calculateSaju: lichun boundary 2024-02-03 is 癸卯 year, 乙丑 month" {
    const result = try calculateSaju(.{
        .year = 2024,
        .month = 2,
        .day = 3,
        .hour = 12,
        .minute = 0,
        .gender = .male,
        .calendar = .solar,
    }, 2026);

    // Before lichun 2024: year is still 癸卯
    try testing.expectEqual(Stem.gye, result.pillars.year.stem);
    try testing.expectEqual(Branch.myo, result.pillars.year.branch);
    // Month pillar: 乙丑
    try testing.expectEqual(Stem.eul, result.pillars.month.stem);
    try testing.expectEqual(Branch.chuk, result.pillars.month.branch);
}

test "calculateSaju: lichun boundary 2024-02-05 is 甲辰 year, 丙寅 month" {
    const result = try calculateSaju(.{
        .year = 2024,
        .month = 2,
        .day = 5,
        .hour = 12,
        .minute = 0,
        .gender = .male,
        .calendar = .solar,
    }, 2026);

    // After lichun 2024: year is 甲辰
    try testing.expectEqual(Stem.gap, result.pillars.year.stem);
    try testing.expectEqual(Branch.jin, result.pillars.year.branch);
    // Month pillar: 丙寅
    try testing.expectEqual(Stem.byeong, result.pillars.month.stem);
    try testing.expectEqual(Branch.in_, result.pillars.month.branch);
}

test "calculateSaju: LMT correction changes hour pillar" {
    // Without LMT: 1992-10-24 05:30 → hour pillar 乙卯
    const normal = try calculateSaju(.{
        .year = 1992,
        .month = 10,
        .day = 24,
        .hour = 5,
        .minute = 30,
        .gender = .male,
        .calendar = .solar,
    }, 2026);

    try testing.expectEqual(Stem.eul, normal.pillars.hour.stem);
    try testing.expectEqual(Branch.myo, normal.pillars.hour.branch);

    // With LMT (longitude 126.9784): calculation time → 04:57 → hour pillar 甲寅
    const lmt = try calculateSaju(.{
        .year = 1992,
        .month = 10,
        .day = 24,
        .hour = 5,
        .minute = 30,
        .gender = .male,
        .calendar = .solar,
        .apply_local_mean_time = true,
        .longitude = 126.9784,
    }, 2026);

    // LMT shifts time back ~33 minutes, crossing the 寅/卯 boundary
    try testing.expectEqual(Stem.gap, lmt.pillars.hour.stem);
    try testing.expectEqual(Branch.in_, lmt.pillars.hour.branch);

    // Verify calculation time is adjusted
    try testing.expectEqual(@as(u8, 4), lmt.normalized.calculation.hour);
    try testing.expectEqual(@as(u8, 57), lmt.normalized.calculation.minute);
}

test "calculateSaju: seyun ascending order and contains current year" {
    const current_year: u16 = 2026;
    const result = try calculateSaju(.{
        .year = 1992,
        .month = 10,
        .day = 24,
        .hour = 5,
        .minute = 30,
        .gender = .male,
        .calendar = .solar,
    }, current_year);

    // Seyun years must be strictly ascending
    var i: usize = 1;
    while (i < result.seyun.len) : (i += 1) {
        try testing.expect(result.seyun[i].year > result.seyun[i - 1].year);
    }

    // Seyun should include the current year
    var found = false;
    for (result.seyun) |s| {
        if (s.year == current_year) {
            found = true;
            break;
        }
    }
    try testing.expect(found);
}

test "calculateSaju: compact output contains key content" {
    const result = try calculateSaju(.{
        .year = 1992,
        .month = 10,
        .day = 24,
        .hour = 5,
        .minute = 30,
        .gender = .male,
        .calendar = .solar,
    }, 2026);

    var buf: [8192]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try result.writeCompact(fbs.writer(), 2026);
    const compact = fbs.getWritten();

    // Key sections and content
    try testing.expect(std.mem.indexOf(u8, compact, "## 원국") != null);
    try testing.expect(std.mem.indexOf(u8, compact, "## 오행") != null);
    try testing.expect(std.mem.indexOf(u8, compact, "공망") != null);
    try testing.expect(std.mem.indexOf(u8, compact, "## 대운") != null);
    try testing.expect(std.mem.indexOf(u8, compact, "## 세운") != null);
    try testing.expect(std.mem.indexOf(u8, compact, "## 월운") != null);
    try testing.expect(std.mem.indexOf(u8, compact, "장간") != null);

    // Day stem with element and yin-yang
    try testing.expect(std.mem.indexOf(u8, compact, "癸(계)수-") != null);
    // Geukguk
    try testing.expect(std.mem.indexOf(u8, compact, "종왕격") != null);
}

test "calculateSaju: markdown output contains key sections" {
    const result = try calculateSaju(.{
        .year = 2001,
        .month = 11,
        .day = 3,
        .hour = 14,
        .minute = 20,
        .gender = .male,
        .calendar = .solar,
    }, 2026);

    var buf: [16384]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try result.writeMarkdownFmt(fbs.writer(), 2026);
    const md = fbs.getWritten();

    // Key markdown sections
    try testing.expect(std.mem.indexOf(u8, md, "## 사주 원국") != null);
    try testing.expect(std.mem.indexOf(u8, md, "## 오행 분포") != null);
    try testing.expect(std.mem.indexOf(u8, md, "## 고급 분석") != null);
    try testing.expect(std.mem.indexOf(u8, md, "## 대운") != null);
    try testing.expect(std.mem.indexOf(u8, md, "## 지장간") != null);
    try testing.expect(std.mem.indexOf(u8, md, "## 공망") != null);
    try testing.expect(std.mem.indexOf(u8, md, "## 관계 해석") != null);
}

test "calculateSaju: daeun start age is valid" {
    const result = try calculateSaju(.{
        .year = 1970,
        .month = 1,
        .day = 7,
        .hour = 23,
        .minute = 30,
        .gender = .male,
        .calendar = .solar,
    }, 2026);

    try testing.expect(result.daeun_start_age >= 1);
    try testing.expect(result.daeun_precise_age > 0);
}

test {
    testing.refAllDecls(@This());
}
