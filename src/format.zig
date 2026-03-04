const std = @import("std");
const testing = std.testing;
const types = @import("types.zig");
const constants = @import("constants.zig");
const analyze = @import("analyze.zig");

const Stem = types.Stem;
const Branch = types.Branch;
const Element = types.Element;
const Pillar = types.Pillar;
const FourPillars = types.FourPillars;
const TenGod = types.TenGod;
const HiddenStems = types.HiddenStems;
const PillarKey = types.PillarKey;
const SajuInput = types.SajuInput;
const NormalizedBirth = types.NormalizedBirth;
const PillarDetail = types.PillarDetail;

// We import the SajuResult from root.zig would create a circular dependency.
// Instead, format functions take individual fields as parameters.

// =============================
// Helper functions
// =============================

fn pad2(writer: anytype, n: u8) !void {
    if (n < 10) try writer.writeByte('0');
    try writer.print("{d}", .{n});
}

fn yinYangSign(yy: types.YinYang) []const u8 {
    return if (yy == .yang) "+" else "-";
}

/// Writes a compact pillar token like "甲(갑)목+"
fn writePillarToken(writer: anytype, stem: Stem, branch: Branch, comptime which: enum { stem_tok, branch_tok }) !void {
    switch (which) {
        .stem_tok => {
            try writer.writeAll(stem.hanja());
            try writer.writeByte('(');
            try writer.writeAll(stem.korean());
            try writer.writeByte(')');
            try writer.writeAll(stem.element().korean());
            try writer.writeAll(yinYangSign(stem.yinYang()));
        },
        .branch_tok => {
            try writer.writeAll(branch.hanja());
            try writer.writeByte('(');
            try writer.writeAll(branch.korean());
            try writer.writeByte(')');
            try writer.writeAll(branch.element().korean());
            try writer.writeAll(yinYangSign(branch.yinYang()));
        },
    }
}

fn writeHiddenStem(writer: anytype, hs: HiddenStems) !void {
    if (hs.yeogi) |y| {
        try writer.writeAll(y.hanja());
    } else {
        try writer.writeByte('-');
    }
    try writer.writeByte(',');
    if (hs.junggi) |j| {
        try writer.writeAll(j.hanja());
    } else {
        try writer.writeByte('-');
    }
    try writer.writeByte(',');
    try writer.writeAll(hs.jeonggi.hanja());
}

// =============================
// Compact Text Format
// =============================

