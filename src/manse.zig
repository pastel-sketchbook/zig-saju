const std = @import("std");
const math = std.math;
const testing = std.testing;
const klc = @import("klc");
const types = @import("types.zig");
const constants = @import("constants.zig");

const Stem = types.Stem;
const Branch = types.Branch;
const Pillar = types.Pillar;
const FourPillars = types.FourPillars;
const SajuInput = types.SajuInput;
const SolarDate = types.SolarDate;
const DateTime = types.DateTime;
const NormalizedBirth = types.NormalizedBirth;
const LocalMeanTimeInfo = types.LocalMeanTimeInfo;
const CalendarType = types.CalendarType;

// =============================
// Date/Time Utilities
// =============================

/// Minutes in a day.
const MINUTES_PER_DAY: i32 = 24 * 60;

/// Compares two LocalTime values. Returns negative/zero/positive.
fn compareLocal(a: constants.LocalTime, b: constants.LocalTime) i32 {
    if (a.year != b.year) return @as(i32, @intCast(a.year)) - @as(i32, @intCast(b.year));
    if (a.month != b.month) return @as(i32, @intCast(a.month)) - @as(i32, @intCast(b.month));
    if (a.day != b.day) return @as(i32, @intCast(a.day)) - @as(i32, @intCast(b.day));
    if (a.hour != b.hour) return @as(i32, @intCast(a.hour)) - @as(i32, @intCast(b.hour));
    return @as(i32, @intCast(a.minute)) - @as(i32, @intCast(b.minute));
}

/// Checks if a Korean local datetime falls within a historical DST period.
fn isDuringKoreaDST(year: u16, month: u8, day: u8, hour: u8, minute: u8) bool {
    const local = constants.LocalTime{ .year = year, .month = month, .day = day, .hour = hour, .minute = minute };
    for (constants.KOREA_DST_PERIODS) |period| {
        if (compareLocal(local, period.start) >= 0 and compareLocal(local, period.end) < 0) {
            return true;
        }
    }
    return false;
}

/// Converts a KST local datetime to a fractional Julian Day (UTC).
/// Accounts for Korea DST if applicable.
pub fn kstToJulianDayPub(year: u16, month: u8, day: u8, hour: u8, minute: u8) f64 {
    return kstToJulianDayImpl(year, month, day, hour, minute);
}

fn kstToJulianDayImpl(year: u16, month: u8, day: u8, hour: u8, minute: u8) f64 {
    const dst_offset: i32 = if (isDuringKoreaDST(year, month, day, hour, minute)) 60 else 0;
    const total_offset_minutes: i32 = constants.BASE_KST_OFFSET_MINUTES + dst_offset;

    // Safe: callers validate year is within 1900-2050 (zig-klc supports 1391-2050).
    const jdn = klc.LunarSolarConverter.getJulianDayNumber(year, month, day) orelse unreachable;
    // JDN is at noon UTC. Convert to fractional JD for given time.
    // total minutes from midnight in local time
    const local_minutes: i32 = @as(i32, @intCast(hour)) * 60 + @as(i32, @intCast(minute));
    // UTC minutes from midnight = local_minutes - offset
    const utc_minutes: i32 = local_minutes - total_offset_minutes;
    // Fractional day from noon: (utc_minutes - 720) / 1440
    const frac: f64 = @as(f64, @floatFromInt(utc_minutes - 720)) / @as(f64, @floatFromInt(MINUTES_PER_DAY));
    return @as(f64, @floatFromInt(jdn)) + frac;
}

// =============================
// Solar Longitude (simplified VSOP87)
// =============================

/// Computes the apparent solar longitude in degrees for a given Julian Day.
fn getSolarLongitude(jd: f64) f64 {
    const T = (jd - 2451545.0) / 36525.0;
    const L0 = 280.46646 + 36000.76983 * T + 0.0003032 * T * T;
    const M = 357.52911 + 35999.05029 * T - 0.0001537 * T * T - 0.00000048 * T * T * T;
    const M_rad = M * math.pi / 180.0;
    const C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * @sin(M_rad) +
        (0.019993 - 0.000101 * T) * @sin(2.0 * M_rad) +
        0.000289 * @sin(3.0 * M_rad);
    const true_longitude = L0 + C;
    const omega = 125.04 - 1934.136 * T;
    const lambda = true_longitude - 0.00569 - 0.00478 * @sin(omega * math.pi / 180.0);
    return posMod(lambda, 360.0);
}

