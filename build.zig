const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const klc_dep = b.dependency("klc", .{
        .target = target,
        .optimize = optimize,
    });
    const klc_mod = klc_dep.module("klc");

    const mod = b.addModule("saju", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "klc", .module = klc_mod },
        },
    });

    // Read version from VERSION file (single source of truth)
    const version = @embedFile("VERSION");
    const version_trimmed = std.mem.trimEnd(u8, version, &.{ '\n', '\r', ' ' });

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", version_trimmed);

    const exe = b.addExecutable(.{
        .name = "saju",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "saju", .module = mod },
                .{ .name = "klc", .module = klc_mod },
                .{ .name = "build_options", .module = build_options.createModule() },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // ── Data generation step (zig build gen-data -- > output.txt) ──

    const gen_data_exe = b.addExecutable(.{
        .name = "gen-saju-data",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gen_saju_data.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "saju", .module = mod },
            },
        }),
    });
    b.installArtifact(gen_data_exe);

    const gen_data_step = b.step("gen-data", "Generate saju training data to stdout");
    const gen_data_cmd = b.addRunArtifact(gen_data_exe);
    gen_data_step.dependOn(&gen_data_cmd.step);
    gen_data_cmd.step.dependOn(b.getInstallStep());

    // ── Gunghap (pair compatibility) data generation step ──

    const gen_gunghap_exe = b.addExecutable(.{
        .name = "gen-gunghap-data",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gen_gunghap_data.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "saju", .module = mod },
            },
        }),
    });
    b.installArtifact(gen_gunghap_exe);

    const gen_gunghap_step = b.step("gen-gunghap", "Generate gunghap pair compatibility data to stdout");
    const gen_gunghap_cmd = b.addRunArtifact(gen_gunghap_exe);
    gen_gunghap_step.dependOn(&gen_gunghap_cmd.step);
    gen_gunghap_cmd.step.dependOn(b.getInstallStep());

    // ── WASM build step (lazy — only built when `zig build wasm` is invoked) ──

    const wasm_step = b.step("wasm", "Build WASM module (wasm32-freestanding)");

    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });
    const wasm_optimize = b.option(
        std.builtin.OptimizeMode,
        "wasm-optimize",
        "Optimization level for WASM build (default: ReleaseSmall)",
    ) orelse .ReleaseSmall;

    const wasm_klc_dep = b.dependency("klc", .{
        .target = wasm_target,
        .optimize = wasm_optimize,
    });
    const wasm_klc_mod = wasm_klc_dep.module("klc");

    const wasm_saju_mod = b.addModule("saju-wasm", .{
        .root_source_file = b.path("src/root.zig"),
        .target = wasm_target,
        .optimize = wasm_optimize,
        .imports = &.{
            .{ .name = "klc", .module = wasm_klc_mod },
        },
    });

    const wasm_lib = b.addExecutable(.{
        .name = "saju",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
            .target = wasm_target,
            .optimize = wasm_optimize,
            .imports = &.{
                .{ .name = "saju", .module = wasm_saju_mod },
            },
        }),
    });
    wasm_lib.entry = .disabled;
    wasm_lib.rdynamic = true;

    const wasm_install = b.addInstallArtifact(wasm_lib, .{});
    wasm_step.dependOn(&wasm_install.step);
}