/// Writes a compact text summary to the given writer.
/// This mirrors the TS `generateCompactText` output format.
pub fn writeCompactText(
    writer: anytype,
    input: SajuInput,
    normalized: NormalizedBirth,
    pillars: FourPillars,
    pillar_details: [4]PillarDetail,
    gongmang: [2]Branch,
    five_elements: [5]u8,
    twelve_stages_bong: [4]constants.TwelveStage,
    twelve_stages_geo: [4]constants.TwelveStage,
    twelve_sals: [4][]const u8,
    special_sals: [4]analyze.SpecialSals,
    stem_relations: analyze.StemRelationsResult,
    branch_relations: analyze.BranchRelations,
    day_strength: analyze.DayStrengthResult,
    geukguk: analyze.Geukguk,
    yongsin: [3]Stem,
    advanced_sinsal: analyze.AdvancedSinsal,
    daeun_forward: bool,
    daeun_start_age: u8,
    daeun: [10]analyze.DaeunItem,
    seyun: [10]analyze.SeyunItem,
    wolun: [12]analyze.WolunItem,
    current_year: u16,
) !void {
    const day_stem = pillars.day.stem;
    const solar = normalized.solar;

    // ## 기본
    try writer.writeAll("## 기본\n");
    try writer.print("{d}.{d:0>2}.{d:0>2} {d:0>2}:{d:0>2} ", .{ solar.year, solar.month, solar.day, input.hour, input.minute });
    try writer.writeAll(input.gender.korean());
    try writer.writeByte(' ');
    try writer.writeAll(if (input.calendar == .solar) "양력" else "음력");
    try writer.writeByte('\n');

    // Day stem info
    try writer.writeAll("일간 ");
    try writer.writeAll(day_stem.hanja());
    try writer.writeByte('(');
    try writer.writeAll(day_stem.korean());
    try writer.writeByte(')');
    try writer.writeAll(day_stem.element().korean());
    try writer.writeAll(yinYangSign(day_stem.yinYang()));
    try writer.print(" 강약: {s}({d}) 격: {s} 용신: {s},{s},{s}\n", .{
        day_strength.strength.korean(),
        day_strength.score,
        geukguk.korean(),
        yongsin[0].hanja(),
        yongsin[1].hanja(),
        yongsin[2].hanja(),
    });

    // ## 원국
    try writer.writeAll("\n## 원국\n");

    // Header row: 시 | 일 | 월 | 연
    try writer.writeAll("     시주     | 일주     | 월주     | 연주\n");

    // 干 row
    try writer.writeAll("干   ");
    const order = [4]usize{ 3, 2, 1, 0 }; // hour, day, month, year
    for (order, 0..) |pi, oi| {
        if (oi > 0) try writer.writeAll(" | ");
        try writePillarToken(writer, pillar_details[pi].stem, pillar_details[pi].branch, .stem_tok);
    }
    try writer.writeByte('\n');

    // 支 row
    try writer.writeAll("支   ");
    for (order, 0..) |pi, oi| {
        if (oi > 0) try writer.writeAll(" | ");
        try writePillarToken(writer, pillar_details[pi].stem, pillar_details[pi].branch, .branch_tok);
    }
    try writer.writeByte('\n');

    // 장간 row
    try writer.writeAll("장간 ");
    for (order, 0..) |pi, oi| {
        if (oi > 0) try writer.writeAll(" | ");
        try writeHiddenStem(writer, pillar_details[pi].hidden_stems);
    }
    try writer.writeByte('\n');

    // 干성 row (stem ten god)
    try writer.writeAll("干성 ");
    for (order, 0..) |pi, oi| {
        if (oi > 0) try writer.writeAll(" | ");
        try writer.writeAll(pillar_details[pi].stem_ten_god.korean());
    }
    try writer.writeByte('\n');

    // 支성 row (branch ten god)
    try writer.writeAll("支성 ");
    for (order, 0..) |pi, oi| {
        if (oi > 0) try writer.writeAll(" | ");
        try writer.writeAll(pillar_details[pi].branch_ten_god.korean());
    }
    try writer.writeByte('\n');

    // 봉12 row
    try writer.writeAll("봉12 ");
    for (order, 0..) |pi, oi| {
        if (oi > 0) try writer.writeAll(" | ");
        try writer.writeAll(twelve_stages_bong[pi].korean());
    }
    try writer.writeByte('\n');

    // 거12 row
    try writer.writeAll("거12 ");
    for (order, 0..) |pi, oi| {
        if (oi > 0) try writer.writeAll(" | ");
        try writer.writeAll(twelve_stages_geo[pi].korean());
    }
    try writer.writeByte('\n');

    // 12살 row
    try writer.writeAll("12살 ");
    for (order, 0..) |pi, oi| {
        if (oi > 0) try writer.writeAll(" | ");
        try writer.writeAll(twelve_sals[pi]);
    }
    try writer.writeByte('\n');

    // 특살 row
    try writer.writeAll("특살 ");
    for (order, 0..) |pi, oi| {
        if (oi > 0) try writer.writeAll(" | ");
        var any = false;
        if (special_sals[pi].cheonEulGwiin) {
            try writer.writeAll("천을귀인");
            any = true;
        }
        if (special_sals[pi].yeokma) {
            if (any) try writer.writeByte(',');
            try writer.writeAll("역마살");
            any = true;
        }
        if (special_sals[pi].dohwa) {
            if (any) try writer.writeByte(',');
            try writer.writeAll("도화살");
            any = true;
        }
        if (special_sals[pi].hwagae) {
            if (any) try writer.writeByte(',');
            try writer.writeAll("화개살");
            any = true;
        }
        if (!any) try writer.writeByte('-');
    }
    try writer.writeByte('\n');

    // ## 오행
    try writer.writeAll("\n## 오행\n");
    const elem_names = [5][]const u8{ "목", "화", "토", "금", "수" };
    try writer.writeAll("계: ");
    for (0..5) |i| {
        if (i > 0) try writer.writeByte(' ');
        try writer.writeAll(elem_names[i]);
        try writer.print("{d}", .{five_elements[i]});
    }
    try writer.writeByte('\n');
    try writer.writeAll("공망: ");
    try writer.writeAll(gongmang[0].hanja());
    try writer.writeByte('(');
    try writer.writeAll(gongmang[0].korean());
    try writer.writeAll("), ");
    try writer.writeAll(gongmang[1].hanja());
    try writer.writeByte('(');
    try writer.writeAll(gongmang[1].korean());
    try writer.writeAll(")\n");

    // Gilsin / Hyungsin
    if (advanced_sinsal.gilsin_count > 0) {
        try writer.writeAll("길신: ");
        for (0..advanced_sinsal.gilsin_count) |i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.writeAll(advanced_sinsal.gilsin[i]);
        }
        try writer.writeByte('\n');
    }
    if (advanced_sinsal.hyungsin_count > 0) {
        try writer.writeAll("흉신: ");
        for (0..advanced_sinsal.hyungsin_count) |i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.writeAll(advanced_sinsal.hyungsin[i]);
        }
        try writer.writeByte('\n');
    }

    // ## 관계
    try writer.writeAll("\n## 관계\n");
    if (stem_relations.count == 0 and branch_relations.pair_count == 0 and branch_relations.triple_count == 0) {
        try writer.writeAll("없음\n");
    } else {
        // Stem relations
        if (stem_relations.count > 0) {
            for (0..stem_relations.count) |i| {
                const rel = stem_relations.items[i];
                try writer.writeAll("干");
                try writer.writeAll(rel.rel_type.korean());
                try writer.writeAll(": ");
                try writer.writeAll(rel.stem_a.hanja());
                try writer.writeAll(rel.stem_b.hanja());
                try writer.writeByte(' ');
                try writer.writeAll(rel.rel_type.korean());
                if (rel.hap_element) |elem| {
                    try writer.writeAll(" → ");
                    try writer.writeAll(elem.korean());
                }
                try writer.writeAll(" (");
                try writer.writeAll(rel.pillar_a.korean());
                try writer.writeAll("-");
                try writer.writeAll(rel.pillar_b.korean());
                try writer.writeAll(")\n");
            }
        }
        // Branch pair relations
        for (0..branch_relations.pair_count) |i| {
            const rel = branch_relations.pairs[i];
            try writer.writeAll("支");
            try writer.writeAll(rel.rel_type.korean());
            try writer.writeAll(": ");
            try writer.writeAll(rel.branch_a.hanja());
            try writer.writeAll(rel.branch_b.hanja());
            try writer.writeByte(' ');
            try writer.writeAll(rel.rel_type.korean());
            try writer.writeAll(" (");
            try writer.writeAll(rel.pillar_a.korean());
            try writer.writeAll("-");
            try writer.writeAll(rel.pillar_b.korean());
            try writer.writeAll(")\n");
        }
        // Branch triple relations
        for (0..branch_relations.triple_count) |i| {
            const rel = branch_relations.triples[i];
            try writer.writeAll("支");
            try writer.writeAll(rel.rel_type.korean());
            try writer.writeAll(": ");
            for (0..rel.pillar_count) |bi| {
                try writer.writeAll(rel.branches[bi].hanja());
            }
            try writer.writeByte(' ');
            try writer.writeAll(rel.rel_type.korean());
            try writer.writeByte(' ');
            try writer.writeAll(rel.name);
            try writer.writeByte('\n');
        }
    }

    // ## 대운
    try writer.writeAll("\n## 대운 ");
    try writer.writeAll(if (daeun_forward) "순행" else "역행");
    try writer.print(" 시작 {d}세\n", .{daeun_start_age});
    for (daeun) |d| {
        try writer.print(" {d}({d}) ", .{ d.start_age, d.start_year });
        try writer.writeAll(d.pillar.stem.hanja());
        try writer.writeAll(d.pillar.branch.hanja());
        try writer.print(" {s}/{s} {s}\n", .{
            d.stem_ten_god.korean(),
            d.branch_ten_god.korean(),
            d.twelve_stage.korean(),
        });
    }

    // ## 세운
    try writer.print("\n## 세운 {d}년 기준\n", .{current_year});
    for (seyun) |s| {
        const marker: []const u8 = if (s.year == current_year) "★" else " ";
        try writer.print("{s}{d} ", .{ marker, s.year });
        try writer.writeAll(s.pillar.stem.hanja());
        try writer.writeAll(s.pillar.branch.hanja());
        try writer.print(" {s}/{s} {s}\n", .{
            s.ten_god_stem.korean(),
            s.ten_god_branch.korean(),
            s.twelve_stage.korean(),
        });
    }

    // ## 월운
    try writer.print("\n## 월운 {d}년\n", .{current_year});
    for (wolun) |w| {
        try writer.print("{d:>2}월 ", .{w.month});
        try writer.writeAll(w.pillar.stem.hanja());
        try writer.writeAll(w.pillar.branch.hanja());
        try writer.print(" {s}/{s} {s}\n", .{
            w.stem_ten_god.korean(),
            w.branch_ten_god.korean(),
            w.twelve_stage.korean(),
        });
    }
}