/// Positive modulo for floats.
fn posMod(n: f64, m: f64) f64 {
    const r = @mod(n, m);
    return if (r < 0) r + m else r;
}

/// Normalize angle to [-180, 180).
fn normalizeAngle(angle: f64) f64 {
    var n = @mod(angle, 360.0);
    if (n > 180.0) n -= 360.0;
    if (n < -180.0) n += 360.0;
    return n;
}

// =============================
// Solar Term Finding
// =============================

/// Finds the precise Julian Day (UTC) when the sun reaches a target ecliptic longitude.
/// Uses Newton-Raphson iteration.
fn findSolarTermJD(year: u16, target_degree: f64, approx_day_of_year: f64) f64 {
    // Safe: Jan 1 of any supported year (1900-2050) is always valid in zig-klc.
    const jan1_jdn = klc.LunarSolarConverter.getJulianDayNumber(year, 1, 1) orelse unreachable;
    // Initial guess: JDN at noon + approx_day_of_year
    var current_jd: f64 = @as(f64, @floatFromInt(jan1_jdn)) + approx_day_of_year;

    for (0..15) |_| {
        const longitude = getSolarLongitude(current_jd);
        const diff = normalizeAngle(target_degree - longitude);
        if (@abs(diff) < 1e-6) break;
        const delta_days = (diff / 360.0) * 365.2422;
        current_jd += delta_days;
    }

    return current_jd;
}

/// Builds the 12 major solar term JDs for a given year, sorted chronologically.
fn buildMajorSolarTermsJD(year: u16) [12]f64 {
    var terms: [12]f64 = undefined;
    for (constants.MAJOR_SOLAR_TERM_DEGREES, 0..) |degree, i| {
        terms[i] = findSolarTermJD(year, degree, constants.majorSolarTermApproxDay(degree));
    }
    // Sort chronologically
    std.mem.sort(f64, &terms, {}, std.sort.asc(f64));
    return terms;
}

/// Returns the Julian Day of Lichun (입춘, 315°) for a given year.
fn getLichunJD(year: u16) f64 {
    return findSolarTermJD(year, 315.0, constants.majorSolarTermApproxDay(315.0));
}

// =============================
// Four Pillars Core
// =============================

/// Returns the adjusted year based on whether the date is before or after Lichun.
fn getAdjustedYearByLichun(year: u16, month: u8, day: u8, hour: u8, minute: u8) u16 {
    const input_jd = kstToJulianDayImpl(year, month, day, hour, minute);
    const lichun_jd = getLichunJD(year);
    return if (input_jd < lichun_jd) year - 1 else year;
}

/// Returns the solar month index (0=寅月 ... 11=丑月) based on solar longitude.
fn getSolarMonthIndex(year: u16, month: u8, day: u8, hour: u8, minute: u8) u4 {
    const input_jd = kstToJulianDayImpl(year, month, day, hour, minute);
    const longitude = getSolarLongitude(input_jd);
    const normalized = posMod(longitude - 315.0, 360.0);
    return @intCast(@as(u32, @intFromFloat(@floor(normalized / 30.0))));
}

/// Year pillar from the adjusted year.
fn getYearPillar(adjusted_year: u16) Pillar {
    const y = @as(i32, @intCast(adjusted_year));
    const stem_idx: u4 = @intCast(@as(u32, @intCast(posMod64(y - 4, 10))));
    const branch_idx: u4 = @intCast(@as(u32, @intCast(posMod64(y - 4, 12))));
    return .{
        .stem = Stem.fromIndex(stem_idx),
        .branch = Branch.fromIndex(branch_idx),
    };
}

