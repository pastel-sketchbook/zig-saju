const std = @import("std");
const testing = std.testing;

pub const types = @import("types.zig");
pub const constants = @import("constants.zig");
pub const manse = @import("manse.zig");
pub const analyze = @import("analyze.zig");

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
pub const calculateGongmang = analyze.calculateGongmang;
pub const countFiveElements = analyze.countFiveElements;
pub const getTwelveSal = analyze.getTwelveSal;
pub const calculateSpecialSals = analyze.calculateSpecialSals;
pub const calculateDayStrength = analyze.calculateDayStrength;
pub const determineGeukguk = analyze.determineGeukguk;
pub const selectYongsin = analyze.selectYongsin;
pub const isDaeunForward = analyze.isDaeunForward;
pub const calculateDaeunStartAge = analyze.calculateDaeunStartAge;
pub const buildDaeunList = analyze.buildDaeunList;
pub const buildSeyunList = analyze.buildSeyunList;
pub const buildWolunList = analyze.buildWolunList;

test {
    testing.refAllDecls(@This());
}