// =============================
// Markdown Format
// =============================

/// Writes a markdown summary to the given writer.
pub fn writeMarkdown(
    writer: anytype,
    input: SajuInput,
    normalized: NormalizedBirth,
    pillars: FourPillars,
    pillar_details: [4]PillarDetail,
    gongmang: [2]Branch,
    five_elements: [5]u8,
    twelve_stages_bong: [4]constants.TwelveStage,
    twelve_stages_geo: [4]constants.TwelveStage,
    twelve_sals: [4][]const u8,
    special_sals: [4]analyze.SpecialSals,
    stem_relations: analyze.StemRelationsResult,
    branch_relations: analyze.BranchRelations,
    day_strength: analyze.DayStrengthResult,
    geukguk: analyze.Geukguk,
    yongsin: [3]Stem,
    advanced_sinsal: analyze.AdvancedSinsal,
    daeun_forward: bool,
    daeun_start_age: u8,
    daeun: [10]analyze.DaeunItem,
    seyun: [10]analyze.SeyunItem,
    wolun: [12]analyze.WolunItem,
    current_year: u16,
    interpretation: []const u8,
) !void {
    const day_stem = pillars.day.stem;
    const solar = normalized.solar;

    // ## 기본 정보
    try writer.writeAll("## 기본 정보\n\n");
    try writer.print("- 생년월일: {d}.{d:0>2}.{d:0>2} {d:0>2}:{d:0>2}\n", .{ solar.year, solar.month, solar.day, input.hour, input.minute });
    try writer.print("- 성별: {s}\n", .{input.gender.korean()});
    try writer.print("- 역법: {s}\n", .{if (input.calendar == .solar) "양력" else "음력"});
    try writer.print("- 일간: {s}({s}) {s}{s}\n", .{
        day_stem.hanja(),
        day_stem.korean(),
        day_stem.element().korean(),
        yinYangSign(day_stem.yinYang()),
    });

    // LMT info
    if (normalized.local_mean_time) |lmt| {
        try writer.print("- 진태양시 적용: {d}.{d:0>2}.{d:0>2} {d:0>2}:{d:0>2} (경도 {d:.1}, 보정 {d:.1}분)\n", .{
            lmt.year,           lmt.month,  lmt.day,
            lmt.hour,           lmt.minute, lmt.longitude,
            lmt.offset_minutes,
        });
    }

    // ## 사주 원국
    try writer.writeAll("\n## 사주 원국\n\n");
    try writer.writeAll("| | 시주 | 일주 | 월주 | 연주 |\n");
    try writer.writeAll("|---|---|---|---|---|\n");

    // Display order: hour(3), day(2), month(1), year(0) in pillar_details
    const disp = [4]usize{ 3, 2, 1, 0 };

    // 천간 row
    try writer.writeAll("| 천간 |");
    for (disp) |pi| {
        try writer.print(" {s}({s}) |", .{ pillar_details[pi].stem.hanja(), pillar_details[pi].stem.korean() });
    }
    try writer.writeByte('\n');

    // 오행/음양 stem row
    try writer.writeAll("| 오행 |");
    for (disp) |pi| {
        const s = pillar_details[pi].stem;
        try writer.print(" {s}{s} |", .{ s.element().korean(), yinYangSign(s.yinYang()) });
    }
    try writer.writeByte('\n');

    // 지지 row
    try writer.writeAll("| 지지 |");
    for (disp) |pi| {
        try writer.print(" {s}({s}) |", .{ pillar_details[pi].branch.hanja(), pillar_details[pi].branch.korean() });
    }
    try writer.writeByte('\n');

    // 오행/음양 branch row
    try writer.writeAll("| 오행 |");
    for (disp) |pi| {
        const b = pillar_details[pi].branch;
        try writer.print(" {s}{s} |", .{ b.element().korean(), yinYangSign(b.yinYang()) });
    }
    try writer.writeByte('\n');

    // ## 지장간
    try writer.writeAll("\n## 지장간\n\n");
    try writer.writeAll("| | 시주 | 일주 | 월주 | 연주 |\n");
    try writer.writeAll("|---|---|---|---|---|\n");

    // 여기
    try writer.writeAll("| 여기 |");
    for (disp) |pi| {
        if (pillar_details[pi].hidden_stems.yeogi) |y| {
            try writer.print(" {s} |", .{y.hanja()});
        } else {
            try writer.writeAll(" - |");
        }
    }
    try writer.writeByte('\n');

    // 중기
    try writer.writeAll("| 중기 |");
    for (disp) |pi| {
        if (pillar_details[pi].hidden_stems.junggi) |j| {
            try writer.print(" {s} |", .{j.hanja()});
        } else {
            try writer.writeAll(" - |");
        }
    }
    try writer.writeByte('\n');

    // 정기
    try writer.writeAll("| 정기 |");
    for (disp) |pi| {
        try writer.print(" {s} |", .{pillar_details[pi].hidden_stems.jeonggi.hanja()});
    }
    try writer.writeByte('\n');

    // ## 오행 분포
    try writer.writeAll("\n## 오행 분포\n\n");
    try writer.writeAll("| 오행 | 목 | 화 | 토 | 금 | 수 |\n");
    try writer.writeAll("|---|---|---|---|---|---|\n");
    try writer.writeAll("| 합계 |");
    for (0..5) |i| {
        try writer.print(" {d} |", .{five_elements[i]});
    }
    try writer.writeByte('\n');

    // ## 십성 & 12운성
    try writer.writeAll("\n## 십성 & 12운성\n\n");
    try writer.writeAll("| | 시주 | 일주 | 월주 | 연주 |\n");
    try writer.writeAll("|---|---|---|---|---|\n");

    try writer.writeAll("| 천간십성 |");
    for (disp) |pi| {
        try writer.print(" {s} |", .{pillar_details[pi].stem_ten_god.korean()});
    }
    try writer.writeByte('\n');

    try writer.writeAll("| 지지십성 |");
    for (disp) |pi| {
        try writer.print(" {s} |", .{pillar_details[pi].branch_ten_god.korean()});
    }
    try writer.writeByte('\n');

    try writer.writeAll("| 봉법12운성 |");
    for (disp) |pi| {
        try writer.print(" {s} |", .{twelve_stages_bong[pi].korean()});
    }
    try writer.writeByte('\n');

    try writer.writeAll("| 거법12운성 |");
    for (disp) |pi| {
        try writer.print(" {s} |", .{twelve_stages_geo[pi].korean()});
    }
    try writer.writeByte('\n');

    // ## 신살
    try writer.writeAll("\n## 사주별 신살\n\n");
    try writer.writeAll("| | 시주 | 일주 | 월주 | 연주 |\n");
    try writer.writeAll("|---|---|---|---|---|\n");
    try writer.writeAll("| 12신살 |");
    for (disp) |pi| {
        try writer.print(" {s} |", .{twelve_sals[pi]});
    }
    try writer.writeByte('\n');
    try writer.writeAll("| 특수신살 |");
    for (disp) |pi| {
        var any = false;
        try writer.writeByte(' ');
        if (special_sals[pi].cheonEulGwiin) {
            try writer.writeAll("천을귀인");
            any = true;
        }
        if (special_sals[pi].yeokma) {
            if (any) try writer.writeAll(", ");
            try writer.writeAll("역마살");
            any = true;
        }
        if (special_sals[pi].dohwa) {
            if (any) try writer.writeAll(", ");
            try writer.writeAll("도화살");
            any = true;
        }
        if (special_sals[pi].hwagae) {
            if (any) try writer.writeAll(", ");
            try writer.writeAll("화개살");
            any = true;
        }
        if (!any) try writer.writeByte('-');
        try writer.writeAll(" |");
    }
    try writer.writeByte('\n');

    // ## 공망
    try writer.writeAll("\n## 공망 (空亡)\n\n");
    try writer.print("- {s}({s}), {s}({s})\n", .{
        gongmang[0].hanja(), gongmang[0].korean(),
        gongmang[1].hanja(), gongmang[1].korean(),
    });

    // ## 고급 분석
    try writer.writeAll("\n## 고급 분석\n\n");
    try writer.print("- 일간 강약: {s} (점수 {d})\n", .{ day_strength.strength.korean(), day_strength.score });
    try writer.print("- 격국: {s}\n", .{geukguk.korean()});
    try writer.print("- 용신: {s}, {s}, {s}\n", .{ yongsin[0].hanja(), yongsin[1].hanja(), yongsin[2].hanja() });

    if (advanced_sinsal.gilsin_count > 0) {
        try writer.writeAll("- 길신: ");
        for (0..advanced_sinsal.gilsin_count) |i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.writeAll(advanced_sinsal.gilsin[i]);
        }
        try writer.writeByte('\n');
    }
    if (advanced_sinsal.hyungsin_count > 0) {
        try writer.writeAll("- 흉신: ");
        for (0..advanced_sinsal.hyungsin_count) |i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.writeAll(advanced_sinsal.hyungsin[i]);
        }
        try writer.writeByte('\n');
    }

    // ## 관계
    try writer.writeAll("\n## 관계 해석\n\n");
    if (stem_relations.count > 0) {
        try writer.writeAll("### 천간 관계\n\n");
        for (0..stem_relations.count) |i| {
            const rel = stem_relations.items[i];
            try writer.writeAll("- ");
            try writer.writeAll(rel.stem_a.hanja());
            try writer.writeAll(rel.stem_b.hanja());
            try writer.writeByte(' ');
            try writer.writeAll(rel.rel_type.korean());
            if (rel.hap_element) |elem| {
                try writer.writeAll(" → ");
                try writer.writeAll(elem.korean());
            }
            try writer.writeAll(" (");
            try writer.writeAll(rel.pillar_a.korean());
            try writer.writeAll("주-");
            try writer.writeAll(rel.pillar_b.korean());
            try writer.writeAll("주)\n");
        }
    }

    if (branch_relations.pair_count > 0 or branch_relations.triple_count > 0) {
        try writer.writeAll("\n### 지지 관계\n\n");
        for (0..branch_relations.pair_count) |i| {
            const rel = branch_relations.pairs[i];
            try writer.writeAll("- ");
            try writer.writeAll(rel.branch_a.hanja());
            try writer.writeAll(rel.branch_b.hanja());
            try writer.writeByte(' ');
            try writer.writeAll(rel.rel_type.korean());
            try writer.writeAll(" (");
            try writer.writeAll(rel.pillar_a.korean());
            try writer.writeAll("주-");
            try writer.writeAll(rel.pillar_b.korean());
            try writer.writeAll("주)\n");
        }
        for (0..branch_relations.triple_count) |i| {
            const rel = branch_relations.triples[i];
            try writer.writeAll("- ");
            for (0..rel.pillar_count) |bi| {
                try writer.writeAll(rel.branches[bi].hanja());
            }
            try writer.writeByte(' ');
            try writer.writeAll(rel.rel_type.korean());
            try writer.writeByte(' ');
            try writer.writeAll(rel.name);
            try writer.writeByte('\n');
        }
    }

    // ## 대운
    try writer.writeAll("\n## 대운\n\n");
    try writer.print("- 방향: {s}\n", .{if (daeun_forward) "순행" else "역행"});
    try writer.print("- 시작 나이: {d}세\n\n", .{daeun_start_age});
    try writer.writeAll("| 나이 | 간지 | 천간십성 | 지지십성 | 12운성 |\n");
    try writer.writeAll("|---|---|---|---|---|\n");
    for (daeun) |d| {
        try writer.print("| {d}~{d} | {s}{s} | {s} | {s} | {s} |\n", .{
            d.start_age,
            d.end_age,
            d.pillar.stem.hanja(),
            d.pillar.branch.hanja(),
            d.stem_ten_god.korean(),
            d.branch_ten_god.korean(),
            d.twelve_stage.korean(),
        });
    }

    // ## 세운
    try writer.print("\n## 세운 ({d}년 기준)\n\n", .{current_year});
    try writer.writeAll("| 연도 | 간지 | 천간십성 | 지지십성 | 12운성 |\n");
    try writer.writeAll("|---|---|---|---|---|\n");
    for (seyun) |s| {
        const marker: []const u8 = if (s.year == current_year) " ★" else "";
        try writer.print("| {d}{s} | {s}{s} | {s} | {s} | {s} |\n", .{
            s.year,
            marker,
            s.pillar.stem.hanja(),
            s.pillar.branch.hanja(),
            s.ten_god_stem.korean(),
            s.ten_god_branch.korean(),
            s.twelve_stage.korean(),
        });
    }

    // ## 월운
    try writer.print("\n## 월운 ({d}년)\n\n", .{current_year});
    try writer.writeAll("| 월 | 간지 | 천간십성 | 지지십성 | 12운성 |\n");
    try writer.writeAll("|---|---|---|---|---|\n");
    for (wolun) |w| {
        try writer.print("| {d}월 | {s}{s} | {s} | {s} | {s} |\n", .{
            w.month,
            w.pillar.stem.hanja(),
            w.pillar.branch.hanja(),
            w.stem_ten_god.korean(),
            w.branch_ten_god.korean(),
            w.twelve_stage.korean(),
        });
    }

    // ## 해석
    if (interpretation.len > 0) {
        try writer.writeAll("\n## 해석\n\n");
        try writer.writeAll(interpretation);
        try writer.writeByte('\n');
    }
}