/// Positive modulo for i32.
fn posMod64(n: i32, m: i32) i32 {
    return @mod(n, m);
}

/// Month pillar from adjusted year and month index.
fn getMonthPillar(adjusted_year: u16, month_index: u4) Pillar {
    const y = @as(i32, @intCast(adjusted_year));
    const year_stem_idx: u4 = @intCast(@as(u32, @intCast(posMod64(y - 4, 10))));
    const year_stem = Stem.fromIndex(year_stem_idx);
    const start_stem = constants.yearStemToMonthStartStemIndex(year_stem);
    const month_stem_idx: u4 = @intCast((@as(u8, start_stem) + @as(u8, month_index)) % 10);
    const branch = constants.monthBranch(@as(u8, month_index) + 1);
    return .{
        .stem = Stem.fromIndex(month_stem_idx),
        .branch = branch,
    };
}

/// Day pillar using JDN difference from base date 1992-10-24 (ganji index 9).
fn getDayPillar(year: u16, month: u8, day: u8) Pillar {
    // Safe: 1992-10-24 is a known constant within zig-klc's supported range.
    const base_jdn = klc.LunarSolarConverter.getJulianDayNumber(1992, 10, 24) orelse unreachable;
    // Safe: callers validate year is within 1900-2050.
    const target_jdn = klc.LunarSolarConverter.getJulianDayNumber(year, month, day) orelse unreachable;
    const base_ganji: i32 = 9;
    const days_diff: i32 = @as(i32, @intCast(target_jdn)) - @as(i32, @intCast(base_jdn));
    const ganji_num: u6 = @intCast(@as(u32, @intCast(posMod64(base_ganji + days_diff, 60))));
    return Pillar.fromGanjiIndex(ganji_num);
}

/// Hour pillar from the day pillar, hour, and minute.
fn getHourPillar(day_pillar: Pillar, hour: u8, minute: u8) Pillar {
    const adjusted_hour: u8 = if (hour == 23) 0 else hour;
    const total_minutes: u16 = @as(u16, adjusted_hour) * 60 + @as(u16, minute);
    const shichen: u4 = @intCast(((total_minutes + 60) / 120) % 12);
    const day_stem_idx: u8 = @intFromEnum(day_pillar.stem);
    const hour_stem_base: u8 = (day_stem_idx % 5) * 2;
    const hour_stem_idx: u4 = @intCast((hour_stem_base + @as(u8, shichen)) % 10);
    return .{
        .stem = Stem.fromIndex(hour_stem_idx),
        .branch = Branch.fromIndex(shichen),
    };
}

/// Calculates the four pillars from a KST date/time.
pub fn calculateFourPillars(year: u16, month: u8, day: u8, hour: u8, minute: u8) FourPillars {
    const adjusted_year = getAdjustedYearByLichun(year, month, day, hour, minute);
    const month_index = getSolarMonthIndex(year, month, day, hour, minute);

    const year_pillar = getYearPillar(adjusted_year);
    const month_pillar = getMonthPillar(adjusted_year, month_index);
    const day_pillar = getDayPillar(year, month, day);
    const hour_pillar = getHourPillar(day_pillar, hour, minute);

    return .{
        .year = year_pillar,
        .month = month_pillar,
        .day = day_pillar,
        .hour = hour_pillar,
    };
}

// =============================
// Birth Date Normalization
// =============================

