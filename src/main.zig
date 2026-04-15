const std = @import("std");
const saju = @import("saju");
const build_options = @import("build_options");

const version = build_options.version;

const Format = enum {
    compact,
    markdown,
};

const CliArgs = struct {
    year: ?u16 = null,
    month: ?u8 = null,
    day: ?u8 = null,
    hour: u8 = 0,
    minute: u8 = 0,
    gender: saju.Gender = .male,
    calendar: saju.CalendarType = .solar,
    leap: bool = false,
    longitude: ?f64 = null,
    lmt: bool = false,
    format: Format = .compact,
    show_help: bool = false,
    show_version: bool = false,
};

fn printUsage(writer: *std.Io.Writer) !void {
    try writer.writeAll(
        \\Usage: saju [options]
        \\
        \\Compute Korean Four Pillars (사주/만세력) from a birth date.
        \\
        \\Required:
        \\  --year <YYYY>       Birth year (1900-2050)
        \\  --month <MM>        Birth month (1-12)
        \\  --day <DD>          Birth day (1-31)
        \\
        \\Optional:
        \\  --hour <HH>         Birth hour (0-23, default: 0)
        \\  --minute <MM>       Birth minute (0-59, default: 0)
        \\  --gender <m|f>      Gender: m=male, f=female (default: m)
        \\  --calendar <s|l>    Calendar: s=solar, l=lunar (default: s)
        \\  --leap              Lunar leap month flag (only with --calendar l)
        \\  --longitude <deg>   Longitude for LMT correction (e.g. 126.9784)
        \\  --lmt               Enable Local Mean Time correction (requires --longitude)
        \\  --format <c|m>      Output: c=compact, m=markdown (default: c)
        \\  --help              Show this help message
        \\  --version           Show version
        \\
        \\Examples:
        \\  saju --year 1992 --month 10 --day 24 --hour 5 --minute 30
        \\  saju --year 1992 --month 9 --day 29 --calendar l --gender f
        \\  saju --year 1992 --month 10 --day 24 --hour 5 --longitude 126.9784 --lmt --format m
        \\
    );
}

fn parseArgs(args_data: std.process.Args) !CliArgs {
    var args = args_data.iterate();
    _ = args.skip();

    var cli = CliArgs{};

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            cli.show_help = true;
            return cli;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            cli.show_version = true;
            return cli;
        } else if (std.mem.eql(u8, arg, "--year")) {
            const val = args.next() orelse return error.MissingValue;
            cli.year = std.fmt.parseInt(u16, val, 10) catch return error.InvalidYear;
        } else if (std.mem.eql(u8, arg, "--month")) {
            const val = args.next() orelse return error.MissingValue;
            cli.month = std.fmt.parseInt(u8, val, 10) catch return error.InvalidMonth;
        } else if (std.mem.eql(u8, arg, "--day")) {
            const val = args.next() orelse return error.MissingValue;
            cli.day = std.fmt.parseInt(u8, val, 10) catch return error.InvalidDay;
        } else if (std.mem.eql(u8, arg, "--hour")) {
            const val = args.next() orelse return error.MissingValue;
            cli.hour = std.fmt.parseInt(u8, val, 10) catch return error.InvalidHour;
        } else if (std.mem.eql(u8, arg, "--minute")) {
            const val = args.next() orelse return error.MissingValue;
            cli.minute = std.fmt.parseInt(u8, val, 10) catch return error.InvalidMinute;
        } else if (std.mem.eql(u8, arg, "--gender")) {
            const val = args.next() orelse return error.MissingValue;
            if (std.mem.eql(u8, val, "m") or std.mem.eql(u8, val, "male")) {
                cli.gender = .male;
            } else if (std.mem.eql(u8, val, "f") or std.mem.eql(u8, val, "female")) {
                cli.gender = .female;
            } else {
                return error.InvalidGender;
            }
        } else if (std.mem.eql(u8, arg, "--calendar")) {
            const val = args.next() orelse return error.MissingValue;
            if (std.mem.eql(u8, val, "s") or std.mem.eql(u8, val, "solar")) {
                cli.calendar = .solar;
            } else if (std.mem.eql(u8, val, "l") or std.mem.eql(u8, val, "lunar")) {
                cli.calendar = .lunar;
            } else {
                return error.InvalidCalendar;
            }
        } else if (std.mem.eql(u8, arg, "--longitude")) {
            const val = args.next() orelse return error.MissingValue;
            cli.longitude = std.fmt.parseFloat(f64, val) catch return error.InvalidLongitude;
        } else if (std.mem.eql(u8, arg, "--leap")) {
            cli.leap = true;
        } else if (std.mem.eql(u8, arg, "--lmt")) {
            cli.lmt = true;
        } else if (std.mem.eql(u8, arg, "--format")) {
            const val = args.next() orelse return error.MissingValue;
            if (std.mem.eql(u8, val, "c") or std.mem.eql(u8, val, "compact")) {
                cli.format = .compact;
            } else if (std.mem.eql(u8, val, "m") or std.mem.eql(u8, val, "markdown")) {
                cli.format = .markdown;
            } else {
                return error.InvalidFormat;
            }
        } else {
            return error.UnknownArgument;
        }
    }

    return cli;
}