// =============================
// Tests
// =============================

test "writeCompactText: produces output for golden case" {
    const root = @import("root.zig");
    const result = try root.calculateSaju(.{
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
    try writeCompactText(
        fbs.writer(),
        result.input,
        result.normalized,
        result.pillars,
        result.pillar_details,
        result.gongmang,
        result.five_elements,
        result.twelve_stages_bong,
        result.twelve_stages_geo,
        result.twelve_sals,
        result.special_sals,
        result.stem_relations,
        result.branch_relations,
        result.day_strength,
        result.geukguk,
        result.yongsin,
        result.advanced_sinsal,
        result.daeun_forward,
        result.daeun_start_age,
        result.daeun,
        result.seyun,
        result.wolun,
        2026,
    );

    const output = fbs.getWritten();
    try testing.expect(output.len > 100);
    try testing.expect(std.mem.startsWith(u8, output, "## 기본\n"));
    // Contains key sections
    try testing.expect(std.mem.indexOf(u8, output, "## 원국") != null);
    try testing.expect(std.mem.indexOf(u8, output, "## 오행") != null);
    try testing.expect(std.mem.indexOf(u8, output, "## 대운") != null);
    try testing.expect(std.mem.indexOf(u8, output, "## 세운") != null);
    try testing.expect(std.mem.indexOf(u8, output, "## 월운") != null);
}

test "writeMarkdown: produces output for golden case" {
    const root = @import("root.zig");
    const result = try root.calculateSaju(.{
        .year = 1992,
        .month = 10,
        .day = 24,
        .hour = 5,
        .minute = 30,
        .gender = .male,
        .calendar = .solar,
    }, 2026);

    var buf: [16384]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try writeMarkdown(
        fbs.writer(),
        result.input,
        result.normalized,
        result.pillars,
        result.pillar_details,
        result.gongmang,
        result.five_elements,
        result.twelve_stages_bong,
        result.twelve_stages_geo,
        result.twelve_sals,
        result.special_sals,
        result.stem_relations,
        result.branch_relations,
        result.day_strength,
        result.geukguk,
        result.yongsin,
        result.advanced_sinsal,
        result.daeun_forward,
        result.daeun_start_age,
        result.daeun,
        result.seyun,
        result.wolun,
        2026,
        result.interpretation(),
    );

    const output = fbs.getWritten();
    try testing.expect(output.len > 200);
    try testing.expect(std.mem.startsWith(u8, output, "## 기본 정보\n"));
    try testing.expect(std.mem.indexOf(u8, output, "## 사주 원국") != null);
    try testing.expect(std.mem.indexOf(u8, output, "## 지장간") != null);
    try testing.expect(std.mem.indexOf(u8, output, "## 오행 분포") != null);
    try testing.expect(std.mem.indexOf(u8, output, "## 대운") != null);
}