/// Normalizes a SajuInput into a NormalizedBirth, handling lunar→solar conversion,
/// KST timezone, and optional Local Mean Time correction.
pub fn normalizeBirthDate(input: SajuInput) !NormalizedBirth {
    // 1. Resolve solar date
    var solar = SolarDate{ .year = input.year, .month = input.month, .day = input.day };
    if (input.calendar == .lunar) {
        solar = try lunarToSolar(input.year, input.month, input.day, input.leap);
    }

    // 2. KST = input time (we assume KST input for now)
    const kst = DateTime{
        .year = solar.year,
        .month = solar.month,
        .day = solar.day,
        .hour = input.hour,
        .minute = input.minute,
    };

    // 3. Apply Local Mean Time if requested
    var lmt_info: ?LocalMeanTimeInfo = null;
    var calc = kst;

    if (input.apply_local_mean_time) {
        const longitude = input.longitude orelse constants.SEOUL_LONGITUDE;
        const std_longitude = constants.STANDARD_LONGITUDE;
        const offset_minutes = (longitude - std_longitude) * 4.0;

        const adjusted = addMinutesToDateTimeFractional(kst, offset_minutes);
        calc = adjusted;
        lmt_info = .{
            .year = adjusted.year,
            .month = adjusted.month,
            .day = adjusted.day,
            .hour = adjusted.hour,
            .minute = adjusted.minute,
            .longitude = longitude,
            .offset_minutes = offset_minutes,
            .standard_longitude = std_longitude,
        };
    }

    return .{
        .solar = solar,
        .kst = kst,
        .calculation = calc,
        .local_mean_time = lmt_info,
    };
}

/// Converts a lunar date to a solar date using zig-klc.
fn lunarToSolar(year: u16, month: u8, day: u8, is_leap: bool) !SolarDate {
    var converter = klc.LunarSolarConverter.new();
    const ok = converter.setLunarDate(@intCast(year), month, day, is_leap);
    if (!ok) return error.InvalidLunarDate;
    return .{
        .year = @intCast(converter.solarYear()),
        .month = @intCast(converter.solarMonth()),
        .day = @intCast(converter.solarDay()),
    };
}

/// Adds a fractional minute offset to a DateTime, matching JS Date behavior
/// (floor for hour/minute extraction after applying the fractional offset).
fn addMinutesToDateTimeFractional(dt: DateTime, offset_minutes: f64) DateTime {
    // Safe: dt comes from a previously validated date within 1900-2050.
    const jdn = klc.LunarSolarConverter.getJulianDayNumber(dt.year, dt.month, dt.day) orelse unreachable;
    const minutes_from_midnight: f64 = @as(f64, @floatFromInt(dt.hour)) * 60.0 + @as(f64, @floatFromInt(dt.minute));
    const adjusted = minutes_from_midnight + offset_minutes;

    const day_offset_f = @divFloor(adjusted, @as(f64, MINUTES_PER_DAY));
    const day_offset: i32 = @intFromFloat(day_offset_f);
    const remaining = adjusted - day_offset_f * @as(f64, MINUTES_PER_DAY);
    const new_hour: u8 = @intFromFloat(@floor(remaining / 60.0));
    const new_minute: u8 = @intFromFloat(@floor(remaining - @as(f64, @floatFromInt(new_hour)) * 60.0));

    const new_jdn: u32 = @intCast(@as(i32, @intCast(jdn)) + day_offset);
    const date = jdnToDate(new_jdn);

    return .{
        .year = date.year,
        .month = date.month,
        .day = date.day,
        .hour = new_hour,
        .minute = new_minute,
    };
}

/// Converts a Julian Day Number to a solar date (year, month, day).
/// Algorithm from Meeus, "Astronomical Algorithms" (Richards).
fn jdnToDate(jdn: u32) SolarDate {
    // Algorithm for Julian Day Number → Gregorian calendar
    const a_val: i64 = @as(i64, jdn) + 32044;
    const b_val: i64 = @divFloor(4 * a_val + 3, 146097);
    const c_val: i64 = a_val - @divFloor(146097 * b_val, 4);
    const d_val: i64 = @divFloor(4 * c_val + 3, 1461);
    const e_val: i64 = c_val - @divFloor(1461 * d_val, 4);
    const m_val: i64 = @divFloor(5 * e_val + 2, 153);
    const day: i64 = e_val - @divFloor(153 * m_val + 2, 5) + 1;
    const month: i64 = m_val + 3 - 12 * @divFloor(m_val, 10);
    const year: i64 = 100 * b_val + d_val - 4800 + @divFloor(m_val, 10);
    return .{
        .year = @intCast(year),
        .month = @intCast(month),
        .day = @intCast(day),
    };
}

// =============================
// Solar Term Resolution (for Daeun)
// =============================