/// Get the current year from system time (KST = UTC+9).
fn getCurrentYear(io: std.Io) u16 {
    const ts = std.Io.Clock.real.now(io).toSeconds();
    const kst_ts = ts + 9 * std.time.s_per_hour;
    const epoch_secs: std.time.epoch.EpochSeconds = .{ .secs = @intCast(kst_ts) };
    const year_day = epoch_secs.getEpochDay().calculateYearDay();
    return year_day.year;
}

/// Get the current KST date-time for manse reference codes.
fn getCurrentKstDateTime(io: std.Io) saju.DateTime {
    const ts = std.Io.Clock.real.now(io).toSeconds();
    const kst_ts = ts + 9 * std.time.s_per_hour;
    const epoch_secs: std.time.epoch.EpochSeconds = .{ .secs = @intCast(kst_ts) };
    const epoch_day = epoch_secs.getEpochDay();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_secs = epoch_secs.getDaySeconds();
    const hour = day_secs.getHoursIntoDay();
    const minute = day_secs.getMinutesIntoHour();
    return .{
        .year = year_day.year,
        .month = month_day.month.numeric(),
        .day = month_day.day_index + 1,
        .hour = @intCast(hour),
        .minute = @intCast(minute),
    };
}

pub fn main(init: std.process.Init) !void {
    const stdout_file = std.Io.File.stdout();
    const stderr_file = std.Io.File.stderr();

    var stdout_buf: [4096]u8 = undefined;
    var stderr_buf: [1024]u8 = undefined;

    var stdout_w = stdout_file.writer(init.io, &stdout_buf);
    var stderr_w = stderr_file.writer(init.io, &stderr_buf);

    const stdout = &stdout_w.interface;
    const stderr = &stderr_w.interface;

    const cli = parseArgs(init.minimal.args) catch |err| {
        try stderr.print("Error: {s}\n\n", .{@errorName(err)});
        try printUsage(stderr);
        try stderr.flush();
        std.process.exit(1);
    };

    if (cli.show_version) {
        try stdout.print("saju v{s}\n", .{version});
        try stdout.flush();
        return;
    }

    if (cli.show_help) {
        try printUsage(stdout);
        try stdout.flush();
        return;
    }

    // Validate required arguments
    const year = cli.year orelse {
        try stderr.writeAll("Error: --year is required\n\n");
        try printUsage(stderr);
        try stderr.flush();
        std.process.exit(1);
    };
    const month = cli.month orelse {
        try stderr.writeAll("Error: --month is required\n\n");
        try printUsage(stderr);
        try stderr.flush();
        std.process.exit(1);
    };
    const day = cli.day orelse {
        try stderr.writeAll("Error: --day is required\n\n");
        try printUsage(stderr);
        try stderr.flush();
        std.process.exit(1);
    };

    // Validate ranges
    if (year < 1900 or year > 2050) {
        try stderr.writeAll("Error: --year must be between 1900 and 2050\n");
        try stderr.flush();
        std.process.exit(1);
    }
    if (month < 1 or month > 12) {
        try stderr.writeAll("Error: --month must be between 1 and 12\n");
        try stderr.flush();
        std.process.exit(1);
    }
    if (day < 1 or day > 31) {
        try stderr.writeAll("Error: --day must be between 1 and 31\n");
        try stderr.flush();
        std.process.exit(1);
    }
    if (cli.hour > 23) {
        try stderr.writeAll("Error: --hour must be between 0 and 23\n");
        try stderr.flush();
        std.process.exit(1);
    }
    if (cli.minute > 59) {
        try stderr.writeAll("Error: --minute must be between 0 and 59\n");
        try stderr.flush();
        std.process.exit(1);
    }
    if (cli.lmt and cli.longitude == null) {
        try stderr.writeAll("Error: --lmt requires --longitude\n");
        try stderr.flush();
        std.process.exit(1);
    }

    const input = saju.SajuInput{
        .year = year,
        .month = month,
        .day = day,
        .hour = cli.hour,
        .minute = cli.minute,
        .gender = cli.gender,
        .calendar = cli.calendar,
        .leap = cli.leap,
        .longitude = cli.longitude,
        .apply_local_mean_time = cli.lmt,
    };

    const current_year = getCurrentYear(init.io);
    const ref_time = getCurrentKstDateTime(init.io);

    const result = saju.calculateSaju(input, current_year, ref_time) catch |err| {
        try stderr.print("Error calculating saju: {s}\n", .{@errorName(err)});
        try stderr.flush();
        std.process.exit(1);
    };

    switch (cli.format) {
        .compact => result.writeCompact(stdout, current_year) catch |err| {
            try stderr.print("Error writing output: {s}\n", .{@errorName(err)});
            try stderr.flush();
            std.process.exit(1);
        },
        .markdown => result.writeMarkdownFmt(stdout, current_year) catch |err| {
            try stderr.print("Error writing output: {s}\n", .{@errorName(err)});
            try stderr.flush();
            std.process.exit(1);
        },
    }

    try stdout.flush();
}
