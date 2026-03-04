const std = @import("std");
const testing = std.testing;

pub const types = @import("types.zig");
pub const constants = @import("constants.zig");
pub const manse = @import("manse.zig");
pub const analyze = @import("analyze.zig");
pub const format = @import("format.zig");

// Re-export core types for convenience
pub const Stem = types.Stem;
pub const Branch = types.Branch;
pub const Element = types.Element;
pub const YinYang = types.YinYang;
pub const Gender = types.Gender;
pub const CalendarType = types.CalendarType;
pub const TenGod = types.TenGod;
pub const Pillar = types.Pillar;
pub const FourPillars = types.FourPillars;
pub const HiddenStems = types.HiddenStems;
pub const SajuInput = types.SajuInput;
pub const PillarKey = types.PillarKey;
pub const SolarDate = types.SolarDate;
pub const DateTime = types.DateTime;
pub const NormalizedBirth = types.NormalizedBirth;
pub const PillarDetail = types.PillarDetail;

// Re-export key functions
pub const getTenGod = constants.getTenGod;
pub const getHiddenStems = constants.getHiddenStems;
pub const calculateFourPillars = manse.calculateFourPillars;
pub const normalizeBirthDate = manse.normalizeBirthDate;

// Re-export analyze types and functions
pub const DayStrength = analyze.DayStrength;
pub const DayStrengthResult = analyze.DayStrengthResult;
pub const Geukguk = analyze.Geukguk;
pub const SpecialSals = analyze.SpecialSals;
pub const DaeunItem = analyze.DaeunItem;
pub const SeyunItem = analyze.SeyunItem;
pub const WolunItem = analyze.WolunItem;
pub const StemRelation = analyze.StemRelation;
pub const StemRelationsResult = analyze.StemRelationsResult;
pub const BranchRelations = analyze.BranchRelations;
pub const AdvancedSinsal = analyze.AdvancedSinsal;

// =============================
// SajuResult — Complete analysis result
// =============================

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

test "calculateSaju: hour boundary 23:30 is 자시" {
    const result = try calculateSaju(.{
        .year = 1992,
        .month = 10,
        .day = 24,
        .hour = 23,
        .minute = 30,
        .gender = .male,
        .calendar = .solar,
    }, 2026);

    // 23:30 should be 자시 (子)
    try testing.expectEqual(Branch.ja, result.pillars.hour.branch);
}

test "calculateSaju: lichun boundary 2024-02-03 is 癸卯 year" {
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
}

test "calculateSaju: lichun boundary 2024-02-05 is 甲辰 year" {
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
}

test {
    testing.refAllDecls(@This());
}