/// Resolves the nearest major solar term JD relative to a birth JD.
/// If forward=true, finds the next term after birth; if false, finds the previous term.
pub fn resolveNearestMajorSolarTermJD(birth_jd: f64, forward: bool) f64 {
    // We need to estimate the year from the JD to build candidates.
    const approx_year: u16 = @intFromFloat(@floor((birth_jd - 2451545.0) / 365.25 + 2000.0));
    const start_year = if (approx_year > 1) approx_year - 1 else approx_year;

    var candidates: [48]f64 = undefined; // 4 years * 12 terms
    var count: usize = 0;
    var y = start_year;
    while (y <= approx_year + 2 and y <= constants.MAX_SUPPORTED_YEAR) : (y += 1) {
        const terms = buildMajorSolarTermsJD(y);
        for (terms) |t| {
            if (count < candidates.len) {
                candidates[count] = t;
                count += 1;
            }
        }
    }

    // Sort candidates
    std.mem.sort(f64, candidates[0..count], {}, std.sort.asc(f64));

    if (forward) {
        for (candidates[0..count]) |t| {
            if (t > birth_jd) return t;
        }
    } else {
        var i: usize = count;
        while (i > 0) {
            i -= 1;
            if (candidates[i] <= birth_jd) return candidates[i];
        }
    }

    // Fallback
    return candidates[count / 2];
}

// =============================
// Tests
// =============================

test "golden case: 1992-10-24 05:30 solar → 壬申/庚戌/癸酉/乙卯" {
    const pillars = calculateFourPillars(1992, 10, 24, 5, 30);

    // Year: 壬申
    try testing.expectEqual(Stem.im, pillars.year.stem);
    try testing.expectEqual(Branch.sin, pillars.year.branch);

    // Month: 庚戌
    try testing.expectEqual(Stem.gyeong, pillars.month.stem);
    try testing.expectEqual(Branch.sul, pillars.month.branch);

    // Day: 癸酉
    try testing.expectEqual(Stem.gye, pillars.day.stem);
    try testing.expectEqual(Branch.yu, pillars.day.branch);

    // Hour: 乙卯
    try testing.expectEqual(Stem.eul, pillars.hour.stem);
    try testing.expectEqual(Branch.myo, pillars.hour.branch);
}

test "hour boundary: 23:30 is 자시 (子)" {
    const pillars = calculateFourPillars(1992, 10, 24, 23, 30);
    try testing.expectEqual(Branch.ja, pillars.hour.branch);
}

test "hour boundary: 00:00 is 자시 (子)" {
    const pillars = calculateFourPillars(1992, 10, 25, 0, 0);
    try testing.expectEqual(Branch.ja, pillars.hour.branch);
}

test "hour boundary: 01:00 is 축시 (丑)" {
    const pillars = calculateFourPillars(1992, 10, 25, 1, 0);
    try testing.expectEqual(Branch.chuk, pillars.hour.branch);
}

test "lichun boundary: 2024-02-03 is 癸卯 year" {
    const pillars = calculateFourPillars(2024, 2, 3, 12, 0);
    // Before lichun → previous year: 2023 = 癸卯
    try testing.expectEqual(Stem.gye, pillars.year.stem);
    try testing.expectEqual(Branch.myo, pillars.year.branch);
}

test "lichun boundary: 2024-02-05 is 甲辰 year" {
    const pillars = calculateFourPillars(2024, 2, 5, 12, 0);
    // After lichun → 2024 = 甲辰
    try testing.expectEqual(Stem.gap, pillars.year.stem);
    try testing.expectEqual(Branch.jin, pillars.year.branch);
}

test "day pillar base case: 1992-10-24 is ganji 9 = 癸酉" {
    const day = getDayPillar(1992, 10, 24);
    try testing.expectEqual(Stem.gye, day.stem);
    try testing.expectEqual(Branch.yu, day.branch);
    try testing.expectEqual(@as(u6, 9), day.ganjiIndex());
}

test "normalizeBirthDate: solar input passthrough" {
    const input = SajuInput{
        .year = 1992,
        .month = 10,
        .day = 24,
        .hour = 5,
        .minute = 30,
    };
    const nb = try normalizeBirthDate(input);
    try testing.expectEqual(@as(u16, 1992), nb.solar.year);
    try testing.expectEqual(@as(u8, 10), nb.solar.month);
    try testing.expectEqual(@as(u8, 24), nb.solar.day);
    try testing.expectEqual(@as(u8, 5), nb.kst.hour);
    try testing.expectEqual(@as(u8, 30), nb.kst.minute);
    try testing.expect(nb.local_mean_time == null);
}

test "normalizeBirthDate: lunar 1992-9-29 = solar 1992-10-24" {
    const input = SajuInput{
        .year = 1992,
        .month = 9,
        .day = 29,
        .hour = 5,
        .minute = 30,
        .calendar = .lunar,
    };
    const nb = try normalizeBirthDate(input);
    try testing.expectEqual(@as(u16, 1992), nb.solar.year);
    try testing.expectEqual(@as(u8, 10), nb.solar.month);
    try testing.expectEqual(@as(u8, 24), nb.solar.day);
}

test "normalizeBirthDate: LMT correction changes time" {
    const input = SajuInput{
        .year = 1992,
        .month = 10,
        .day = 24,
        .hour = 5,
        .minute = 30,
        .longitude = 126.9784,
        .apply_local_mean_time = true,
    };
    const nb = try normalizeBirthDate(input);
    try testing.expect(nb.local_mean_time != null);
    // LMT offset = (126.9784 - 135) * 4 = -32.0864 minutes
    // 05h30m = 330.0 - 32.0864 = 297.9136 → floor: 4h57m
    const lmt = nb.local_mean_time.?;
    try testing.expectEqual(@as(u8, 4), lmt.hour);
    try testing.expectEqual(@as(u8, 57), lmt.minute);
}

test "LMT correction changes hour pillar from 乙卯 to 甲寅" {
    // Without LMT: 05:30 → 乙卯
    const p1 = calculateFourPillars(1992, 10, 24, 5, 30);
    try testing.expectEqual(Stem.eul, p1.hour.stem);
    try testing.expectEqual(Branch.myo, p1.hour.branch);

    // With LMT: adjusted to 04:57 → 甲寅
    const input = SajuInput{
        .year = 1992,
        .month = 10,
        .day = 24,
        .hour = 5,
        .minute = 30,
        .longitude = 126.9784,
        .apply_local_mean_time = true,
    };
    const nb = try normalizeBirthDate(input);
    const p2 = calculateFourPillars(nb.calculation.year, nb.calculation.month, nb.calculation.day, nb.calculation.hour, nb.calculation.minute);
    try testing.expectEqual(Stem.gap, p2.hour.stem);
    try testing.expectEqual(Branch.in_, p2.hour.branch);
}

test "jdnToDate round-trip" {
    // 1992-10-24 JDN should round-trip
    const jdn = klc.LunarSolarConverter.getJulianDayNumber(1992, 10, 24) orelse unreachable;
    const date = jdnToDate(jdn);
    try testing.expectEqual(@as(u16, 1992), date.year);
    try testing.expectEqual(@as(u8, 10), date.month);
    try testing.expectEqual(@as(u8, 24), date.day);

    // 2024-02-04
    const jdn2 = klc.LunarSolarConverter.getJulianDayNumber(2024, 2, 4) orelse unreachable;
    const date2 = jdnToDate(jdn2);
    try testing.expectEqual(@as(u16, 2024), date2.year);
    try testing.expectEqual(@as(u8, 2), date2.month);
    try testing.expectEqual(@as(u8, 4), date2.day);
}

test "solar longitude is in valid range" {
    // Check a known date
    const jdn = klc.LunarSolarConverter.getJulianDayNumber(2024, 3, 20) orelse unreachable;
    const jd: f64 = @floatFromInt(jdn);
    const lon = getSolarLongitude(jd);
    // Around March equinox, longitude should be near 0° (within a few degrees)
    try testing.expect(lon < 5.0 or lon > 355.0);
}
